
module "eks-vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.18.1"

   name = "eks-vpc"
   cidr = var.vpc_cidr_block

  azs             = data.aws_availability_zones.azs.names
  private_subnets = var.private_subnet_cidr_blocks
  public_subnets  = var.public_subnet_cidr_blocks
 
  #For networking purposes
  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true

  #For logging purposes
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  #these tags are required, for the K8s controller manager 
  #to be able to identify which vpc and subnet it should connect to
  tags = {
     "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
  }

}