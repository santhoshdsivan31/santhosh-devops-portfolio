variable "cluster_name"       { type = string }
variable "cluster_endpoint"   { type = string }
variable "oidc_provider_arn"  { type = string }
variable "oidc_provider_url"  { type = string }
variable "node_role_arn"      { type = string }
variable "node_role_name"     { type = string }
variable "karpenter_version"  { type = string; default = "v0.33.0" }
variable "tags"               { type = map(string); default = {} }
