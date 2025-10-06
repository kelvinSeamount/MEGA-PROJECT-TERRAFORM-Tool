provider "aws" {
  region = "eu-central-1"
}

resource "aws_vpc" "mekadevops_vpc" {
  cidr_block = "10.0.0.0/16"
  
    tags = {
        Name = "mekadevops_vpc"
    }
}

resource "aws_subnet" "mekadevops_subnet" {
  count = 2
  vpc_id = aws_vpc.mekadevops_vpc.id
  cidr_block = cidrsubnet(aws_vpc.mekadevops_vpc.cidr_block, 8, count.index)
  availability_zone = element(["eu-central-1a", "eu-central-1b"], count.index)
  map_public_ip_on_launch = true


  tags = {
     Name = "mekadevops_subnet_${count.index + 1}"
   }
}

resource "aws_internet_gateway" "mekadevops_igw" {
  vpc_id = aws_vpc.mekadevops_vpc.id

  tags = {
    Name = "mekadevops_igw"
  }
}


resource "aws_route_table" "mekadevops_route_table" {
  vpc_id = aws_vpc.mekadevops_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mekadevops_igw.id
  }         
    tags = {
        Name = "mekadevops_route_table"
    }
}


resource "aws_route_table_association" "mekadevops_association" {
  count = 2
  subnet_id = aws_subnet.mekadevops_subnet[count.index].id
  route_table_id = aws_route_table.mekadevops_route_table.id
}

resource "aws_security_group" "mekadevops_cluster_sg" {
  vpc_id = aws_vpc.mekadevops_vpc.id

  egress  {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mekadevops_cluster_sg"
  }
}

resource "aws_security_group" "mekadevops_node_sg" {
  vpc_id = aws_vpc.mekadevops_vpc.id

  ingress  {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    egress  {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

  tags = {
    Name = "mekadevops_node_sg"
  }
}

resource "aws_eks_cluster" "mekadevops" {
  name     = "mekadevops-cluster"
  role_arn = aws_iam_role.mekadevops_eks_role.arn

  vpc_config {
    subnet_ids = aws_subnet.mekadevops_subnet[*].id
    security_group_ids = [aws_security_group.mekadevops_cluster_sg.id]
  }
}

# OIDC Provider for IRSA
data "tls_certificate" "eks" {
  url = aws_eks_cluster.mekadevops.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.mekadevops.identity[0].oidc[0].issuer
}

# EBS CSI Driver IAM Role with IRSA
data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "mekadevops-ebs-csi-driver-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

# Updated EBS CSI Driver Addon
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.mekadevops.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_node_group.mekadevops,
    aws_iam_role_policy_attachment.ebs_csi_driver
  ]
}

resource "aws_eks_node_group" "mekadevops" {
  cluster_name = aws_eks_cluster.mekadevops.name
    node_group_name = "mekadevops-node-group"
    node_role_arn   = aws_iam_role.mekadevops_node_role.arn
    subnet_ids      = aws_subnet.mekadevops_subnet[*].id
    instance_types  = ["t2.medium"]

    scaling_config {
      desired_size = 3
      max_size     = 3
      min_size     = 3
    }

    remote_access {
      ec2_ssh_key = var.key_name
      source_security_group_ids = [aws_security_group.mekadevops_node_sg.id]
}
}

resource "aws_iam_role" "mekadevops_eks_role" {
  name = "mekadevops-eks-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "mekadevops_cluster_role_policy" {
  role = aws_iam_role.mekadevops_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "mekadevops_node_role" {
  name = "mekadevops-node-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "mekadevops_node_role_policy" {
  role = aws_iam_role.mekadevops_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "mekadevops_node_group_cni_policy" {
  role = aws_iam_role.mekadevops_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "mekadeveops_node_group_registry_policy" {
  role = aws_iam_role.mekadevops_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}