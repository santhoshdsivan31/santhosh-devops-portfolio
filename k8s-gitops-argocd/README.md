# k8s-gitops-argocd

GitOps-driven Kubernetes delivery platform using ArgoCD. Reflects real CI/CD patterns used to enable multiple production deployments per hour with zero-downtime rollouts across 42+ microservices.

## Structure

```
bootstrap/          ArgoCD install + App of Apps root application
clusters/
├── prod/           Cluster-level config (ingress, cert-manager, ESO, KEDA)
└── staging/        Staging cluster config
apps/
├── production/     ApplicationSet definitions for production workloads
└── staging/        ApplicationSet definitions for staging workloads
charts/
└── sample-app/     Reusable Helm chart template for microservices
```

## How it works

```
Git push → GitHub Actions (build + push image) → update image tag in Git
                                                        ↓
                                              ArgoCD detects diff
                                                        ↓
                                        ArgoCD syncs → Kubernetes rollout
                                                        ↓
                                        Health check passes → done
                                        Health check fails  → auto-rollback
```

## Bootstrap a new cluster

```bash
# 1. Install ArgoCD
kubectl apply -n argocd -f bootstrap/argocd-install.yaml

# 2. Wait for ArgoCD to be ready
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s

# 3. Apply the App of Apps (this kicks off everything else)
kubectl apply -f bootstrap/app-of-apps.yaml

# 4. Get the initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo

# 5. Port-forward to access the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Deploying a new microservice

1. Copy `charts/sample-app` and rename it for your service
2. Add an `Application` manifest under `apps/production/`
3. Push to Git — ArgoCD picks it up automatically

## Image updates

GitHub Actions builds the image, then updates the tag via:

```bash
# In your CI pipeline
yq e '.image.tag = "'$IMAGE_TAG'"' -i charts/my-service/values-prod.yaml
git commit -am "ci: update my-service to $IMAGE_TAG"
git push
```

ArgoCD detects the change and rolls out within seconds.

## Author

**Santhosh Sivan** — DevOps & Platform Engineer
[linkedin.com/in/me-santhosh-sivan](https://www.linkedin.com/in/me-santhosh-sivan)
