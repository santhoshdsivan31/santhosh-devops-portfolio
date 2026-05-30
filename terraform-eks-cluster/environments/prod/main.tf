terraform {
  required_version = ">= 1.6"
  required_providers {
    aws    = { source = "hashicorp/aws",    version = "~> 5.0" }
    helm   = { source = "hashicorp/helm",   version = "~> 2.12" }
    kubectl = { source = "gavinbunney/kubectl", version = "~> 1.14" }
    tls    = { source = "hashicorp/tls",    version = "~> 4.0" }
  }
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "prod/eks/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = local.common_tags }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
  load_config_file = false
}

locals {
  common_tags = {
    Environment = "prod"
    Cluster     = var.cluster_name
    ManagedBy   = "terraform"
    Team        = "platform"
  }
}

module "vpc" {
  source       = "../../modules/vpc"
  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
  az_count     = 3
  single_nat   = false  # HA: one NAT per AZ in prod
  tags         = local.common_tags
}

module "eks" {
  source                     = "../../modules/eks"
  cluster_name               = var.cluster_name
  kubernetes_version         = var.kubernetes_version
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  public_endpoint            = true
  system_node_instance_types = ["m5.large"]
  system_node_desired        = 2
  system_node_min            = 2
  system_node_max            = 4
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
  karpenter_version = "v0.33.0"
  tags              = local.common_tags
}

# External Secrets Operator IRSA — grants ESO access to Secrets Manager
module "eso_irsa" {
  source               = "../../modules/irsa"
  role_name_prefix     = "${var.cluster_name}-eso"
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  namespace            = "external-secrets"
  service_account_name = "external-secrets"
  managed_policy_arns  = ["arn:aws:iam::aws:policy/SecretsManagerReadWrite"]
  tags                 = local.common_tags
}
