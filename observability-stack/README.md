# observability-stack

Production observability stack deployed on Kubernetes using Helm and GitOps. Covers metrics, logs, alerting, and dashboards — reflecting the real setup used to monitor 42+ microservices, MongoDB clusters, and Kubernetes infrastructure.

## Stack

| Tool          | Purpose                              |
|---------------|--------------------------------------|
| Prometheus    | Metrics collection and storage       |
| Grafana       | Dashboards and visualisation         |
| Loki          | Log aggregation (Prometheus for logs)|
| Promtail      | Log shipper (runs as DaemonSet)      |
| Alertmanager  | Alert routing → Slack / PagerDuty   |
| AWS CloudWatch| AWS-native metrics and log groups    |

## Deploy

### Option A — Helm (recommended)

```bash
# Add repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Deploy kube-prometheus-stack (Prometheus + Grafana + Alertmanager + node-exporter)
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --values helm-values/kube-prometheus-stack.yaml

# Deploy Loki stack
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --values helm-values/loki-stack.yaml
```

### Option B — GitOps via ArgoCD

```bash
kubectl apply -f manifests/argocd-app.yaml
```

## Alerting

Alerts are defined in `manifests/alertmanager/` and cover:

- Kubernetes node pressure and pod crash-looping
- MongoDB replication lag and connection pool saturation
- High error rate (5xx) across HTTP services
- Karpenter node provisioning failures
- Disk and memory pressure warnings before they become pages

## Dashboards

Pre-built Grafana dashboards in `dashboards/`:

| Dashboard                  | Description                          |
|---------------------------|--------------------------------------|
| kubernetes-cluster.json   | Node CPU, memory, pod counts         |
| mongodb-overview.json     | Connections, ops/sec, replication    |
| karpenter-nodes.json      | Node provisioning, spot interruptions|
| application-overview.json | Request rate, error rate, latency    |

Import them via Grafana UI → Dashboards → Import → Upload JSON.

## Author

**Santhosh Sivan** — DevOps & Platform Engineer
[linkedin.com/in/me-santhosh-sivan](https://www.linkedin.com/in/me-santhosh-sivan)
