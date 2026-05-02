# Current Infrastructure State — Saved Before Destroy
# Date: May 2, 2026
# ⚠️  Use this file tomorrow to recreate everything from scratch.

---

## ENVIRONMENT SUMMARY

| Env | Cloud | Cluster | Region | Status |
|-----|-------|---------|--------|--------|
| **Production** | AWS | `retail-store-ffup` | `us-west-2` | 🟢 Running |
| **Dev** | AWS | `retail-store-dev-adp5` | `us-west-2` | 🟢 Running |
| **DR** | Azure | `retail-store-dr-sj4r` | `eastus` | 🟢 Running |

---

## PRODUCTION (AWS EKS)

| Item | Value |
|------|-------|
| Cluster Name | `retail-store-ffup` |
| Cluster Version | `1.33` |
| Region | `us-west-2` |
| VPC ID | `vpc-037b3ba4229ed3f1f` |
| VPC CIDR | `10.0.0.0/16` |
| Cluster Endpoint | `https://BBBCE3E30A73C8D9C10399DB6092DB4A.sk1.us-west-2.eks.amazonaws.com` |
| App URL | `http://k8s-ingressn-ingressn-1edffdf3f9-434002756bd28258.elb.us-west-2.amazonaws.com` |
| Grafana URL | *(reinstall monitoring after recreate — see Step 9 below)* |
| Namespace | `retail-store` |
| ArgoCD Branch | `gitops` |
| GitHub Actions Role | `arn:aws:iam::033484686218:role/github-actions-ecr-ffup` |

### Prod Subnets
- Private: `subnet-0dd66525a6631b809`, `subnet-09e7f2e2d4490a45f`, `subnet-0ff22cc0da284ba06`
- Public: `subnet-0712b179527de5250`, `subnet-0a535dbd8315f8975`, `subnet-00081f7886c754e5e`

---

## DEV (AWS EKS)

| Item | Value |
|------|-------|
| Cluster Name | `retail-store-dev-adp5` |
| Region | `us-west-2` |
| VPC ID | `vpc-08fc38d10143189ab` |
| VPC CIDR | `10.1.0.0/16` |
| Namespace | `retail-store-dev` |
| ArgoCD Branch | `dev` |

---

## DR (AZURE AKS)

| Item | Value |
|------|-------|
| Cluster Name | `retail-store-dr-sj4r` |
| Resource Group | `retail-store-dr-rg` |
| Region | `eastus` |
| Kubernetes Version | `1.33` |
| Node Size | `Standard_DC2s_v3` (2 vCPU, 8GB) |
| Node Count | 2 (min:1, max:2) |
| ACR Name | `retailstoredrsj4r` |
| ACR Login Server | `retailstoredrsj4r.azurecr.io` |
| Namespace | `retail-store-dr` |
| ArgoCD Branch | `dr` |

---

## ARGOCD CREDENTIALS (ALL ENVS)

| Env | Port-Forward | URL | User | Password |
|-----|-------------|-----|------|----------|
| Prod | `kubectl port-forward svc/argocd-server -n argocd 8080:443` | `http://localhost:8080` | `admin` | `admin@123` |
| Dev | `kubectl port-forward svc/argocd-server -n argocd 8081:443 --context dev` | `http://localhost:8081` | `admin` | `admin@123` |
| DR | `kubectl port-forward svc/argocd-server -n argocd 8082:443 --context dr` | `http://localhost:8082` | `admin` | `admin@123` |

---

## AWS IAM — gitops-user
> ⚠️ These CHANGE every terraform apply. Get fresh values after recreate:
```bash
cd terraform
terraform output -raw gitops_user_access_key_id
terraform output -raw gitops_user_secret_access_key
```
Current (will be invalid after destroy):
- Access Key ID: `AKIAQPS6XYOFNXQ5R6HC`

---

## AZURE SERVICE PRINCIPAL — dr-user-mgmt-sp
> These are PERMANENT (not destroyed with terraform destroy)

| Item | Value |
|------|-------|
| User | `dr-user-mgmt@shivanshusaxenaytgmail.onmicrosoft.com` |
| User Password | `DrUser@123!` |
| SP Client ID | `a115e404-5cf5-48ba-b0a2-d7843d7a3232` |
| Tenant ID | `85e6742e-8945-4d4a-86f5-b0ce51e32e46` |
| Subscription ID | `14652e0a-47e7-4d83-bc39-0947f8d35c58` |

> SP Client Secret: stored in GitHub Secret `AZURE_CREDENTIALS` — get from Azure Portal if needed

---

## GITHUB SECRETS (current values)

| Secret | Value | Changes on recreate? |
|--------|-------|---------------------|
| `AWS_ACCESS_KEY_ID` | `AKIAQPS6XYOFNXQ5R6HC` | ✅ YES — update after terraform apply |
| `AWS_SECRET_ACCESS_KEY` | *(run terraform output)* | ✅ YES |
| `AWS_REGION` | `us-west-2` | ❌ No |
| `AWS_ACCOUNT_ID` | `033484686218` | ❌ No |
| `AZURE_CREDENTIALS` | *(JSON SP — permanent)* | ❌ No |
| `AZURE_ACR_NAME` | `retailstoredrsj4r` | ✅ YES — suffix changes |
| `AZURE_ACR_LOGIN_SERVER` | `retailstoredrsj4r.azurecr.io` | ✅ YES |
| `AZURE_ACR_USERNAME` | `retailstoredrsj4r` | ✅ YES |
| `AZURE_ACR_PASSWORD` | *(run terraform output)* | ✅ YES |
| `AZURE_RESOURCE_GROUP` | `retail-store-dr-rg` | ❌ No |
| `AZURE_AKS_NAME` | `retail-store-dr-sj4r` | ✅ YES — suffix changes |

---

## RECREATE CHECKLIST (do in this exact order tomorrow)

### STEP 1 — Deploy Production (AWS)
```bash
cd terraform
terraform init
terraform apply -auto-approve
```
⏱️ ~15-20 min

### STEP 2 — Configure kubectl for Prod
```bash
aws eks list-clusters --region us-west-2
aws eks update-kubeconfig --region us-west-2 --name <new-cluster-name>
kubectl get nodes
```

### STEP 3 — Fix ArgoCD if helm shows "failed"
```bash
helm upgrade argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version 5.51.6 -n argocd \
  --reuse-values --wait --timeout 10m
terraform apply -auto-approve  # re-run to finish
```

### STEP 4 — Create ECR pull secret on Prod
```powershell
$token = aws ecr get-authorization-token --region us-west-2 --query 'authorizationData[0].authorizationToken' --output text
$password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($token)).Split(':')[1]
kubectl create namespace retail-store
kubectl create secret docker-registry regcred `
  --docker-server=033484686218.dkr.ecr.us-west-2.amazonaws.com `
  --docker-username=AWS --docker-password=$password `
  -n retail-store --dry-run=client -o yaml | kubectl apply -f -
```

### STEP 5 — Update GitHub Secrets with new IAM credentials
```bash
cd terraform
terraform output -raw gitops_user_access_key_id    # → AWS_ACCESS_KEY_ID
terraform output -raw gitops_user_secret_access_key # → AWS_SECRET_ACCESS_KEY
```
Update at: https://github.com/Shivanshusaxena2/retail-store-sample-app/settings/secrets/actions

### STEP 6 — Remove Karpenter taint if pods Pending
```bash
kubectl taint node --all karpenter.sh/disrupted:NoSchedule-
```

### STEP 7 — Deploy Dev (AWS)
```bash
cd terraform-dev
terraform init
terraform apply -auto-approve
```
⏱️ ~15-20 min

### STEP 8 — Configure kubectl for Dev
```bash
aws eks list-clusters --region us-west-2
aws eks update-kubeconfig --region us-west-2 --name <dev-cluster-name> --alias dev
```

### STEP 9 — Create ECR pull secret on Dev
```powershell
$token = aws ecr get-authorization-token --region us-west-2 --query 'authorizationData[0].authorizationToken' --output text
$password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($token)).Split(':')[1]
kubectl create namespace retail-store-dev --context dev
kubectl create secret docker-registry regcred `
  --docker-server=033484686218.dkr.ecr.us-west-2.amazonaws.com `
  --docker-username=AWS --docker-password=$password `
  -n retail-store-dev --context dev
```

### STEP 10 — Install Monitoring on Prod
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl apply -f monitoring/storageclass-ebs.yaml
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/values-prod.yaml
# Remove Karpenter taint if Prometheus pod is Pending:
kubectl taint node --all karpenter.sh/disrupted:NoSchedule-
# Get Grafana URL:
kubectl get svc monitoring-grafana -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### STEP 11 — Deploy DR (Azure)
```powershell
cd terraform-dr
$env:TF_VAR_azure_client_secret = "<SP_CLIENT_SECRET>"
terraform init
terraform apply -auto-approve
```
⏱️ ~10 min

### STEP 12 — Configure kubectl for DR
```bash
terraform output cluster_name  # get AKS name
az aks get-credentials --resource-group retail-store-dr-rg --name <aks-name> --context dr
kubectl get nodes --context dr
```

### STEP 13 — Update GitHub Secrets for DR (ACR changes each recreate)
```bash
cd terraform-dr
terraform output acr_name              # → AZURE_ACR_NAME
terraform output acr_login_server      # → AZURE_ACR_LOGIN_SERVER
terraform output -raw acr_admin_username  # → AZURE_ACR_USERNAME
terraform output -raw acr_admin_password  # → AZURE_ACR_PASSWORD
terraform output cluster_name          # → AZURE_AKS_NAME
```

### STEP 14 — Trigger CI pipelines to build images
```bash
# Prod (builds all 5 services → pushes to ECR → DR auto-mirrors to ACR)
git checkout gitops
git commit --allow-empty -m "ci: trigger prod pipeline after recreate"
git push origin gitops

# Dev
git checkout dev
git commit --allow-empty -m "ci: trigger dev pipeline after recreate"
git push origin dev
```
OR go to GitHub Actions → Run workflow manually for each.

### STEP 15 — Force ArgoCD refresh on Dev and DR
```bash
# Dev
for app in retail-store-dev-ui retail-store-dev-cart retail-store-dev-catalog retail-store-dev-checkout retail-store-dev-orders; do
  kubectl annotate application $app -n argocd argocd.argoproj.io/refresh=hard --overwrite --context dev
done

# DR
for app in retail-store-dr-ui retail-store-dr-cart retail-store-dr-catalog retail-store-dr-checkout retail-store-dr-orders; do
  kubectl annotate application $app -n argocd argocd.argoproj.io/refresh=hard --overwrite --context dr
done
```

### STEP 16 — Remove Karpenter taints if pods Pending
```bash
kubectl taint node --all karpenter.sh/disrupted:NoSchedule-
kubectl taint node --all karpenter.sh/disrupted:NoSchedule- --context dev
```

---

## DESTROY COMMANDS (run now)

```bash
# 1. Destroy DR first (Azure — fastest)
cd terraform-dr
$env:TF_VAR_azure_client_secret = "<SP_CLIENT_SECRET>"
terraform destroy -auto-approve

# 2. Destroy Dev (AWS)
cd ../terraform-dev
terraform destroy -auto-approve

# 3. Destroy Prod (AWS — last)
cd ../terraform
terraform destroy -auto-approve
```

---

## IMPORTANT NOTES FOR TOMORROW

1. **Cluster names change** every recreate (random suffix). Always run `aws eks list-clusters` first.
2. **ECR repos are deleted** with `terraform destroy` — CI will rebuild and push fresh images.
3. **ACR is deleted** with `terraform destroy` — DR CI will push fresh images after recreate.
4. **GitHub Secrets must be updated** after every recreate for AWS keys and Azure ACR details.
5. **ArgoCD password is `admin@123`** — baked into Terraform, set automatically.
6. **Karpenter taint** blocks pod scheduling — remove it whenever pods are stuck in Pending.
7. **Azure SP is permanent** — `dr-user-mgmt-sp` survives destroy, no need to recreate.
8. **Monitoring (Grafana)** — reinstall manually after prod cluster is up (Step 10).
9. **DR images** — CI auto-mirrors from ECR to ACR after prod deploy succeeds.
10. **Port-forward uses HTTP** — open `http://localhost:808X` not `https://`.

---

*Last updated: May 2, 2026*
*Prod: retail-store-ffup | Dev: retail-store-dev-adp5 | DR: retail-store-dr-sj4r*
