variable "cluster_name"      { type = string }
variable "vpc_cidr"          { type = string; default = "10.0.0.0/16" }
variable "az_count"          { type = number; default = 3 }
variable "single_nat"        { type = bool;   default = false; description = "Use single NAT GW (cost saving for non-prod)" }
variable "enable_flow_logs"  { type = bool;   default = true }
variable "tags"              { type = map(string); default = {} }
