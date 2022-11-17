terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

provider "aws" {
  region = var.region
}

#this is to be able to acceess the cluster to create some resources
provider "kubernetes" {
  config_path = "~/.kube/config"
  host        = data.aws_eks_cluster.my-cluster.endpoint
  token       = data.aws_eks_cluster_auth.my-cluster.token
  #must search how to get it
  #cluster_ca_certificate = base64decode(data.aws_eks_cluster.my-cluster.certificate authority.0.data)
}
