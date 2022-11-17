data "aws_availability_zones" "azs" {
  state = "available"
}

#to get the cluster (we need this in the kubernetes provider)
data "aws_eks_cluster" "my-cluster" {
  name = var.cluster_name
}

#to get the token, we need this in the kuebernetes provider
data "aws_eks_cluster_auth" "my-cluster" {
  name = var.cluster_name
}
