variable "aws_region"          { type = string; default = "ap-south-1" }
variable "cluster_name"        { type = string; default = "prod-eks" }
variable "vpc_cidr"            { type = string; default = "10.0.0.0/16" }
variable "kubernetes_version"  { type = string; default = "1.29" }
