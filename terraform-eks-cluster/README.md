# terraform-eks-cluster

Production-ready AWS EKS infrastructure built with Terraform. Reflects real patterns from managing 6 Kubernetes clusters across production, staging, and development environments.

## Architecture

```
VPC (3 AZs)
├── Public Subnets      → ALB, NAT Gateways
├── Private Subnets     → EKS worker nodes (Karpenter-managed)
└── Isolated Subnets    → RDS, ElastiCache

EKS Cluster
├── System Node Group   → CoreDNS, kube-proxy, critical add-ons
├── Karpenter           → dynamic spot/on-demand provisioning
├── KEDA                → event-driven pod autoscaling (Kafka, SQS, Redis)
├── External Secrets Operator → AWS Secrets Manager → K8s secrets
├── AWS Load Balancer Controller
└── IRSA                → pod-level IAM roles, zero static credentials
```

## Features

- Multi-AZ VPC with public / private / isolated subnet tiers
- EKS 1.29 with system managed node group + Karpenter for cost-efficient scaling
- IRSA (IAM Roles for Service Accounts) — no static AWS credentials in pods
- External Secrets Operator — automated sync from AWS Secrets Manager
- KEDA — scale pods to zero based on Kafka lag, SQS depth, Redis queue length
- Karpenter NodePools with spot-first, on-demand fallback
- Terraform remote state on S3 + DynamoDB locking
- VPC Flow Logs to CloudWatch

## Cost Optimisation

Patterns here achieved a 55% AWS cost reduction in production:
- Karpenter spot instance prioritisation with automatic on-demand fallback
- KEDA scale-to-zero for non-critical and async workloads
- NodePool CPU/memory limits preventing runaway scaling
- Resource labels compatible with Kubecost team/env/service attribution

## Prerequisites

- Terraform >= 1.6
- AWS CLI configured
- kubectl
- helm >= 3.12

## Quick Start

```bash
# 1. Clone and enter environment
cd environments/prod

# 2. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars

# 3. Initialise (creates S3 backend if needed)
terraform init

# 4. Plan and apply
terraform plan -out=tfplan
terraform apply tfplan

# 5. Configure kubectl
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name $(terraform output -raw cluster_name)

# 6. Verify
kubectl get nodes
kubectl get pods -n kube-system
```

## Module Structure

```
modules/
├── vpc/        VPC, subnets, NAT gateways, route tables, flow logs
├── eks/        EKS cluster, OIDC, system node group, add-ons, EBS CSI
├── karpenter/  Helm release, EC2NodeClass, NodePools, IAM
└── irsa/       Reusable IRSA role factory

environments/
├── prod/       m5.xlarge nodes, multi-AZ NAT, 2–20 Karpenter nodes
├── staging/    t3.large nodes, single NAT, 1–5 Karpenter nodes
└── dev/        t3.medium nodes, single NAT, 0–3 Karpenter nodes
```

## Author

**Santhosh Sivan** — DevOps & Platform Engineer
[linkedin.com/in/me-santhosh-sivan](https://www.linkedin.com/in/me-santhosh-sivan)
