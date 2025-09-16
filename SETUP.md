# DevOps Playground - Setup Guide

This guide will walk you through setting up the complete DevOps playground environment.

## Prerequisites

Before starting, ensure you have:

- AWS CLI installed and configured
- Terraform >= 1.6.0
- kubectl
- Docker
- Git
- A GitHub repository (fork or create your own)

## Step 1: AWS Setup

### 1.1 Create AWS IAM User

Create an IAM user with the following policies:
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`
- `AmazonS3FullAccess`
- `AmazonDynamoDBFullAccess`
- `AmazonRDSFullAccess`
- `AmazonVPCFullAccess`
- `IAMFullAccess`

### 1.2 Configure AWS CLI

```bash
aws configure
# Enter your Access Key ID
# Enter your Secret Access Key
# Enter region: us-east-1
# Enter output format: json
```

### 1.3 Get AWS Account ID

```bash
aws sts get-caller-identity --query Account --output text
```

## Step 2: GitHub Repository Setup

### 2.1 Fork or Create Repository

1. Fork this repository or create a new one
2. Clone your repository locally
3. Update the repository URLs in the configuration files

### 2.2 Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following secrets:

- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `AWS_ACCOUNT_ID`: Your AWS account ID (from step 1.3)

## Step 3: Update Configuration Files

### 3.1 Update Repository URLs

Replace `your-org` with your GitHub username/organization in:
- `argo-apps/api-app.yaml`
- `argo-apps/frontend-app.yaml`
- `argo-apps/observability-app.yaml`

### 3.2 Update ECR Repository Names

Update the ECR repository names in:
- `charts/api/values.yaml`
- `charts/frontend/values.yaml`
- `.github/workflows/ci-build-deploy.yml`

### 3.3 Update Domain Names

Replace `devops-playground.local` with your actual domain in:
- `charts/api/values.yaml`
- `charts/frontend/values.yaml`

## Step 4: Deploy Infrastructure

### 4.1 Create S3 Bucket for Terraform State

```bash
# Replace with your unique bucket name
aws s3 mb s3://your-unique-terraform-state-bucket
```

### 4.2 Update Backend Configuration

Edit `terraform/backend-config.hcl`:
```hcl
bucket = "your-unique-terraform-state-bucket"
key    = "devops-playground/terraform.tfstate"
region = "us-east-1"
dynamodb_table = "devops-playground-terraform-state-lock"
encrypt = true
```

### 4.3 Create DynamoDB Table

```bash
aws dynamodb create-table \
    --table-name devops-playground-terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
```

### 4.4 Deploy Dev Environment

```bash
# Initialize Terraform
make tf-init-dev

# Plan the deployment
make tf-plan-dev

# Apply the infrastructure
make tf-apply-dev
```

This will create:
- VPC with public/private subnets
- EKS cluster with managed node groups
- RDS PostgreSQL database
- ECR repositories
- S3 bucket and DynamoDB table for Terraform state

## Step 5: Configure kubectl

```bash
# Configure kubectl for your EKS cluster
make kube-config
```

## Step 6: Deploy Observability Stack

```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Deploy Prometheus, Grafana, and Alertmanager
make kube-deploy-observability
```

## Step 7: Install ArgoCD

```bash
# Install ArgoCD
make argocd-install

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Step 8: Deploy Applications

### 8.1 Build and Push Docker Images

```bash
# Build API image
make build-api

# Build frontend image
make build-frontend

# Tag and push to ECR (replace with your account ID)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

docker tag devops-playground-api:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/devops-playground-demo-app:latest
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/devops-playground-demo-app:latest

docker tag devops-playground-frontend:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/devops-playground-frontend:latest
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/devops-playground-frontend:latest
```

### 8.2 Deploy ArgoCD Applications

```bash
# Deploy ArgoCD applications
make argocd-apps
```

## Step 9: Configure DNS and Ingress

### 9.1 Install NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/aws/deploy.yaml
```

### 9.2 Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

### 9.3 Configure DNS

If using a real domain:
1. Create a hosted zone in Route 53
2. Update your domain's nameservers
3. Create A records pointing to your load balancer

For local testing, add to your `/etc/hosts`:
```
<LOAD_BALANCER_IP> api.devops-playground.local
<LOAD_BALANCER_IP> frontend.devops-playground.local
```

## Step 10: Verify Deployment

### 10.1 Check Pod Status

```bash
kubectl get pods -A
```

### 10.2 Check Services

```bash
kubectl get services -A
```

### 10.3 Check ArgoCD Applications

```bash
kubectl get applications -n argocd
```

### 10.4 Access Applications

- **Frontend**: http://frontend.devops-playground.local
- **API**: http://api.devops-playground.local/health
- **Grafana**: `kubectl port-forward svc/grafana 3000:3000 -n monitoring`
- **Prometheus**: `kubectl port-forward svc/prometheus 9090:9090 -n monitoring`
- **ArgoCD**: `kubectl port-forward svc/argocd-server 8080:443 -n argocd`

## Troubleshooting

### Common Issues

1. **Terraform Backend Issues**
   - Ensure S3 bucket exists and is accessible
   - Check DynamoDB table permissions

2. **EKS Cluster Issues**
   - Verify IAM permissions
   - Check VPC and subnet configuration

3. **ArgoCD Sync Issues**
   - Check repository access
   - Verify image tags and repository URLs

4. **Application Issues**
   - Check pod logs: `kubectl logs <pod-name>`
   - Verify environment variables and secrets

### Useful Commands

```bash
# Check cluster status
kubectl cluster-info

# View pod logs
kubectl logs -f deployment/api

# Check ingress
kubectl get ingress

# ArgoCD CLI
argocd app list
argocd app sync <app-name>
```

## Next Steps

1. **Set up monitoring alerts** in Alertmanager
2. **Configure backup strategies** for RDS
3. **Set up log aggregation** with Fluent Bit
4. **Implement security scanning** in CI/CD pipeline
5. **Add staging and production environments**

## Cost Optimization

- Use spot instances for non-critical workloads
- Set up TTL tags for automatic cleanup
- Monitor costs with AWS Cost Explorer
- Use smaller instance types for development

## Security Considerations

- Rotate IAM keys regularly
- Use least privilege access
- Enable VPC Flow Logs
- Set up AWS Config for compliance
- Regular security scanning with Trivy
