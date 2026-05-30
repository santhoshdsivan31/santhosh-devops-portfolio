output "karpenter_role_arn"          { value = aws_iam_role.karpenter.arn }
output "node_instance_profile_name"  { value = aws_iam_instance_profile.karpenter.name }
