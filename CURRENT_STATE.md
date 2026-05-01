# Current Infrastructure State — Saved Before Destroy
# Date: May 1, 2026
# Use this to recreate everything tomorrow

---

## PRODUCTION CLUSTER

| Item | Value |
|------|-------|
| Cluster Name | `retail-store-8rwj` |
| Cluster Version | `1.33` |
| Region | `us-west-2` |
| VPC ID | `vpc-0bc85095963c92d3a` |
| VPC CIDR | `10.0.0.0/16` |
| Cluster Endpoint | `https://2457DCD098FB1AAC99DDBB6923A1D3D3.gr7.us-west-2.eks.amazonaws.com` |
| OIDC Issuer | `https://oidc.eks.us-west-2.amazonaws.com/id/2457DCD098FB1AAC99DDBB6923A1D3D3` |
| Security Group | `sg-0d1f872029988b0c1` |
| GitHub Actions Role | `arn:aws:iam::033484686218:role/github-actions-ecr-8rwj` |

### Prod Subnets
- Private: `subnet-05495c6344100dd1a`, `subnet-0d794b558eb50f4f0`, `subnet-0617e445bcfc5216c`
- Public: `subnet-036265c50a6a9dbb8`, `subnet-08256f9b14a4d6eba`, `subnet-05c721dac113d11bb`

### Prod App Status (at time of destroy)
- All 5 ArgoCD apps: **Synced + Healthy**
- Namespace: `retail-store`
- Branch: `gitops`

---

## DEV CLUSTER

| Item | Value |
|------|-------|
| Cluster Name | `retail-store-dev-5u69` |
| Region | `us-west-2` |
| VPC ID | `vpc-0e4979d9c0414af8f` |
| VPC CIDR | `10.1.0.0/16` |
| Cluster Endpoint | `https://4DB579ED88045B48C658AD58114D65E0.gr7.us-west-2.eks.amazonaws.com` |

### Dev App Status (at time of destroy)
- All 5 ArgoCD apps: **Synced + Healthy**
- Namespace: `retail-store-dev`
- Branch: `dev`

---

## IAM CREDENTIALS (gitops-user)
> These are saved in GitHub Secrets. After recreate, get new ones from terraform output.

| Secret | How to get |
|--------|------------|
| AWS_ACCESS_KEY_ID | `cd terraform && terraform output -raw gitops_user_access_key_id` |
| AWS_SECRET_ACCESS_KEY | `cd terraform && terraform output -raw gitops_user_secret_access_key` |
| AWS_REGION | `us-west-2` |
| AWS_ACCOUNT_ID | `033484686218` |

> **NOTE:** After `terraform apply` tomorrow, the gitops-user gets NEW credentials.
> Run these to get them and update GitHub Secrets:
> ```bash
> cd terraform
> terraform output -raw gitops_user_access_key_id
> terraform output -raw gitops_user_secret_access_key
> ```

---

## ECR REPOSITORIES (these SURVIVE terraform destroy)

ECR repos are created with `force_delete = true` in terraform.
The repos and images will be DELETED when you run `terraform destroy`.

Current image tags in ECR:
| Service | Prod Tags | Dev Tags |
|---------|-----------|----------|
| ui | `7a1d96c`, `8bd007f`, `latest` | `dev-e8f7fd4`, `dev-latest` |
| catalog | `7a1d96c`, `fe5b385`, `latest` | `dev-e8f7fd4`, `dev-c193778`, `dev-latest` |
| cart | `7a1d96c`, `fe5b385`, `latest` | `dev-e8f7fd4`, `dev-c193778`, `dev-latest` |
| checkout | `7a1d96c`, `latest` | `dev-e8f7fd4`, `dev-latest` |
| orders | `7a1d96c`, `latest` | `dev-e8f7fd4`, `dev-latest` |

> After recreate, the CI pipeline will build and push fresh images automatically.
> Just push any change to `src/` on `gitops` branch (prod) or `dev` branch (dev).

---

## ARGOCD CREDENTIALS

| Environment | URL | Username | Password |
|-------------|-----|----------|----------|
| Production | `http://localhost:8080` (port-forward) | `admin` | `admin@123` |
| Dev | `http://localhost:8081` (port-forward) | `admin` | `admin@123` |

Password is baked into Terraform — will be set automatically on recreate.

---

## CURRENT IMAGE TAGS IN HELM VALUES

### Production (src/*/chart/values.yaml)
| Service | Repository | Tag |
|---------|-----------|-----|
| ui | `033484686218.dkr.ecr.us-west-2.amazonaws.com/retail-store-ui` | `8bd007f` |
| catalog | `033484686218.dkr.ecr.us-west-2.amazonaws.com/retail-store-catalog` | `7a1d96c` |
| cart | `033484686218.dkr.ecr.us-west-2.amazonaws.com/retail-store-cart` | `7a1d96c` |
| checkout | `public.ecr.aws/aws-containers/retail-store-sample-checkout` | `1.2.2` |
| orders | `public.ecr.aws/aws-containers/retail-store-sample-orders` | `1.2.2` |

### Dev (src/*/chart/values-dev.yaml)
| Service | Repository | Tag |
|---------|-----------|-----|
| ui | `033484686218.dkr.ecr.us-west-2.amazonaws.com/retail-store-ui` | `dev-e8f7fd4` |
| catalog | `033484686218.dkr.ecr.us-west-2.amazonaws.com/retail-store-catalog` | `dev-e8f7fd4` |
| cart | `033484686218.dkr.ecr.us-west-2.amazonaws.com/retail-store-cart` | `dev-e8f7fd4` |
| checkout | `033484686218.dkr.ecr.us-west-2.amazonaws.com/retail-store-checkout` | `dev-e8f7fd4` |
| orders | `033484686218.dkr.ecr.us-west-2.amazonaws.com/retail-store-orders` | `dev-e8f7fd4` |

---

## RECREATE CHECKLIST (do in this order tomorrow)

### Step 1 — Deploy Production
```bash
cd terraform
terraform init
terraform apply
```

### Step 2 — Configure kubectl for prod
```bash
aws eks update-kubeconfig --region us-west-2 --name <new-cluster-name>
# cluster name will be retail-store-XXXX (new random suffix)
```

### Step 3 — Fix ArgoCD if helm shows "failed"
```bash
helm upgrade argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version 5.51.6 -n argocd \
  --reuse-values --wait --timeout 10m
terraform apply  # re-run to finish ArgoCD apps
```

### Step 4 — Create ECR pull secret on prod
```powershell
$token = aws ecr get-authorization-token --region us-west-2 --query 'authorizationData[0].authorizationToken' --output text
$decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($token))
$password = $decoded.Split(':')[1]
kubectl create secret docker-registry regcred `
  --docker-server=033484686218.dkr.ecr.us-west-2.amazonaws.com `
  --docker-username=AWS --docker-password=$password `
  -n retail-store --dry-run=client -o yaml | kubectl apply -f -
```

### Step 5 — Update GitHub Secrets with new IAM credentials
```bash
cd terraform
terraform output -raw gitops_user_access_key_id    # → AWS_ACCESS_KEY_ID
terraform output -raw gitops_user_secret_access_key # → AWS_SECRET_ACCESS_KEY
```
Update in: https://github.com/Shivanshusaxena2/retail-store-sample-app/settings/secrets/actions

### Step 6 — Trigger prod CI to rebuild images
```bash
git checkout gitops
git commit --allow-empty -m "ci: trigger prod pipeline after recreate"
git push origin gitops
```

### Step 7 — Fix image tags if pods show ImagePullBackOff
```bash
# Check what tags exist after CI runs
aws ecr list-images --repository-name retail-store-ui --region us-west-2
# Update src/ui/chart/values.yaml with new tag, commit and push to gitops
```

### Step 8 — Remove Karpenter taint if pods are Pending
```bash
kubectl taint node --all karpenter.sh/disrupted:NoSchedule-
```

### Step 9 — Deploy Dev
```bash
cd terraform-dev
terraform init
terraform apply
```

### Step 10 — Configure kubectl for dev
```bash
aws eks update-kubeconfig --region us-west-2 --name <dev-cluster-name> --alias dev
```

### Step 11 — Create ECR pull secret on dev
```powershell
$token = aws ecr get-authorization-token --region us-west-2 --query 'authorizationData[0].authorizationToken' --output text
$decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($token))
$password = $decoded.Split(':')[1]
kubectl create namespace retail-store-dev --context dev
kubectl create secret docker-registry regcred `
  --docker-server=033484686218.dkr.ecr.us-west-2.amazonaws.com `
  --docker-username=AWS --docker-password=$password `
  -n retail-store-dev --context dev
```

### Step 12 — Force ArgoCD sync on dev
```bash
for app in retail-store-dev-ui retail-store-dev-cart retail-store-dev-catalog retail-store-dev-checkout retail-store-dev-orders; do
  kubectl annotate application $app -n argocd argocd.argoproj.io/refresh=hard --overwrite --context dev
done
```

### Step 13 — Remove Karpenter taint on dev if pods Pending
```bash
kubectl taint node --all karpenter.sh/disrupted:NoSchedule- --context dev
```

### Step 14 — Trigger dev CI to rebuild images
```bash
git checkout dev
git commit --allow-empty -m "ci: trigger dev pipeline after recreate"
git push origin dev
```

### Step 15 — Access ArgoCD (password: admin@123)
```bash
# Prod (http://localhost:8080)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Dev (http://localhost:8081)
kubectl port-forward svc/argocd-server -n argocd 8081:443 --context dev
```

---

## IMPORTANT NOTES

1. **Cluster names change** every recreate (random suffix). Always run `aws eks list-clusters` first.
2. **ECR repos are deleted** with `terraform destroy` (force_delete=true). CI will recreate and push fresh images.
3. **GitHub Secrets must be updated** after every recreate — new IAM user = new credentials.
4. **ArgoCD password is `admin@123`** — baked into Terraform, set automatically.
5. **Karpenter taint** (`karpenter.sh/disrupted:NoSchedule`) blocks pod scheduling — remove it whenever pods are stuck in Pending.
6. **Dev service endpoints** in `values-dev.yaml` use `retail-store-dev-*` prefix — already correct, no changes needed.
7. **Port-forward uses HTTP** not HTTPS — open `http://localhost:8080` not `https://`.
