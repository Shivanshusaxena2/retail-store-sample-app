# Retail Store Infrastructure — Runbook & Recreate Guide

This document covers everything needed to recreate this infrastructure from scratch.
Keep this updated as the setup evolves.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites — Tools to Install](#2-prerequisites--tools-to-install)
3. [Required Code Changes Before Deploying](#3-required-code-changes-before-deploying)
4. [GitHub Secrets Setup](#4-github-secrets-setup)
5. [Deploy Production Infrastructure](#5-deploy-production-infrastructure)
6. [Deploy Dev Infrastructure](#6-deploy-dev-infrastructure)
7. [Post-Deploy Steps (Both Envs)](#7-post-deploy-steps-both-envs)
8. [Accessing Everything](#8-accessing-everything)
9. [Known Issues & Fixes](#9-known-issues--fixes)
10. [Destroy & Recreate](#10-destroy--recreate)
11. [Quick Reference](#11-quick-reference)

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  PRODUCTION                                                      │
│  Branch: gitops  │  Cluster: retail-store-xxxx                  │
│  Namespace: retail-store  │  VPC: 10.0.0.0/16                   │
│  Terraform: terraform/                                           │
│  ArgoCD apps: argocd/applications/  (targetRevision: gitops)    │
│  CI: .github/workflows/deploy.yml                               │
│  Images: private ECR (prod tags e.g. 7a1d96c)                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  DEV                                                             │
│  Branch: dev  │  Cluster: retail-store-dev-xxxx                 │
│  Namespace: retail-store-dev  │  VPC: 10.1.0.0/16              │
│  Terraform: terraform-dev/                                       │
│  ArgoCD apps: argocd-dev/applications/ (targetRevision: dev)    │
│  CI: .github/workflows/deploy-dev.yml                           │
│  Images: private ECR (dev- prefix tags e.g. dev-e8f7fd4)        │
└─────────────────────────────────────────────────────────────────┘

CI/CD Flow:
  Push src/** to gitops → deploy.yml → build+push ECR → ArgoCD syncs prod
  Push src/** to dev    → deploy-dev.yml → build+push ECR → ArgoCD syncs dev
  Prod deploy success   → promote-to-main.yml → merge gitops→main
```

---

## 2. Prerequisites — Tools to Install

### Install kubectl (Windows — no admin needed)
```powershell
New-Item -ItemType Directory -Path "$env:USERPROFILE\bin" -Force
curl.exe -L -o "$env:USERPROFILE\bin\kubectl.exe" `
  "https://dl.k8s.io/release/v1.33.1/bin/windows/amd64/kubectl.exe"
$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
[Environment]::SetEnvironmentVariable('PATH', "$env:USERPROFILE\bin;$currentPath", 'User')
$env:PATH = "$env:USERPROFILE\bin;" + $env:PATH
kubectl version --client
```

### Install Helm
```powershell
winget install Helm.Helm --accept-package-agreements --accept-source-agreements
```

### Install Terraform
Download from https://developer.hashicorp.com/terraform/downloads
Extract `terraform.exe` to `C:\Terraform\` (already in PATH).

### Install Docker Desktop
```powershell
winget install Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
# Restart machine after install, then launch Docker Desktop
```

### Install GitHub CLI (optional, for triggering workflows)
```powershell
winget install GitHub.cli --accept-package-agreements --accept-source-agreements
```

### Configure AWS CLI
```bash
aws configure
# Region: us-west-2
# Output: json
```

---

## 3. Required Code Changes Before Deploying

### 3.1 — GitHub Repo URL in ArgoCD files
If you fork or rename the repo, update `repoURL` in ALL these files:
- `argocd/applications/retail-store-ui.yaml`
- `argocd/applications/retail-store-catalog.yaml`
- `argocd/applications/retail-store-cart.yaml`
- `argocd/applications/retail-store-checkout.yaml`
- `argocd/applications/retail-store-orders.yaml`
- `argocd/projects/retail-store-project.yaml`
- `argocd-dev/applications/retail-store-dev-*.yaml`
- `argocd-dev/projects/retail-store-dev-project.yaml`

Current value: `https://github.com/Shivanshusaxena2/retail-store-sample-app`

### 3.2 — GitHub Repo in github-oidc.tf
```hcl
# terraform/github-oidc.tf and terraform-dev/ (if added)
locals {
  github_repo = "Shivanshusaxena2/retail-store-sample-app"  # update if repo changes
}
```

### 3.3 — AWS Region / Account ID
Default region is `us-west-2`. To change:
- `terraform/variables.tf` → `aws_region`
- `terraform-dev/variables.tf` → `aws_region`
- All `values-dev.yaml` files → ECR URLs contain account ID `033484686218`

---

## 4. GitHub Secrets Setup

Go to: **GitHub repo → Settings → Secrets and variables → Actions**

| Secret | Value | Notes |
|--------|-------|-------|
| `AWS_ACCESS_KEY_ID` | From terraform output | Run `terraform output -raw gitops_user_access_key_id` |
| `AWS_SECRET_ACCESS_KEY` | From terraform output | Run `terraform output -raw gitops_user_secret_access_key` |
| `AWS_REGION` | `us-west-2` | |
| `AWS_ACCOUNT_ID` | `033484686218` | Your 12-digit AWS account ID |

> **Important:** Get credentials AFTER `terraform apply` completes — Terraform creates the `gitops-user` IAM user with exact ECR permissions needed.

---

## 5. Deploy Production Infrastructure

```bash
cd terraform

# Initialize
terraform init

# Review
terraform plan

# Deploy (~15-20 min)
terraform apply
```

### After apply completes:

```bash
# Get cluster name from output
terraform output cluster_name

# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name <cluster-name>

# Verify nodes
kubectl get nodes
```

### Fix ArgoCD if helm shows "failed" status:
```bash
helm upgrade argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version 5.51.6 \
  -n argocd \
  --reuse-values \
  --wait \
  --timeout 10m

# Then re-run terraform apply to finish ArgoCD apps
terraform apply
```

### Create ECR pull secret on prod cluster:
```powershell
$token = aws ecr get-authorization-token --region us-west-2 --query 'authorizationData[0].authorizationToken' --output text
$decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($token))
$password = $decoded.Split(':')[1]
kubectl create secret docker-registry regcred `
  --docker-server=033484686218.dkr.ecr.us-west-2.amazonaws.com `
  --docker-username=AWS `
  --docker-password=$password `
  -n retail-store --dry-run=client -o yaml | kubectl apply -f -
```

### Update GitHub Secrets with new credentials:
```bash
terraform output -raw gitops_user_access_key_id
terraform output -raw gitops_user_secret_access_key
```
Update `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in GitHub Secrets.

### Fix image tags if pods show ImagePullBackOff:
```bash
# Check what tags exist in ECR
aws ecr list-images --repository-name retail-store-ui --region us-west-2 --query 'imageIds[?imageTag!=`latest`].imageTag'

# Update values.yaml for affected services with the correct tag
# Then commit and push to gitops branch
```

### Remove Karpenter disruption taint if pods are Pending:
```bash
kubectl taint node --all karpenter.sh/disrupted:NoSchedule-
```

---

## 6. Deploy Dev Infrastructure

```bash
cd terraform-dev

# Initialize
terraform init

# Deploy (~15-20 min)
terraform apply
```

### After apply completes:

```bash
# Get dev cluster name
terraform output cluster_name

# Add dev context with alias
aws eks update-kubeconfig --region us-west-2 --name <dev-cluster-name> --alias dev

# Verify
kubectl get nodes --context dev
```

### Create ECR pull secret on dev cluster:
```powershell
$token = aws ecr get-authorization-token --region us-west-2 --query 'authorizationData[0].authorizationToken' --output text
$decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($token))
$password = $decoded.Split(':')[1]
kubectl create namespace retail-store-dev --context dev
kubectl create secret docker-registry regcred `
  --docker-server=033484686218.dkr.ecr.us-west-2.amazonaws.com `
  --docker-username=AWS `
  --docker-password=$password `
  -n retail-store-dev --context dev
```

### Force ArgoCD to sync dev apps:
```bash
for app in retail-store-dev-ui retail-store-dev-cart retail-store-dev-catalog retail-store-dev-checkout retail-store-dev-orders; do
  kubectl annotate application $app -n argocd argocd.argoproj.io/refresh=hard --overwrite --context dev
done
```

### Remove Karpenter taint on dev if pods are Pending:
```bash
kubectl taint node --all karpenter.sh/disrupted:NoSchedule- --context dev
```

---

## 7. Post-Deploy Steps (Both Envs)

### Trigger CI pipeline to build and push images:

**Production** — push a change to `src/` on `gitops` branch:
```bash
git checkout gitops
git commit --allow-empty -m "ci: trigger prod pipeline"
git push origin gitops
```

**Dev** — push a change to `src/` on `dev` branch:
```bash
git checkout dev
git commit --allow-empty -m "ci: trigger dev pipeline"
git push origin dev
```

### Verify ArgoCD apps are healthy:
```bash
# Prod
kubectl get applications -n argocd

# Dev
kubectl get applications -n argocd --context dev
```

---

## 8. Accessing Everything

### Production App URL:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Dev App URL:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' --context dev
```

### Production ArgoCD UI (port 8080):
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: http://localhost:8080
# User: admin
# Password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### Dev ArgoCD UI (port 8081):
```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443 --context dev
# Open: http://localhost:8081
# User: admin
# Password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" --context dev | base64 -d
```

### ECR Login (for manual docker operations):
```bash
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin \
  033484686218.dkr.ecr.us-west-2.amazonaws.com
```

---

## 9. Known Issues & Fixes

### Issue 1 — ArgoCD `context deadline exceeded` in Terraform
**Fix:** `timeout = 600` and `wait = true` already added to `terraform/argocd.tf`.
If it still fails, run helm upgrade manually (see Section 5), then re-run `terraform apply`.

### Issue 2 — kubectl not in PATH after new session
**Fix:** Open a new terminal — the PATH update is permanent.
Or run: `$env:PATH = "$env:USERPROFILE\bin;" + $env:PATH`

### Issue 3 — Stale kubeconfig after cluster recreation
**Symptom:** `dial tcp: lookup XXXX.gr7.us-west-2.eks.amazonaws.com: no such host`
**Fix:**
```bash
aws eks list-clusters --region us-west-2
aws eks update-kubeconfig --region us-west-2 --name <new-cluster-name>
```

### Issue 4 — ImagePullBackOff on catalog or cart
**Symptom:** Old image tags from previous cluster don't exist in new ECR
**Fix:** Check ECR for available tags, update `values.yaml` or `values-dev.yaml`:
```bash
aws ecr list-images --repository-name retail-store-catalog --region us-west-2
```
Update tag in `src/catalog/chart/values.yaml` (prod) or `src/catalog/chart/values-dev.yaml` (dev), commit and push.

### Issue 5 — Pods stuck in Pending (Karpenter taint)
**Symptom:** `0/1 nodes available: 1 node(s) had untolerated taint {karpenter.sh/disrupted}`
**Fix:**
```bash
# Prod
kubectl taint node --all karpenter.sh/disrupted:NoSchedule-

# Dev
kubectl taint node --all karpenter.sh/disrupted:NoSchedule- --context dev
```

### Issue 6 — Dev app shows 500 error
**Symptom:** UI can't reach backend services
**Fix:** Ensure `src/ui/chart/values-dev.yaml` has correct dev service endpoints:
```yaml
app:
  endpoints:
    catalog: http://retail-store-dev-catalog:80
    carts: http://retail-store-dev-cart-carts:80
    orders: http://retail-store-dev-orders:80
    checkout: http://retail-store-dev-checkout:80
```

### Issue 7 — Dev pods OOMKilled or slow to start
**Symptom:** Spring Boot apps crash on 2vCPU/4GB node
**Fix:** `values-dev.yaml` already has reduced resource requests (`50m CPU, 128-256Mi memory`).
If node is still too small, Karpenter will provision a larger one automatically.

### Issue 8 — GitHub Actions "invalid security token"
**Fix:** Get fresh credentials from Terraform and update GitHub Secrets:
```bash
cd terraform
terraform output -raw gitops_user_access_key_id
terraform output -raw gitops_user_secret_access_key
```

### Issue 9 — `regcred` secret missing after cluster recreation
**Symptom:** `Unable to retrieve some image pull secrets (regcred)`
**Fix:** Re-create the secret (see Section 5 and 6 above).

### Issue 10 — Docker not found
**Fix:** Install Docker Desktop, restart machine, launch Docker Desktop before running any docker commands.

---

## 10. Destroy & Recreate

### Destroy Dev:
```bash
cd terraform-dev
terraform destroy
```

### Destroy Production:
```bash
cd terraform
terraform destroy
```

> After destroy, the cluster name changes (new random suffix). Always run `aws eks update-kubeconfig` with the new name.

### Full Recreate Order:
1. `terraform apply` in `terraform/` (prod) — ~15-20 min
2. Update kubeconfig for prod
3. Fix ArgoCD if needed (helm upgrade)
4. Create `regcred` secret on prod
5. Update GitHub Secrets with new IAM credentials from terraform output
6. `terraform apply` in `terraform-dev/` (dev) — ~15-20 min
7. Update kubeconfig for dev with `--alias dev`
8. Create `regcred` secret on dev
9. Force ArgoCD refresh on dev apps
10. Remove Karpenter taints if pods are Pending
11. Trigger CI pipelines to build fresh images

---

## 11. Quick Reference

| Item | Value |
|------|-------|
| AWS Region | `us-west-2` |
| AWS Account ID | `033484686218` |
| Prod cluster name pattern | `retail-store-<4-char-random>` |
| Dev cluster name pattern | `retail-store-dev-<4-char-random>` |
| Prod namespace | `retail-store` |
| Dev namespace | `retail-store-dev` |
| Prod VPC CIDR | `10.0.0.0/16` |
| Dev VPC CIDR | `10.1.0.0/16` |
| ArgoCD chart version | `5.51.6` |
| Prod ArgoCD port-forward | `8080` |
| Dev ArgoCD port-forward | `8081` |
| GitHub repo | `https://github.com/Shivanshusaxena2/retail-store-sample-app` |
| Prod branch | `gitops` |
| Dev branch | `dev` |
| Prod CI workflow | `.github/workflows/deploy.yml` |
| Dev CI workflow | `.github/workflows/deploy-dev.yml` |
| Promote workflow | `.github/workflows/promote-to-main.yml` |
| Prod Terraform dir | `terraform/` |
| Dev Terraform dir | `terraform-dev/` |
| Prod ArgoCD apps dir | `argocd/applications/` |
| Dev ArgoCD apps dir | `argocd-dev/applications/` |

---

*Last updated: May 2026*
