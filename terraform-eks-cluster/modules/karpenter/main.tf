# Karpenter IRSA
resource "aws_iam_role" "karpenter" {
  name = "${var.cluster_name}-karpenter"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:karpenter:karpenter"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_policy" "karpenter" {
  name = "${var.cluster_name}-karpenter"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate", "ec2:CreateFleet", "ec2:RunInstances",
          "ec2:CreateTags", "ec2:TerminateInstances", "ec2:DeleteLaunchTemplate",
          "ec2:DescribeLaunchTemplates", "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups", "ec2:DescribeSubnets",
          "ec2:DescribeInstanceTypes", "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones", "ec2:DescribeSpotPriceHistory"
        ]
        Resource = "*"
      },
      { Effect = "Allow", Action = ["ssm:GetParameter"], Resource = "arn:aws:ssm:*:*:parameter/aws/service/*" },
      { Effect = "Allow", Action = ["iam:PassRole"], Resource = var.node_role_arn },
      { Effect = "Allow", Action = ["eks:DescribeCluster"], Resource = "arn:aws:eks:*:*:cluster/${var.cluster_name}" },
      { Effect = "Allow", Action = ["pricing:GetProducts"], Resource = "*" }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter" {
  role       = aws_iam_role.karpenter.name
  policy_arn = aws_iam_policy.karpenter.arn
}

resource "aws_iam_instance_profile" "karpenter" {
  name = "KarpenterNodeInstanceProfile-${var.cluster_name}"
  role = var.node_role_name
  tags = var.tags
}

# Karpenter Helm release
resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_version

  set { name = "settings.clusterName";      value = var.cluster_name }
  set { name = "settings.clusterEndpoint";  value = var.cluster_endpoint }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter.arn
  }
  set { name = "controller.resources.requests.cpu";    value = "250m" }
  set { name = "controller.resources.requests.memory"; value = "512Mi" }
  set { name = "controller.resources.limits.cpu";      value = "1" }
  set { name = "controller.resources.limits.memory";   value = "1Gi" }

  depends_on = [aws_iam_role_policy_attachment.karpenter]
}

# EC2NodeClass — tells Karpenter which subnets/SGs to use
resource "kubectl_manifest" "ec2_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2
      role: ${var.node_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            kubernetes.io/cluster/${var.cluster_name}: owned
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 50Gi
            volumeType: gp3
            encrypted: true
      tags:
        Name: karpenter-node-${var.cluster_name}
        karpenter.sh/discovery: ${var.cluster_name}
  YAML
  depends_on = [helm_release.karpenter]
}

# NodePool — general workloads, spot preferred
resource "kubectl_manifest" "node_pool_general" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: general
    spec:
      template:
        metadata:
          labels:
            nodepool: general
        spec:
          nodeClassRef:
            name: default
          requirements:
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot", "on-demand"]
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["m", "c", "r"]
            - key: karpenter.k8s.aws/instance-generation
              operator: Gt
              values: ["4"]
          expireAfter: 720h
      limits:
        cpu: "100"
        memory: 400Gi
      disruption:
        consolidationPolicy: WhenUnderutilized
        consolidateAfter: 30s
  YAML
  depends_on = [kubectl_manifest.ec2_node_class]
}
