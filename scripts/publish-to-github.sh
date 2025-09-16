#!/bin/bash

# DevOps Playground - Publish to GitHub Script
# This script helps publish all code to your GitHub repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists git; then
        missing_tools+=("git")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "Please install the missing tools and run this script again."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Function to check git status
check_git_status() {
    print_status "Checking git status..."
    
    if [ ! -d ".git" ]; then
        print_error "Not a git repository. Please initialize git first."
        exit 1
    fi
    
    # Check if there are uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        print_warning "You have uncommitted changes. Please commit or stash them first."
        git status --short
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    print_success "Git status check passed"
}

# Function to validate files
validate_files() {
    print_status "Validating files..."
    
    local errors=0
    
    # Check for required files
    local required_files=(
        "README.md"
        "terraform/envs/dev/main.tf"
        "charts/api/Chart.yaml"
        "charts/frontend/Chart.yaml"
        "argo-apps/api-app.yaml"
        "app/app.py"
        "app/Dockerfile"
        "app/frontend/Dockerfile"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Required file missing: $file"
            ((errors++))
        fi
    done
    
    # Check for syntax errors in key files
    if command_exists terraform; then
        print_status "Validating Terraform files..."
        cd terraform/envs/dev
        if ! terraform validate >/dev/null 2>&1; then
            print_error "Terraform validation failed"
            ((errors++))
        fi
        cd - >/dev/null
    fi
    
    if [ $errors -gt 0 ]; then
        print_error "Validation failed with $errors errors"
        exit 1
    fi
    
    print_success "File validation passed"
}

# Function to add and commit files
commit_files() {
    print_status "Adding and committing files..."
    
    # Add all files
    git add .
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        print_warning "No changes to commit"
        return 0
    fi
    
    # Commit with a descriptive message
    git commit -m "feat: Complete DevOps playground setup

- Add comprehensive Terraform modules (VPC, EKS, RDS)
- Add Helm charts for API and frontend applications
- Add ArgoCD application manifests for GitOps
- Add observability stack (Prometheus, Grafana, Alertmanager)
- Add CI/CD workflows with GitHub Actions
- Add security scanning with Trivy
- Add setup scripts and documentation
- Add multi-environment support (dev, staging, prod)

This commit includes:
- Infrastructure as Code with Terraform
- Container orchestration with EKS
- GitOps deployment with ArgoCD
- Monitoring and observability
- Security scanning and compliance
- Complete CI/CD pipeline"
    
    print_success "Files committed successfully"
}

# Function to push to GitHub
push_to_github() {
    print_status "Pushing to GitHub..."
    
    # Check if remote exists
    if ! git remote get-url origin >/dev/null 2>&1; then
        print_error "No remote origin found. Please add your GitHub repository as origin."
        print_status "Example: git remote add origin https://github.com/Yancers/devops-playground.git"
        exit 1
    fi
    
    # Push to main branch
    if git push origin main; then
        print_success "Successfully pushed to GitHub"
    else
        print_error "Failed to push to GitHub"
        print_status "You may need to set up authentication or check your remote URL"
        exit 1
    fi
}

# Function to create GitHub repository if needed
setup_github_repo() {
    print_status "Setting up GitHub repository..."
    
    local repo_url="https://github.com/Yancers/devops-playground"
    
    # Check if remote exists
    if ! git remote get-url origin >/dev/null 2>&1; then
        print_status "Adding GitHub remote..."
        git remote add origin "$repo_url.git"
        print_success "Remote added: $repo_url"
    else
        local current_remote=$(git remote get-url origin)
        print_status "Current remote: $current_remote"
    fi
}

# Function to generate final instructions
generate_instructions() {
    print_status "Generating final instructions..."
    
    cat > GITHUB_SETUP_INSTRUCTIONS.md << 'EOF'
# GitHub Repository Setup Complete! 🎉

Your DevOps playground has been successfully published to GitHub!

## Next Steps

### 1. Configure GitHub Secrets
Go to your repository → Settings → Secrets and variables → Actions

Add these secrets:
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `AWS_ACCOUNT_ID`: Your AWS account ID

### 2. Run the Setup Script
```bash
# For Linux/macOS
./scripts/setup.sh

# For Windows
.\scripts\setup.ps1
```

### 3. Deploy Infrastructure
```bash
make tf-init-dev
make tf-plan-dev
make tf-apply-dev
```

### 4. Deploy Applications
```bash
make kube-config
make kube-deploy-observability
make argocd-install
make argocd-apps
```

## Repository Structure

Your repository now contains:
- **terraform/**: Infrastructure as Code modules
- **charts/**: Helm charts for applications
- **argo-apps/**: ArgoCD application manifests
- **observability/**: Monitoring stack configurations
- **app/**: Demo applications (API and frontend)
- **.github/workflows/**: CI/CD pipelines
- **scripts/**: Setup and deployment scripts

## Access Your Applications

After deployment:
- **Frontend**: http://frontend.devops-playground.local
- **API**: http://api.devops-playground.local/health
- **Grafana**: `kubectl port-forward svc/grafana 3000:3000 -n monitoring`
- **Prometheus**: `kubectl port-forward svc/prometheus 9090:9090 -n monitoring`
- **ArgoCD**: `kubectl port-forward svc/argocd-server 8080:443 -n argocd`

## Documentation

- **README.md**: Project overview and architecture
- **SETUP.md**: Detailed setup instructions
- **QUICKSTART.md**: Quick start guide
- **Makefile**: Common commands and automation

## Support

If you encounter issues:
1. Check the troubleshooting sections in the documentation
2. Review GitHub Actions logs
3. Check AWS CloudTrail for API errors
4. Verify IAM permissions

Happy DevOps! 🚀
EOF

    print_success "Instructions generated: GITHUB_SETUP_INSTRUCTIONS.md"
}

# Main function
main() {
    echo "=========================================="
    echo "DevOps Playground - Publish to GitHub"
    echo "=========================================="
    echo
    
    # Check if running from project root
    if [ ! -f "README.md" ] || [ ! -d "terraform" ]; then
        print_error "Please run this script from the project root directory"
        exit 1
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Check git status
    check_git_status
    
    # Validate files
    validate_files
    
    # Setup GitHub repository
    setup_github_repo
    
    # Commit files
    commit_files
    
    # Push to GitHub
    push_to_github
    
    # Generate instructions
    generate_instructions
    
    echo
    print_success "Repository published successfully!"
    echo
    print_status "Your DevOps playground is now available at:"
    echo "https://github.com/Yancers/devops-playground"
    echo
    print_status "Next steps:"
    echo "1. Configure GitHub secrets (see GITHUB_SETUP_INSTRUCTIONS.md)"
    echo "2. Run the setup script to configure AWS resources"
    echo "3. Deploy the infrastructure and applications"
    echo
    print_warning "Remember to replace 'devops-playground.local' with your actual domain"
}

# Run main function
main "$@"
