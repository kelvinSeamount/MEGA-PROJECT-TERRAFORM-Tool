Overview

This Terraform configuration creates a production-ready EKS cluster in the eu-central-1 region with the following resources:

VPC with 2 public subnets across multiple availability zones
EKS cluster with managed node group
Security groups for cluster and worker nodes
IAM roles and policies for EKS operations
EBS CSI driver addon for persistent storage

Architecture

Region: eu-central-1
VPC CIDR: 10.0.0.0/16
Subnets: 2 public subnets in eu-central-1a and eu-central-1b
Node Group: 3 t2.medium instances
SSH Access: Enabled via security group
