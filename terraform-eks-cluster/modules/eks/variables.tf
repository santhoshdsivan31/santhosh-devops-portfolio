variable "cluster_name"                { type = string }
variable "kubernetes_version"          { type = string; default = "1.29" }
variable "vpc_id"                      { type = string }
variable "private_subnet_ids"          { type = list(string) }
variable "public_endpoint"             { type = bool;   default = true }
variable "public_access_cidrs"         { type = list(string); default = ["0.0.0.0/0"] }
variable "system_node_instance_types"  { type = list(string); default = ["m5.large"] }
variable "system_node_desired"         { type = number; default = 2 }
variable "system_node_min"             { type = number; default = 2 }
variable "system_node_max"             { type = number; default = 4 }
variable "tags"                        { type = map(string); default = {} }
