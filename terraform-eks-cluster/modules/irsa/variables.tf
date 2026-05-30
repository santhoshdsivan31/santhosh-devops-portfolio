variable "role_name_prefix"        { type = string }
variable "oidc_provider_arn"       { type = string }
variable "oidc_provider_url"       { type = string }
variable "namespace"               { type = string }
variable "service_account_name"    { type = string }
variable "inline_policy"           { type = string; default = "" }
variable "managed_policy_arns"     { type = list(string); default = [] }
variable "tags"                    { type = map(string); default = {} }
