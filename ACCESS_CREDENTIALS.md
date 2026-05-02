# 🔐 Project Access Credentials & URLs
# Retail Store Sample App — All Environments
#
# ⚠️  IMPORTANT: This file is updated every time infra is recreated.
# ⚠️  Cluster names, URLs and keys change on every terraform apply.
# ⚠️  DO NOT commit real secrets — this file uses placeholders for keys.
#     Get live values using the commands listed in each section.
#
# Last Updated: May 2, 2026
# ============================================================

---

## 🌐 APPLICATION URLs

| Environment | URL | Status |
|-------------|-----|--------|
| **Production** | `http://k8s-ingressn-ingressn-<hash>.elb.us-west-2.amazonaws.com` | 🟢 Live |
| **Dev** | `http://k8s-ingressn-ingressn-<hash>.elb.us-west-2.amazonaws.com` | 🟢 Live |
| **DR (Azure)** | `http://<azure-lb-ip>` | 🔄 Deploying |

### Get live URLs:
```bash
# Production
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Dev
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' --context dev

# DR (Azure - returns IP not hostname)
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --context dr
```

---

## 📊 MONITORING — GRAFANA

| Environment | URL | Username | Password |
|-------------|-----|----------|----------|
| **Production** | `http://k8s-monitori-monitori-b261f6e07f-cebc77a3d98116e3.elb.us-west-2.amazonaws.com` | `admin` | `admin@123` |
| **DR (Azure)** | `http://<azure-grafana-ip>` | `admin` | `admin@123` |

### Get live Grafana URLs:
```bash
# Production
kubectl get svc monitoring-grafana -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# DR (Azure)
kubectl get svc monitoring-grafana -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --context dr
```

---

## 🔄 ARGOCD

| Environment | Port-Forward Command | URL | Username | Password |
|-------------|---------------------|-----|----------|----------|
| **Production** | `kubectl port-forward svc/argocd-server -n argocd 8080:443` | `http://localhost:8080` | `admin` | `admin@123` |
| **Dev** | `kubectl port-forward svc/argocd-server -n argocd 8081:443 --context dev` | `http://localhost:8081` | `admin` | `admin@123` |
| **DR (Azure)** | `kubectl port-forward svc/argocd-server -n argocd 8082:443 --context dr` | `http://localhost:8082` | `admin` | `admin@123` |

---

## ☸️ KUBERNETES CLUSTERS

| Environment | Cloud | Cluster Name | Region | kubectl Context |
|-------------|-------|-------------|--------|----------------|
| **Production** | AWS | `retail-store-ffup` | `us-west-2` | `arn:aws:eks:us-west-2:033484686218:cluster/retail-store-ffup` |
| **Dev** | AWS | `retail-store-dev-adp5` | `us-west-2` | `dev` |
| **DR** | Azure | `retail-store-dr-<suffix>` | `centralindia` | `dr` |

### Configure kubectl:
```bash
# Production
aws eks update-kubeconfig --region us-west-2 --name retail-store-ffup

# Dev
aws eks update-kubeconfig --region us-west-2 --name retail-store-dev-adp5 --alias dev

# DR (Azure) — run after terraform apply completes
az aks get-credentials --resource-group retail-store-dr-rg --name <aks-name> --context dr
# Get AKS name: cd terraform-dr && terraform output cluster_name
```

---

## 🔑 AWS CREDENTIALS

### AWS Account
| Item | Value |
|------|-------|
| Account ID | `033484686218` |
| Region | `us-west-2` |
| Console | https://033484686218.signin.aws.amazon.com/console |

### IAM User: gitops-user (for GitHub Actions CI/CD)
> ⚠️ These change every `terraform apply`. Always get fresh values:
```bash
cd terraform
terraform output -raw gitops_user_access_key_id
terraform output -raw gitops_user_secret_access_key
```

| Secret Name | Current Value |
|-------------|--------------|
| `AWS_ACCESS_KEY_ID` | `AKIAQPS6XYOFNXQ5R6HC` *(update after recreate)* |
| `AWS_SECRET_ACCESS_KEY` | *(run terraform output to get)* |
| `AWS_REGION` | `us-west-2` |
| `AWS_ACCOUNT_ID` | `033484686218` |

### ECR Repositories
| Service | ECR URL |
|---------|---------|
| UI | `033484686218.dkr.ecr.us-west-2.amazonaws.com/retail-store-ui` |
| Catalog | `033484686218.dkr.ecr.us-west-2.amazonaws.com/retail-store-catalog` |
| Cart | `033484686218.dkr.ecr.us-west-2.amazonaws.com/retail-store-cart` |
| Checkout | `033484686218.dkr.ecr.us-west-2.amazonaws.com/retail-store-checkout` |
| Orders | `033484686218.dkr.ecr.us-west-2.amazonaws.com/retail-store-orders` |

### ECR Login:
```bash
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin \
  033484686218.dkr.ecr.us-west-2.amazonaws.com
```

---

## 🔵 AZURE CREDENTIALS (DR Environment)

### Azure Account
| Item | Value |
|------|-------|
| Subscription ID | `14652e0a-47e7-4d83-bc39-0947f8d35c58` |
| Tenant ID | `85e6742e-8945-4d4a-86f5-b0ce51e32e46` |
| Tenant Domain | `shivanshusaxenaytgmail.onmicrosoft.com` |
| Portal | https://portal.azure.com |

### Azure Users
| User | UPN | Password | Role |
|------|-----|----------|------|
| Admin | `shivanshusaxenayt@gmail.com` | *(your Azure password)* | Owner |
| DR Manager | `dr-user-mgmt@shivanshusaxenaytgmail.onmicrosoft.com` | `DrUser@123!` | Contributor |

### Service Principal: dr-user-mgmt-sp (for Terraform + GitHub Actions)
| Item | Value |
|------|-------|
| Client ID | `a115e404-5cf5-48ba-b0a2-d7843d7a3232` |
| Client Secret | *(stored in GitHub Secret: AZURE_CREDENTIALS — never commit)* |
| Tenant ID | `85e6742e-8945-4d4a-86f5-b0ce51e32e46` |
| Subscription ID | `14652e0a-47e7-4d83-bc39-0947f8d35c58` |

### ACR (Azure Container Registry)
> Get after terraform apply:
```bash
cd terraform-dr
terraform output acr_login_server
terraform output -raw acr_admin_username
terraform output -raw acr_admin_password
```

---

## 🐙 GITHUB

| Item | Value |
|------|-------|
| Repository | https://github.com/Shivanshusaxena2/retail-store-sample-app |
| Secrets Page | https://github.com/Shivanshusaxena2/retail-store-sample-app/settings/secrets/actions |
| Actions Page | https://github.com/Shivanshusaxena2/retail-store-sample-app/actions |

### GitHub Secrets (update after every terraform apply)
| Secret | Value | How to get |
|--------|-------|-----------|
| `AWS_ACCESS_KEY_ID` | *(changes each recreate)* | `terraform output -raw gitops_user_access_key_id` |
| `AWS_SECRET_ACCESS_KEY` | *(changes each recreate)* | `terraform output -raw gitops_user_secret_access_key` |
| `AWS_REGION` | `us-west-2` | Fixed |
| `AWS_ACCOUNT_ID` | `033484686218` | Fixed |
| `AZURE_CREDENTIALS` | *(JSON SP credentials)* | See Azure SP section above |
| `AZURE_ACR_NAME` | *(after DR deploy)* | `terraform output acr_name` in terraform-dr/ |
| `AZURE_ACR_LOGIN_SERVER` | *(after DR deploy)* | `terraform output acr_login_server` in terraform-dr/ |
| `AZURE_ACR_USERNAME` | *(after DR deploy)* | `terraform output -raw acr_admin_username` in terraform-dr/ |
| `AZURE_ACR_PASSWORD` | *(after DR deploy)* | `terraform output -raw acr_admin_password` in terraform-dr/ |
| `AZURE_RESOURCE_GROUP` | `retail-store-dr-rg` | Fixed |
| `AZURE_AKS_NAME` | *(after DR deploy)* | `terraform output cluster_name` in terraform-dr/ |

---

## 🌿 GIT BRANCHES

| Branch | Purpose | CI Workflow | Deploys To |
|--------|---------|-------------|-----------|
| `main` | Stable prod mirror | None (auto-promoted) | — |
| `gitops` | Production | `deploy.yml` | Prod EKS |
| `dev` | Development | `deploy-dev.yml` | Dev EKS |
| `dr` | Disaster Recovery | `deploy-dr.yml` | DR AKS (Azure) |

---

## 🔧 TERRAFORM DIRECTORIES

| Directory | Environment | Cloud |
|-----------|-------------|-------|
| `terraform/` | Production | AWS |
| `terraform-dev/` | Development | AWS |
| `terraform-dr/` | Disaster Recovery | Azure |

---

## 📋 DAILY CHECKLIST (when recreating infra)

### After `terraform apply` (prod):
- [ ] Run `aws eks update-kubeconfig --region us-west-2 --name <new-cluster-name>`
- [ ] Create `regcred` secret in `retail-store` namespace
- [ ] Update `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in GitHub Secrets
- [ ] Trigger prod CI: `git commit --allow-empty -m "ci: trigger" && git push origin gitops`
- [ ] Remove Karpenter taint if pods Pending: `kubectl taint node --all karpenter.sh/disrupted:NoSchedule-`
- [ ] Update this file with new cluster name and URLs

### After `terraform apply` (dev):
- [ ] Run `aws eks update-kubeconfig --region us-west-2 --name <new-cluster-name> --alias dev`
- [ ] Create `regcred` secret in `retail-store-dev` namespace
- [ ] Force ArgoCD refresh on dev apps
- [ ] Trigger dev CI: `git commit --allow-empty -m "ci: trigger" && git push origin dev`
- [ ] Update this file with new dev cluster name and URL

### After `terraform apply` (DR):
- [ ] Run `az aks get-credentials --resource-group retail-store-dr-rg --name <aks-name> --context dr`
- [ ] Install monitoring: `helm upgrade --install monitoring ... -f monitoring/values-dr.yaml --context dr`
- [ ] Update GitHub Secrets with ACR credentials
- [ ] Update this file with DR cluster name, ACR name, and URLs

---

## 🚨 EMERGENCY CONTACTS & FAILOVER

### DR Failover (AWS → Azure)
```bash
# Trigger via GitHub Actions
# Actions → Deploy DR (Azure) → Run workflow → force_failover: yes

# Or manually scale up DR
kubectl scale deployment --all --replicas=2 -n retail-store-dr --context dr
```

### Get DR app URL after failover
```bash
kubectl get svc -n ingress-nginx --context dr \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'
```

---

*This file is auto-updated. Last infrastructure state: May 2, 2026*
*Prod cluster: retail-store-ffup | Dev cluster: retail-store-dev-adp5 | DR: deploying*
