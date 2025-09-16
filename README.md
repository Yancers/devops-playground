# DevOps Developer Playground

A comprehensive DevOps playground environment built using industry best practices with AWS EKS, Kubernetes, Terraform, GitHub Actions, Docker, ArgoCD, Helm, Prometheus, Grafana, Trivy, and AWS services.

## 🏗️ Architecture Overview

This playground demonstrates a complete modern DevOps pipeline with:

- **Infrastructure as Code**: Terraform with modular design
- **Container Orchestration**: AWS EKS with Kubernetes
- **CI/CD Pipeline**: GitHub Actions with automated testing and deployment
- **GitOps**: ArgoCD for continuous deployment
- **Monitoring**: Prometheus, Grafana, and Alertmanager
- **Security**: Trivy vulnerability scanning and CIS compliance checks
- **Secrets Management**: AWS Parameter Store and Secrets Manager
- **Remote State**: S3 and DynamoDB for Terraform state management

## 📁 Repository Structure

```
devops-playground/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml      # Terraform plan with tflint/tfsec
│       ├── terraform-apply.yml     # Terraform apply with security checks
│       ├── ci-build-deploy.yml     # CI/CD pipeline for applications
│       └── trivy-scan.yml          # Security scanning and CIS compliance
├── terraform/
│   ├── modules/
│   │   ├── vpc/                    # VPC module with public/private subnets
│   │   ├── eks/                    # EKS cluster module
│   │   └── rds/                    # RDS PostgreSQL module
│   └── envs/
│       ├── dev/                    # Development environment
│       ├── staging/                # Staging environment
│       └── prod/                   # Production environment
├── charts/
│   ├── api/                        # Helm chart for API application
│   └── frontend/                   # Helm chart for frontend application
├── argo-apps/                      # ArgoCD application manifests
├── observability/
│   ├── prometheus/                 # Prometheus configuration
│   ├── grafana/                    # Grafana dashboards and configs
│   ├── alertmanager/               # Alertmanager configuration
│   └── fluentbit/                  # Log aggregation
└── app/                           # Demo Python Flask application
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.6.0
- kubectl
- Docker
- Git

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd devops-playground
```

### 2. Configure Terraform Backend

Create a `terraform/backend-config.hcl` file:

```hcl
bucket = "your-terraform-state-bucket"
key    = "devops-playground/terraform.tfstate"
region = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt = true
```

### 3. Configure Environment Variables

Create `terraform/terraform.tfvars`:

```hcl
owner = "your-name"
branch = "main"
cluster_name = "devops-playground"
region = "us-east-1"
ttl_hours = 24
node_instance_type = "t3.medium"
desired_capacity = 2
```

### 4. Deploy Infrastructure

```bash
cd terraform/envs/dev
terraform init -backend-config="../../backend-config.hcl"
terraform plan -var-file="../../terraform.tfvars"
terraform apply -var-file="../../terraform.tfvars"
```

### 5. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name dev-devops-playground
```

## 🔧 Components

### Infrastructure (Terraform)

- **VPC Module**: Creates VPC with public/private subnets, NAT gateways, and security groups
- **EKS Module**: Deploys EKS cluster with managed node groups and essential add-ons
- **RDS Module**: PostgreSQL database with encryption, backups, and monitoring

### CI/CD Pipeline (GitHub Actions)

- **terraform-plan.yml**: Validates and plans Terraform changes with tflint and tfsec
- **terraform-apply.yml**: Applies infrastructure changes with security checks
- **ci-build-deploy.yml**: Builds, tests, and deploys applications
- **trivy-scan.yml**: Security scanning and CIS compliance checks

### Application

- **Demo Python Flask App**: Containerized application with PostgreSQL and Redis
- **Health Checks**: Comprehensive health monitoring endpoints
- **Metrics**: Prometheus-compatible metrics endpoint

### Monitoring Stack

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and notification
- **Fluent Bit**: Log aggregation and forwarding

### Security

- **Trivy**: Container and filesystem vulnerability scanning
- **CIS Benchmarks**: Compliance checking
- **TFLint**: Terraform code quality and security
- **TFSec**: Terraform security scanning

## 🔐 Security Features

- **Container Scanning**: Automated vulnerability scanning with Trivy
- **Infrastructure Security**: TFSec and TFLint for Terraform security
- **Secrets Management**: AWS Parameter Store and Secrets Manager
- **Network Security**: Private subnets, security groups, and VPC endpoints
- **Encryption**: EBS volumes, RDS, and S3 encryption at rest
- **CIS Compliance**: Automated CIS benchmark checking

## 📊 Monitoring and Observability

- **Application Metrics**: Custom Prometheus metrics from the demo app
- **Infrastructure Metrics**: EKS, EC2, and RDS metrics
- **Log Aggregation**: Centralized logging with Fluent Bit
- **Alerting**: Configurable alerts for critical issues
- **Dashboards**: Pre-built Grafana dashboards for visualization

## 🚦 GitOps with ArgoCD

- **Automated Deployments**: Git-based deployment automation
- **Environment Promotion**: Seamless promotion between dev/staging/prod
- **Rollback Capability**: Easy rollback to previous versions
- **Sync Status**: Real-time deployment status monitoring

## 🛠️ Development Workflow

1. **Code Changes**: Make changes to application code
2. **Pull Request**: Create PR with automated testing
3. **Security Scan**: Trivy scans for vulnerabilities
4. **Infrastructure Plan**: Terraform plan with security checks
5. **Merge**: Merge to main branch
6. **Deploy**: Automated deployment via ArgoCD
7. **Monitor**: Real-time monitoring and alerting

## 📚 Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and security scans
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For questions and support, please open an issue in the GitHub repository.
