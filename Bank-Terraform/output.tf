output "cluster_id" {
  value = aws_eks_cluster.mekadevops.id
}

output "node_group_id" {
  value = aws_eks_node_group.mekadevops.id
}

output "vpc_id" {
  value = aws_vpc.mekadevops_vpc.id
}

output "subnet_ids" {
  value =aws_subnet.mekadevops_subnet[*].id
}