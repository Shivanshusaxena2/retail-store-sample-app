# Retail Store Infrastructure — Runbook & Change Guide

This document covers every change required when recreating this infrastructure,
known issues encountered, and the fixes applied. Keep this updated as the setup evolves.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Required Code Changes Before Deploying](#2-required-code-changes-before-deploying)
3. [GitHub Secrets Setup](#3-github-secrets-setup)
4. [Deployment Steps](#4-deployment-steps)
5. [Post-Deploy Manual Steps](#5-post-deploy-manual-steps)
6. [Known Issues & Fixes](#6-known-issues--fixes)
7. [Accessing the Application](#7-accessing-the-application)
8. [Destroying & Recreating Infrastructure](#8-destroying--recreating-infrastructure)
9. [Tools Required on Your Machine](#9-tools-required-on-your-machine)

---

## 1. Prerequisites

### AWS Account
- AWS CLI configured with credentials that have admin or sufficient IAM permissions
- Account ID: `033484686218` (update if using a different account)
- Region: `us-west-2` (default — change in `terraform/variables.tf` if needed)

### Required IAM Permissions
The AWS user/role running Terraform needs:
- `eks:*`
- `ec2:*`
- `iam:*`
- `ecr:*`
- `elasticloadbalancing:*`
- `autoscaling:*`

### Tools to Install on Windows
| Tool | How to Install | Notes |
|------|---------------|-------|
| AWS CLI v2 | [aws.amazon.com/cli](https://aws.amazon.com/cli/) | Already in PATH at `C:\Program Files\Amazon\AWSCLIV2\` |
| kubectl | See Section 9 | Must be manually placed in PATH |
| Helm v3 | `winget install Helm.Helm` | Already installed via winget |
| Terraform | Download from hashicorp.com, place in `C:\Terraform\` | Already in PATH |
| Docker Desktop | `winget install Docker.DockerDesktop` | Requires restart after install |
| Git | `winget install Git.Git` | Required for GitOps workflow |

---

## 2. Required Code Changes Before Deploying

These are the values you **must update** every time you recreate the infrastructure.

### 2.1 — GitHub Repository URL (ArgoCD Applications)

Every ArgoCD application YAML points to a hardcoded GitHub repo URL.
Update all 5 files if you fork or rename the repository.

**Files to update:**
- `argocd/applications/retail-store-ui.yaml`
- `argocd/applications/retail-store-catalog.yaml`
- `argocd/applications/retail-store-cart.yaml`
- `argocd/applications/retail-store-checkout.yaml`
- `argocd/applications/retail-store-orders.yaml`
- `argocd/projects/retail-store-project.yaml`

**What to change:**
```yaml
# Current value (change this if repo is different)
repoURL: https://github.com/Shivanshusaxena2/retail-store-sample-app

# Also in projects/retail-store-project.yaml
sourceRepos:
  - 'https://github.com/Shivanshusaxena2/retail-store-sample-app'
```

### 2.2 — Target Branch in ArgoCD Applications

Currently all ArgoCD apps point to `main`. If deploying the GitOps (CI/CD) workflow,
change to `gitops` branch.

```yaml
# For GitOps/production workflow — change in all 5 application YAMLs
targetRevision: gitops   # was: main
```

### 2.3 — ArgoCD Helm Chart — Fix Deprecated Config

In `terraform/argocd.tf`, the `server.extraArgs["--insecure"]` setting is deprecated
in ArgoCD chart v5.x+. Replace it to avoid warnings and future breakage.

**Current (deprecated):**
```hcl
server = {
  extraArgs = ["--insecure"]
}
```

**Fix — replace with:**
```hcl
configs = {
  params = {
    "server.insecure" = true
  }
}
```

Full corrected block in `terraform/argocd.tf`:
```hcl
values = [
  yamlencode({
    configs = {
      params = {
        "server.insecure" = true
      }
    }
    server = {
      service = {
        type = "ClusterIP"
      }
      ingress = {
        enabled = false
      }
    }
    # ... rest of controller/repoServer/redis blocks unchanged
  })
]
```

### 2.4 — Terraform Helm Release Timeout

The default Terraform timeout for `helm_release` is 5 minutes, which is too short
for ArgoCD on a fresh cluster. Add `timeout` to prevent the `context deadline exceeded` error.

**File:** `terraform/argocd.tf`

Add this inside the `helm_release "argocd"` resource:
```hcl
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.argocd_namespace
  create_namespace = true
  timeout          = 600   # <-- ADD THIS (10 minutes)
  wait             = true  # <-- ADD THIS

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  # ...
}
```

### 2.5 — AWS Region

Default region is `us-west-2`. To change it, update `terraform/variables.tf`:
```hcl
variable "aws_region" {
  default = "us-west-2"   # Change this
}
```

### 2.6 — Kubernetes Version

Default is `1.33`. Check EKS supported versions before deploying.
Update in `terraform/variables.tf`:
```hcl
variable "kubernetes_version" {
  default = "1.33"   # Verify this is still supported
}
```

---

## 3. GitHub Secrets Setup

Required for the GitOps CI/CD pipeline (`.github/workflows/deploy.yml`).
Go to: **GitHub repo → Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key | IAM user with ECR + EKS permissions |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key | Paired with above |
| `AWS_REGION` | `us-west-2` | Must match Terraform region |
| `AWS_ACCOUNT_ID` | `033484686218` | Your 12-digit AWS account ID |

> **Security note:** Use an IAM user with least-privilege permissions, not root credentials.
> Rotate keys regularly.

---

## 4. Deployment Steps

### Step 1 — Clone and configure
```bash
git clone https://github.com/Shivanshusaxena2/retail-store-sample-app
cd retail-store-sample-app
```
Apply changes from Section 2 above.

### Step 2 — Initialize Terraform
```bash
cd terraform
terraform init
```

### Step 3 — Review the plan
```bash
terraform plan
```
Check that EKS cluster, VPC, node groups, ArgoCD, cert-manager, and ingress-nginx are all listed.

### Step 4 — Apply
```bash
terraform apply
```
This takes approximately **15–20 minutes** for the full stack.

### Step 5 — Update kubeconfig
After apply completes, get the cluster name from Terraform output or AWS CLI:
```bash
aws eks list-clusters --region us-west-2
aws eks update-kubeconfig --region us-west-2 --name <cluster-name>
kubectl get nodes
```

### Step 6 — Verify ArgoCD
```bash
kubectl get pods -n argocd
helm list -n argocd
```
All pods should be `Running` and helm status should be `deployed`.

---

## 5. Post-Deploy Manual Steps

### 5.1 — If ArgoCD helm shows "failed" status

This happens when Terraform times out but ArgoCD is actually running fine.
Fix by running helm upgrade manually:

```bash
helm upgrade argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version 5.51.6 \
  -n argocd \
  --reuse-values \
  --wait \
  --timeout 10m
```

Then re-run `terraform apply` — it will continue from where it left off.

### 5.2 — Get ArgoCD Admin Password
```bash
# PowerShell
kubectl -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath="{.data.password}" | `
  ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Bash/Linux
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```
Username: `admin`

> **Note:** The password is unique per cluster — it changes every time you recreate the infrastructure. Never hardcode it. Always fetch it fresh with the command above.

### 5.3 — Access ArgoCD UI
```bash
kubectl port-forward service/argocd-server -n argocd 8080:443
```
Open: `http://localhost:8080`

### 5.4 — Deploy App Services (main branch / manual)
```bash
# Add helm repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add incubator https://charts.helm.sh/incubator
helm repo update

# Update dependencies
helm dependency update src/assets/chart
helm dependency update src/catalog/chart
helm dependency update src/carts/chart
helm dependency update src/checkout/chart
helm dependency update src/orders/chart

# Create namespace
kubectl create namespace retail-store

# Deploy all services
helm upgrade --install assets    src/assets/chart    -n retail-store
helm upgrade --install catalog   src/catalog/chart   -n retail-store
helm upgrade --install carts     src/carts/chart     -n retail-store
helm upgrade --install checkout  src/checkout/chart  -n retail-store
helm upgrade --install orders    src/orders/chart    -n retail-store
helm upgrade --install ui        src/ui/chart        -n retail-store \
  -f src/ui/chart/values-nginx-ingress.yaml
```

### 5.5 — GitOps Branch Setup (production workflow)
```bash
# Create and push gitops branch
git checkout -b gitops
git push -u origin gitops
```
This triggers GitHub Actions to build all service images and push to private ECR.

### 5.6 — ECR Login (for manual docker operations)
```bash
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin \
  033484686218.dkr.ecr.us-west-2.amazonaws.com
```
Note: Docker Desktop must be running before this command.

---

## 6. Known Issues & Fixes

### Issue 1 — `kubectl` not found in PowerShell PATH
**Symptom:** `kubectl : The term 'kubectl' is not recognized`
**Cause:** kubectl.exe was downloaded to the `terraform/` folder but not added to PATH.
**Fix:**
```powershell
# Copy to user bin folder and add to PATH
New-Item -ItemType Directory -Path "$env:USERPROFILE\bin" -Force
Copy-Item 'terraform\kubectl.exe' "$env:USERPROFILE\bin\kubectl.exe" -Force
$env:PATH = "$env:USERPROFILE\bin;" + $env:PATH
[Environment]::SetEnvironmentVariable('PATH', "$env:USERPROFILE\bin;" + [Environment]::GetEnvironmentVariable('PATH','User'), 'User')
```
Or download fresh:
```powershell
curl.exe -L -o "$env:USERPROFILE\bin\kubectl.exe" `
  "https://dl.k8s.io/release/v1.33.1/bin/windows/amd64/kubectl.exe"
```

### Issue 2 — ArgoCD `context deadline exceeded` in Terraform
**Symptom:** `helm_release.argocd: Still creating... [06m00s elapsed]` then timeout
**Cause:** Default Terraform helm_release timeout (5 min) is too short for ArgoCD startup.
**Fix:** Add `timeout = 600` to the `helm_release "argocd"` resource (see Section 2.4).
If already hit, run the `helm upgrade` command from Section 5.1, then re-run `terraform apply`.

### Issue 3 — `kubectl` pointing to old/destroyed cluster
**Symptom:** `dial tcp: lookup XXXX.gr7.us-west-2.eks.amazonaws.com: no such host`
**Cause:** kubeconfig still has the old cluster endpoint after `terraform destroy` + `apply`.
**Fix:**
```bash
aws eks list-clusters --region us-west-2
aws eks update-kubeconfig --region us-west-2 --name <new-cluster-name>
```

### Issue 4 — `docker` not found
**Symptom:** `docker : The term 'docker' is not recognized`
**Cause:** Docker Desktop not installed or not started.
**Fix:**
```powershell
winget install Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
# Then restart your machine and launch Docker Desktop
```

### Issue 5 — PowerShell `Invoke-WebRequest` / `WebClient` fails silently
**Symptom:** Downloads fail with no clear error using PowerShell web cmdlets.
**Cause:** TLS/SSL handling issue in PowerShell on this Windows Server environment.
**Fix:** Always use `curl.exe` (built into Windows 10+) instead:
```powershell
curl.exe -L -o output.file "https://example.com/file"
```

### Issue 6 — `git checkout gitops` fails
**Symptom:** `error: pathspec 'gitops' did not match any file(s) known to git`
**Cause:** The `gitops` branch doesn't exist yet — it must be created.
**Fix:**
```bash
git checkout -b gitops
git push -u origin gitops
```

### Issue 7 — ArgoCD deprecated `server.extraArgs` warning
**Symptom:** `DEPRECATED option server.extraArgs."--insecure"`
**Cause:** ArgoCD chart v5.x changed the config key.
**Fix:** Update `terraform/argocd.tf` as described in Section 2.3.

---

## 7. Accessing the Application

### ArgoCD UI
```bash
kubectl port-forward service/argocd-server -n argocd 8080:443
# Open: http://localhost:8080
# User: admin  |  Password: (from Section 5.2)
```

### Retail Store UI
```bash
kubectl port-forward service/ui -n retail-store 8081:80
# Open: http://localhost:8081
```

### Get Load Balancer URL (if ingress is configured)
```bash
kubectl get ingress -n retail-store
kubectl get service -n ingress-nginx
```

---

## 8. Destroying & Recreating Infrastructure

### Destroy
```bash
cd terraform
terraform destroy
```
> This deletes the EKS cluster, VPC, all node groups, and all resources.
> The kubeconfig will become stale — update it after recreating.

### Recreate
1. Run `terraform apply` again
2. The cluster name will have a **new random suffix** (e.g., `retail-store-8rwj` → `retail-store-xxxx`) because of `random_string.suffix` in `locals.tf`
3. Run `aws eks update-kubeconfig` with the new cluster name
4. If ArgoCD helm shows `failed`, run the helm upgrade fix from Section 5.1
5. Re-run `terraform apply` to finish applying ArgoCD projects and applications

---

## 9. Tools Required on Your Machine

### Install kubectl (Windows — no admin required)
```powershell
# Create user bin folder
New-Item -ItemType Directory -Path "$env:USERPROFILE\bin" -Force

# Download kubectl
curl.exe -L -o "$env:USERPROFILE\bin\kubectl.exe" `
  "https://dl.k8s.io/release/v1.33.1/bin/windows/amd64/kubectl.exe"

# Add to PATH permanently
$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
[Environment]::SetEnvironmentVariable('PATH', "$env:USERPROFILE\bin;$currentPath", 'User')

# Add to current session
$env:PATH = "$env:USERPROFILE\bin;" + $env:PATH

# Verify
kubectl version --client
```

### Install Helm (Windows)
```powershell
winget install Helm.Helm
```

### Install Terraform (Windows)
Download from https://developer.hashicorp.com/terraform/downloads
Extract `terraform.exe` to `C:\Terraform\` (already in PATH on this machine).

### Install Docker Desktop (Windows)
```powershell
winget install Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
# Restart machine after install
```

### Configure AWS CLI
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-west-2), Output format (json)
```

---

## Quick Reference — Cluster Info

| Item | Value |
|------|-------|
| AWS Region | `us-west-2` |
| AWS Account ID | `033484686218` |
| Cluster Name Pattern | `retail-store-<4-char-random>` |
| ArgoCD Namespace | `argocd` |
| App Namespace | `retail-store` |
| ArgoCD Chart Version | `5.51.6` |
| GitHub Repo | `https://github.com/Shivanshusaxena2/retail-store-sample-app` |
| Main Branch | `main` — public images, manual deploy |
| GitOps Branch | `gitops` — private ECR, automated CI/CD |

---

*Last updated: May 2026*
