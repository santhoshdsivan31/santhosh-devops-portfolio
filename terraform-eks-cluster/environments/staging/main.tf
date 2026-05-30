terraform {
  required_version = ">= 1.6"
  required_providers {
    aws     = { source = "hashicorp/aws",        version = "~> 5.0" }
    helm    = { source = "hashicorp/helm",        version = "~> 2.12" }
    kubectl = { source = "gavinbunney/kubectl",   version = "~> 1.14" }
    tls     = { source = "hashicorp/tls",         version = "~> 4.0" }
  }
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "staging/eks/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws"    { region = var.aws_region }
provider "helm"   {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca)
    exec { api_version = "client.authentication.k8s.io/v1beta1"; command = "aws"; args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name] }
  }
}
provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca)
  exec { api_version = "client.authentication.k8s.io/v1beta1"; command = "aws"; args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name] }
  load_config_file = false
}

locals {
  common_tags = { Environment = "staging", Cluster = var.cluster_name, ManagedBy = "terraform", Team = "platform" }
}

module "vpc" {
  source       = "../../modules/vpc"
  cluster_name = var.cluster_name
  vpc_cidr     = "10.1.0.0/16"
  az_count     = 2
  single_nat   = true   # cost saving for non-prod
  tags         = local.common_tags
}

module "eks" {
  source                     = "../../modules/eks"
  cluster_name               = var.cluster_name
  kubernetes_version         = "1.29"
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  system_node_instance_types = ["t3.large"]
  system_node_desired        = 1
  system_node_min            = 1
  system_node_max            = 2
  tags                       = local.common_tags
}

module "karpenter" {
  source            = "../../modules/karpenter"
  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  node_role_arn     = module.eks.node_role_arn
  node_role_name    = module.eks.node_role_name
  tags              = local.common_tags
}

variable "aws_region"   { default = "ap-south-1" }
variable "cluster_name" { default = "staging-eks" }

output "cluster_name"     { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
