# Disaster Recovery (DR) Runbook
# Azure AKS — DR Environment for Retail Store

---

## Table of Contents

1. [DR Architecture](#1-dr-architecture)
2. [DR Strategy](#2-dr-strategy)
3. [Prerequisites](#3-prerequisites)
4. [Deploy DR Infrastructure](#4-deploy-dr-infrastructure)
5. [GitHub Secrets for DR](#5-github-secrets-for-dr)
6. [How DR Pipeline Works](#6-how-dr-pipeline-works)
7. [Failover Procedure](#7-failover-procedure)
8. [Failback Procedure](#8-failback-procedure)
9. [Accessing DR Environment](#9-accessing-dr-environment)
10. [Known Issues & Fixes](#10-known-issues--fixes)
11. [Quick Reference](#11-quick-reference)

---

## 1. DR Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  PRIMARY — AWS (us-west-2)                                        │
│                                                                    │
│  EKS: retail-store-xxxx        EKS: retail-store-dev-xxxx        │
│  ECR: 033484686218.dkr.ecr.us-west-2.amazonaws.com               │
│  Branch: gitops                Branch: dev                        │
│  Namespace: retail-store       Namespace: retail-store-dev        │
└──────────────────────────────────────────────────────────────────┘
                    │
                    │  After every prod deploy:
                    │  Images mirrored ECR → ACR
                    │  Helm values updated on dr branch
                    ▼
┌──────────────────────────────────────────────────────────────────┐
│  DR — AZURE (centralindia)                                        │
│                                                                    │
│  AKS: retail-store-dr-xxxx                                        │
│  ACR: retailstoredrXXXX.azurecr.io                               │
│  Branch: dr                                                        │
│  Namespace: retail-store-dr                                        │
│  ArgoCD: port 8082                                                │
│                                                                    │
│  Status: WARM (running at 1 replica, ready to scale up)          │
└──────────────────────────────────────────────────────────────────┘
```

### Component Mapping

| Component | AWS Primary | Azure DR |
|-----------|-------------|----------|
| Kubernetes | EKS 1.33 | AKS 1.32 |
| Container Registry | AWS ECR | Azure ACR |
| Load Balancer | AWS NLB | Azure Load Balancer |
| VPC/VNet | 10.0.0.0/16 | 10.2.0.0/16 |
| GitOps | ArgoCD → gitops branch | ArgoCD → dr branch |
| Images | Private ECR tags | Mirrored to ACR |

---

## 2. DR Strategy

**Warm DR** — The DR environment runs at reduced capacity (1 replica per service).
On failover, it scales to full production capacity within ~2 minutes.

### RTO / RPO

| Metric | Target | Notes |
|--------|--------|-------|
| **RTO** (Recovery Time Objective) | ~5 minutes | Time to activate DR and serve traffic |
| **RPO** (Recovery Point Objective) | ~10 minutes | Max data loss (last image sync interval) |

### Image Sync Frequency
- Images are mirrored from ECR → ACR **automatically after every prod deploy**
- DR always has the latest prod image available in ACR
- Manual sync available via `workflow_dispatch` on `deploy-dr.yml`

---

## 3. Prerequisites

### Azure CLI
```bash
az --version  # must be >= 2.0
az login
az account show  # verify correct subscription
```

### DR User Account
All DR operations use the dedicated `dr-user-mgmt` account:

| Item | Value |
|------|-------|
| User | `dr-user-mgmt@shivanshusaxenaytgmail.onmicrosoft.com` |
| Password | `DrUser@123!` |
| Role | Contributor on subscription |
| Service Principal | `dr-user-mgmt-sp` |
| SP Client ID | `a115e404-5cf5-48ba-b0a2-d7843d7a3232` |
| SP Tenant ID | `85e6742e-8945-4d4a-86f5-b0ce51e32e46` |

### Login as dr-user-mgmt
```bash
az login --username dr-user-mgmt@shivanshusaxenaytgmail.onmicrosoft.com --password DrUser@123!
```

### Terraform uses Service Principal automatically
The `terraform-dr/variables.tf` has the SP credentials configured.
Set the secret via environment variable before running terraform:
```powershell
# Get the secret from your password manager or Azure portal
# Never commit the actual secret value
$env:TF_VAR_azure_client_secret = "<SP_CLIENT_SECRET>"
terraform apply -auto-approve
```

---

## 4. Deploy DR Infrastructure

```bash
cd terraform-dr

# Initialize (downloads Azure provider)
terraform init

# Review what will be created
terraform plan

# Deploy (~10-15 min)
terraform apply
```

### What gets created
- Azure Resource Group: `retail-store-dr-rg`
- Virtual Network: `10.2.0.0/16`
- AKS Cluster: `retail-store-dr-xxxx` (2 nodes, Standard_D2s_v3)
- Azure Container Registry (ACR): `retailstoredrXXXX`
- ArgoCD installed on AKS
- ArgoCD apps pointing to `dr` branch

### After apply completes

```bash
# Get cluster name
terraform output cluster_name

# Configure kubectl
az aks get-credentials \
  --resource-group retail-store-dr-rg \
  --name <cluster-name> \
  --context dr

# Verify
kubectl get nodes --context dr
```

---

## 5. GitHub Secrets for DR

Go to: **GitHub repo → Settings → Secrets and variables → Actions**

Add these secrets:

| Secret | How to get | Description |
|--------|-----------|-------------|
| `AZURE_CREDENTIALS` | See below | Service principal JSON |
| `AZURE_ACR_NAME` | `terraform output acr_name` | ACR name (e.g. `retailstoredrxxxx`) |
| `AZURE_ACR_LOGIN_SERVER` | `terraform output acr_login_server` | e.g. `retailstoredrxxxx.azurecr.io` |
| `AZURE_ACR_USERNAME` | `terraform output -raw acr_admin_username` | ACR admin username |
| `AZURE_ACR_PASSWORD` | `terraform output -raw acr_admin_password` | ACR admin password |
| `AZURE_RESOURCE_GROUP` | `retail-store-dr-rg` | Resource group name |
| `AZURE_AKS_NAME` | `terraform output cluster_name` | AKS cluster name |

### Create AZURE_CREDENTIALS (Service Principal)

```bash
# Create service principal with Contributor role
az ad sp create-for-rbac \
  --name "retail-store-dr-sp" \
  --role Contributor \
  --scopes /subscriptions/14652e0a-47e7-4d83-bc39-0947f8d35c58 \
  --sdk-auth
```

Copy the entire JSON output and save as `AZURE_CREDENTIALS` secret.

---

## 6. How DR Pipeline Works

### Automatic (after every prod deploy)

```
1. Developer pushes to src/ on gitops branch
         ↓
2. deploy.yml runs → builds prod images → pushes to ECR
         ↓
3. deploy-dr.yml triggers automatically (workflow_run)
         ↓
4. For each service (ui, catalog, cart, checkout, orders):
   - Pull latest image from ECR
   - Push to ACR with same tag + dr-latest tag
   - Update src/<service>/chart/values-dr.yaml with ACR image
   - Commit to dr branch
         ↓
5. ArgoCD on AKS detects dr branch change
         ↓
6. ArgoCD syncs → deploys updated images to retail-store-dr namespace
```

### Manual Trigger (image sync only)

```bash
# Via GitHub Actions UI:
# Actions → Deploy DR (Azure) → Run workflow → force_failover: no
```

### Manual Full Failover

```bash
# Via GitHub Actions UI:
# Actions → Deploy DR (Azure) → Run workflow → force_failover: yes
```

---

## 7. Failover Procedure

Use this when AWS primary is down or degraded.

### Step 1 — Trigger failover via GitHub Actions
```
GitHub → Actions → Deploy DR (Azure) → Run workflow
Set force_failover = yes
```

### Step 2 — Verify DR is serving traffic
```bash
# Get DR load balancer IP
kubectl get svc -n ingress-nginx --context dr \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'
```

### Step 3 — Update DNS (if using custom domain)
Point `retail-store.trainwithshubham.com` CNAME/A record to the Azure Load Balancer IP.

### Step 4 — Scale DR to full capacity (if not done by workflow)
```bash
for svc in ui catalog cart checkout orders; do
  kubectl scale deployment retail-store-dr-${svc} \
    --replicas=2 -n retail-store-dr --context dr
done
```

### Step 5 — Verify all pods are running
```bash
kubectl get pods -n retail-store-dr --context dr
kubectl get applications -n argocd --context dr
```

---

## 8. Failback Procedure

Use this when AWS primary is restored.

### Step 1 — Verify AWS primary is healthy
```bash
kubectl get pods -n retail-store
kubectl get applications -n argocd
```

### Step 2 — Update DNS back to AWS
Point `retail-store.trainwithshubham.com` back to the AWS NLB hostname.

### Step 3 — Scale DR back to warm standby
```bash
for svc in ui catalog cart checkout orders; do
  kubectl scale deployment retail-store-dr-${svc} \
    --replicas=1 -n retail-store-dr --context dr
done
```

### Step 4 — Verify DR is back to warm state
```bash
kubectl get pods -n retail-store-dr --context dr
```

---

## 9. Accessing DR Environment

### DR App URL
```bash
# Get Azure Load Balancer IP (note: IP not hostname, unlike AWS)
kubectl get svc -n ingress-nginx --context dr \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'

# Access: http://<IP>
```

### DR ArgoCD UI (port 8082)
```bash
kubectl port-forward svc/argocd-server -n argocd 8082:443 --context dr
# Open: http://localhost:8082
# Username: admin
# Password: admin@123
```

### ACR Image List
```bash
# List images in ACR
az acr repository list --name <acr-name> --output table

# List tags for a service
az acr repository show-tags --name <acr-name> --repository retail-store-ui
```

---

## 10. Known Issues & Fixes

### Issue 1 — AKS nodes not ready after deploy
```bash
az aks get-credentials --resource-group retail-store-dr-rg --name <cluster-name> --context dr
kubectl get nodes --context dr
```

### Issue 2 — ACR pull fails in AKS
AKS is configured with `attached_acr_id_map` — no imagePullSecrets needed.
If still failing:
```bash
az aks update --resource-group retail-store-dr-rg --name <cluster-name> \
  --attach-acr <acr-name>
```

### Issue 3 — ArgoCD apps show Unknown after deploy
```bash
for app in retail-store-dr-ui retail-store-dr-cart retail-store-dr-catalog retail-store-dr-checkout retail-store-dr-orders; do
  kubectl annotate application $app -n argocd argocd.argoproj.io/refresh=hard --overwrite --context dr
done
```

### Issue 4 — dr branch doesn't exist
```bash
git checkout -b dr
git push -u origin dr
```

### Issue 5 — values-dr.yaml missing
The CI pipeline creates these automatically on first run.
To create manually:
```bash
# Run the DR workflow manually from GitHub Actions
# Actions → Deploy DR (Azure) → Run workflow → force_failover: no
```

### Issue 6 — Azure service principal expired
```bash
az ad sp create-for-rbac \
  --name "retail-store-dr-sp" \
  --role Contributor \
  --scopes /subscriptions/14652e0a-47e7-4d83-bc39-0947f8d35c58 \
  --sdk-auth
# Update AZURE_CREDENTIALS secret in GitHub
```

---

## 11. Quick Reference

| Item | Value |
|------|-------|
| Azure Subscription | `14652e0a-47e7-4d83-bc39-0947f8d35c58` |
| Azure Tenant | `85e6742e-8945-4d4a-86f5-b0ce51e32e46` |
| Azure Region | `centralindia` |
| Resource Group | `retail-store-dr-rg` |
| VNet CIDR | `10.2.0.0/16` |
| AKS Version | `1.32` |
| Node Size | `Standard_D2s_v3` (2 vCPU, 8GB) |
| DR Namespace | `retail-store-dr` |
| DR Branch | `dr` |
| DR CI Workflow | `.github/workflows/deploy-dr.yml` |
| Terraform Dir | `terraform-dr/` |
| ArgoCD Apps Dir | `argocd-dr/applications/` |
| ArgoCD Port | `8082` |
| ArgoCD Password | `admin@123` |
| DR Strategy | Warm (1 replica standby) |
| RTO | ~5 minutes |
| RPO | ~10 minutes |

### Destroy DR
```bash
cd terraform-dr
terraform destroy
```

---

*Last updated: May 2026*
