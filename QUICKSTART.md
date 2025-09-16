# Quick Start Guide

This guide will get you up and running with the DevOps playground in the fastest way possible.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.6.0
- kubectl
- Docker
- Git

## Option 1: Automated Setup (Recommended)

### For Linux/macOS:
```bash
./scripts/setup.sh
```

### For Windows:
```powershell
.\scripts\setup.ps1
```

The script will:
- Check prerequisites
- Get your AWS account information
- Create S3 bucket and DynamoDB table
- Create ECR repositories
- Update configuration files
- Generate a setup summary

## Option 2: Manual Setup

### 1. Get AWS Account ID
```bash
aws sts get-caller-identity --query Account --output text
```

### 2. Create S3 Bucket
```bash
# Replace with your unique bucket name
aws s3 mb s3://your-unique-terraform-state-bucket
```

### 3. Create DynamoDB Table
```bash
aws dynamodb create-table \
    --table-name devops-playground-terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
```

### 4. Update Configuration Files

Edit `terraform/backend-config.hcl`:
```hcl
bucket = "your-unique-terraform-state-bucket"
key    = "devops-playground/terraform.tfstate"
region = "us-east-1"
dynamodb_table = "devops-playground-terraform-state-lock"
encrypt = true
```

Replace `your-org` with your GitHub username in:
- `argo-apps/api-app.yaml`
- `argo-apps/frontend-app.yaml`
- `argo-apps/observability-app.yaml`

Replace `123456789012` with your AWS account ID in:
- `charts/api/values.yaml`
- `charts/frontend/values.yaml`
- `.github/workflows/ci-build-deploy.yml`

### 5. Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `AWS_ACCOUNT_ID`: Your AWS account ID

## Deploy Infrastructure

```bash
# Deploy dev environment
make tf-init-dev
make tf-plan-dev
make tf-apply-dev

# Configure kubectl
make kube-config

# Deploy observability stack
make kube-deploy-observability

# Install ArgoCD
make argocd-install

# Deploy applications
make argocd-apps
```

## Access Your Applications

### Port Forwarding (for local access):
```bash
# Frontend
kubectl port-forward svc/frontend 8080:80

# API
kubectl port-forward svc/api 5000:80

# Grafana
kubectl port-forward svc/grafana 3000:3000 -n monitoring

# Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n monitoring

# ArgoCD
kubectl port-forward svc/argocd-server 8080:443 -n argocd
```

### Access URLs:
- **Frontend**: http://localhost:8080
- **API**: http://localhost:5000/health
- **Grafana**: http://localhost:3000 (admin/admin123)
- **Prometheus**: http://localhost:9090
- **ArgoCD**: https://localhost:8080 (admin/[password from kubectl])

## Get ArgoCD Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -A
```

### Check Services
```bash
kubectl get services -A
```

### Check ArgoCD Applications
```bash
kubectl get applications -n argocd
```

### View Logs
```bash
kubectl logs -f deployment/api
kubectl logs -f deployment/frontend
```

## Next Steps

1. **Set up DNS**: Replace `devops-playground.local` with your actual domain
2. **Configure SSL**: Install cert-manager for automatic SSL certificates
3. **Set up monitoring**: Configure alerts in Alertmanager
4. **Deploy to staging/prod**: Use the staging and production configurations

## Cost Optimization

- The dev environment uses small instances (t3.medium)
- RDS uses db.t3.micro (free tier eligible)
- Set TTL tags for automatic cleanup
- Monitor costs in AWS Cost Explorer

## Security Notes

- All containers run as non-root users
- Security groups restrict access
- RDS is encrypted at rest
- EKS uses private subnets
- Regular security scanning with Trivy

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review the detailed SETUP.md guide
3. Check AWS CloudTrail for API errors
4. Verify IAM permissions
5. Check Kubernetes events: `kubectl get events --sort-by=.metadata.creationTimestamp`
