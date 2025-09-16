#!/bin/bash

# DevOps Playground Setup Script
# This script helps automate the initial setup process

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
    
    if ! command_exists aws; then
        missing_tools+=("aws-cli")
    fi
    
    if ! command_exists terraform; then
        missing_tools+=("terraform")
    fi
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")
    fi
    
    if ! command_exists docker; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "Please install the missing tools and run this script again."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Function to get AWS account ID
get_aws_account_id() {
    print_status "Getting AWS account ID..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS CLI not configured or credentials invalid"
        print_status "Please run 'aws configure' to set up your credentials"
        exit 1
    fi
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region)
    
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        print_error "Could not retrieve AWS account ID"
        exit 1
    fi
    
    print_success "AWS Account ID: $AWS_ACCOUNT_ID"
    print_success "AWS Region: $AWS_REGION"
}

# Function to create S3 bucket
create_s3_bucket() {
    local bucket_name="$1"
    
    print_status "Creating S3 bucket: $bucket_name"
    
    if aws s3 ls "s3://$bucket_name" 2>/dev/null; then
        print_warning "S3 bucket $bucket_name already exists"
    else
        if [ "$AWS_REGION" = "us-east-1" ]; then
            aws s3 mb "s3://$bucket_name"
        else
            aws s3 mb "s3://$bucket_name" --region "$AWS_REGION"
        fi
        print_success "S3 bucket created: $bucket_name"
    fi
}

# Function to create DynamoDB table
create_dynamodb_table() {
    local table_name="$1"
    
    print_status "Creating DynamoDB table: $table_name"
    
    if aws dynamodb describe-table --table-name "$table_name" >/dev/null 2>&1; then
        print_warning "DynamoDB table $table_name already exists"
    else
        aws dynamodb create-table \
            --table-name "$table_name" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --region "$AWS_REGION"
        
        print_status "Waiting for DynamoDB table to be active..."
        aws dynamodb wait table-exists --table-name "$table_name" --region "$AWS_REGION"
        print_success "DynamoDB table created: $table_name"
    fi
}

# Function to update configuration files
update_config_files() {
    local bucket_name="$1"
    local github_org="$2"
    
    print_status "Updating configuration files..."
    
    # Update backend config
    sed -i.bak "s/your-terraform-state-bucket-name/$bucket_name/g" terraform/backend-config.hcl
    
    # Update ArgoCD app manifests
    find argo-apps/ -name "*.yaml" -exec sed -i.bak "s/your-org/$github_org/g" {} \;
    find argo-apps/ -name "*.yaml" -exec sed -i.bak "s/Yancers/$github_org/g" {} \;
    
    # Update Helm chart values
    find charts/ -name "values.yaml" -exec sed -i.bak "s/123456789012/$AWS_ACCOUNT_ID/g" {} \;
    
    # Update GitHub Actions workflow
    sed -i.bak "s/123456789012/$AWS_ACCOUNT_ID/g" .github/workflows/ci-build-deploy.yml
    
    print_success "Configuration files updated"
}

# Function to create ECR repositories
create_ecr_repositories() {
    print_status "Creating ECR repositories..."
    
    local repositories=("devops-playground-demo-app" "devops-playground-frontend")
    
    for repo in "${repositories[@]}"; do
        if aws ecr describe-repositories --repository-names "$repo" >/dev/null 2>&1; then
            print_warning "ECR repository $repo already exists"
        else
            aws ecr create-repository --repository-name "$repo" --region "$AWS_REGION"
            print_success "ECR repository created: $repo"
        fi
    done
}

# Function to generate setup summary
generate_summary() {
    local bucket_name="$1"
    local github_org="$2"
    
    print_status "Generating setup summary..."
    
    cat > SETUP_SUMMARY.md << EOF
# Setup Summary

## AWS Configuration
- **Account ID**: $AWS_ACCOUNT_ID
- **Region**: $AWS_REGION
- **S3 Bucket**: $bucket_name
- **DynamoDB Table**: devops-playground-terraform-state-lock

## GitHub Configuration
- **Organization**: $github_org
- **Repository**: $(basename $(pwd))

## Next Steps

1. **Configure GitHub Secrets**:
   - Go to your GitHub repository → Settings → Secrets and variables → Actions
   - Add the following secrets:
     - \`AWS_ACCESS_KEY_ID\`: Your AWS access key
     - \`AWS_SECRET_ACCESS_KEY\`: Your AWS secret key
     - \`AWS_ACCOUNT_ID\`: $AWS_ACCOUNT_ID

2. **Deploy Infrastructure**:
   \`\`\`bash
   make tf-init-dev
   make tf-plan-dev
   make tf-apply-dev
   \`\`\`

3. **Configure kubectl**:
   \`\`\`bash
   make kube-config
   \`\`\`

4. **Deploy Applications**:
   \`\`\`bash
   make kube-deploy-observability
   make argocd-install
   make argocd-apps
   \`\`\`

## Access URLs (after deployment)
- **Frontend**: http://frontend.devops-playground.local
- **API**: http://api.devops-playground.local/health
- **Grafana**: \`kubectl port-forward svc/grafana 3000:3000 -n monitoring\`
- **Prometheus**: \`kubectl port-forward svc/prometheus 9090:9090 -n monitoring\`
- **ArgoCD**: \`kubectl port-forward svc/argocd-server 8080:443 -n argocd\`

## Important Notes
- Replace \`devops-playground.local\` with your actual domain
- Update DNS records to point to your load balancer
- Set up SSL certificates with cert-manager
- Configure monitoring alerts in Alertmanager
EOF

    print_success "Setup summary generated: SETUP_SUMMARY.md"
}

# Main function
main() {
    echo "=========================================="
    echo "DevOps Playground Setup Script"
    echo "=========================================="
    echo
    
    # Check if running from project root
    if [ ! -f "README.md" ] || [ ! -d "terraform" ]; then
        print_error "Please run this script from the project root directory"
        exit 1
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Get AWS configuration
    get_aws_account_id
    
    # Get user input
    echo
    read -p "Enter a unique S3 bucket name for Terraform state: " BUCKET_NAME
    read -p "Enter your GitHub username/organization: " GITHUB_ORG
    
    if [ -z "$BUCKET_NAME" ] || [ -z "$GITHUB_ORG" ]; then
        print_error "Both S3 bucket name and GitHub organization are required"
        exit 1
    fi
    
    # Create AWS resources
    create_s3_bucket "$BUCKET_NAME"
    create_dynamodb_table "devops-playground-terraform-state-lock"
    create_ecr_repositories
    
    # Update configuration files
    update_config_files "$BUCKET_NAME" "$GITHUB_ORG"
    
    # Generate summary
    generate_summary "$BUCKET_NAME" "$GITHUB_ORG"
    
    echo
    print_success "Setup completed successfully!"
    echo
    print_status "Next steps:"
    echo "1. Review and update SETUP_SUMMARY.md"
    echo "2. Configure GitHub secrets"
    echo "3. Run 'make deploy-dev' to deploy the infrastructure"
    echo
    print_warning "Remember to replace 'devops-playground.local' with your actual domain"
}

# Run main function
main "$@"
