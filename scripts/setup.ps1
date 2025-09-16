# DevOps Playground Setup Script (PowerShell)
# This script helps automate the initial setup process

param(
    [Parameter(Mandatory=$false)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubOrg
)

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check if command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    $missingTools = @()
    
    if (-not (Test-Command "aws")) {
        $missingTools += "aws-cli"
    }
    
    if (-not (Test-Command "terraform")) {
        $missingTools += "terraform"
    }
    
    if (-not (Test-Command "kubectl")) {
        $missingTools += "kubectl"
    }
    
    if (-not (Test-Command "docker")) {
        $missingTools += "docker"
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Error "Missing required tools: $($missingTools -join ', ')"
        Write-Status "Please install the missing tools and run this script again."
        exit 1
    }
    
    Write-Success "All prerequisites are installed"
}

# Function to get AWS account ID
function Get-AwsAccountInfo {
    Write-Status "Getting AWS account information..."
    
    try {
        $awsIdentity = aws sts get-caller-identity --output json | ConvertFrom-Json
        $script:AWS_ACCOUNT_ID = $awsIdentity.Account
        $script:AWS_REGION = (aws configure get region)
        
        if (-not $script:AWS_ACCOUNT_ID) {
            throw "Could not retrieve AWS account ID"
        }
        
        Write-Success "AWS Account ID: $script:AWS_ACCOUNT_ID"
        Write-Success "AWS Region: $script:AWS_REGION"
    }
    catch {
        Write-Error "AWS CLI not configured or credentials invalid"
        Write-Status "Please run 'aws configure' to set up your credentials"
        exit 1
    }
}

# Function to create S3 bucket
function New-S3Bucket {
    param([string]$BucketName)
    
    Write-Status "Creating S3 bucket: $BucketName"
    
    try {
        aws s3 ls "s3://$BucketName" 2>$null
        Write-Warning "S3 bucket $BucketName already exists"
    }
    catch {
        if ($script:AWS_REGION -eq "us-east-1") {
            aws s3 mb "s3://$BucketName"
        } else {
            aws s3 mb "s3://$BucketName" --region $script:AWS_REGION
        }
        Write-Success "S3 bucket created: $BucketName"
    }
}

# Function to create DynamoDB table
function New-DynamoDBTable {
    param([string]$TableName)
    
    Write-Status "Creating DynamoDB table: $TableName"
    
    try {
        aws dynamodb describe-table --table-name $TableName --region $script:AWS_REGION 2>$null
        Write-Warning "DynamoDB table $TableName already exists"
    }
    catch {
        aws dynamodb create-table `
            --table-name $TableName `
            --attribute-definitions AttributeName=LockID,AttributeType=S `
            --key-schema AttributeName=LockID,KeyType=HASH `
            --billing-mode PAY_PER_REQUEST `
            --region $script:AWS_REGION
        
        Write-Status "Waiting for DynamoDB table to be active..."
        aws dynamodb wait table-exists --table-name $TableName --region $script:AWS_REGION
        Write-Success "DynamoDB table created: $TableName"
    }
}

# Function to update configuration files
function Update-ConfigFiles {
    param(
        [string]$BucketName,
        [string]$GitHubOrg
    )
    
    Write-Status "Updating configuration files..."
    
    # Update backend config
    (Get-Content "terraform/backend-config.hcl") -replace "your-terraform-state-bucket-name", $BucketName | Set-Content "terraform/backend-config.hcl"
    
    # Update ArgoCD app manifests
    Get-ChildItem "argo-apps/*.yaml" | ForEach-Object {
        (Get-Content $_.FullName) -replace "your-org", $GitHubOrg | Set-Content $_.FullName
    }
    
    # Update Helm chart values
    Get-ChildItem "charts/*/values.yaml" | ForEach-Object {
        (Get-Content $_.FullName) -replace "123456789012", $script:AWS_ACCOUNT_ID | Set-Content $_.FullName
    }
    
    # Update GitHub Actions workflow
    (Get-Content ".github/workflows/ci-build-deploy.yml") -replace "123456789012", $script:AWS_ACCOUNT_ID | Set-Content ".github/workflows/ci-build-deploy.yml"
    
    Write-Success "Configuration files updated"
}

# Function to create ECR repositories
function New-ECRRepositories {
    Write-Status "Creating ECR repositories..."
    
    $repositories = @("devops-playground-demo-app", "devops-playground-frontend")
    
    foreach ($repo in $repositories) {
        try {
            aws ecr describe-repositories --repository-names $repo --region $script:AWS_REGION 2>$null
            Write-Warning "ECR repository $repo already exists"
        }
        catch {
            aws ecr create-repository --repository-name $repo --region $script:AWS_REGION
            Write-Success "ECR repository created: $repo"
        }
    }
}

# Function to generate setup summary
function New-SetupSummary {
    param(
        [string]$BucketName,
        [string]$GitHubOrg
    )
    
    Write-Status "Generating setup summary..."
    
    $summary = @"
# Setup Summary

## AWS Configuration
- **Account ID**: $script:AWS_ACCOUNT_ID
- **Region**: $script:AWS_REGION
- **S3 Bucket**: $BucketName
- **DynamoDB Table**: devops-playground-terraform-state-lock

## GitHub Configuration
- **Organization**: $GitHubOrg
- **Repository**: $(Split-Path -Leaf (Get-Location))

## Next Steps

1. **Configure GitHub Secrets**:
   - Go to your GitHub repository → Settings → Secrets and variables → Actions
   - Add the following secrets:
     - ``AWS_ACCESS_KEY_ID``: Your AWS access key
     - ``AWS_SECRET_ACCESS_KEY``: Your AWS secret key
     - ``AWS_ACCOUNT_ID``: $script:AWS_ACCOUNT_ID

2. **Deploy Infrastructure**:
   ```bash
   make tf-init-dev
   make tf-plan-dev
   make tf-apply-dev
   ```

3. **Configure kubectl**:
   ```bash
   make kube-config
   ```

4. **Deploy Applications**:
   ```bash
   make kube-deploy-observability
   make argocd-install
   make argocd-apps
   ```

## Access URLs (after deployment)
- **Frontend**: http://frontend.devops-playground.local
- **API**: http://api.devops-playground.local/health
- **Grafana**: ``kubectl port-forward svc/grafana 3000:3000 -n monitoring``
- **Prometheus**: ``kubectl port-forward svc/prometheus 9090:9090 -n monitoring``
- **ArgoCD**: ``kubectl port-forward svc/argocd-server 8080:443 -n argocd``

## Important Notes
- Replace ``devops-playground.local`` with your actual domain
- Update DNS records to point to your load balancer
- Set up SSL certificates with cert-manager
- Configure monitoring alerts in Alertmanager
"@

    $summary | Out-File -FilePath "SETUP_SUMMARY.md" -Encoding UTF8
    Write-Success "Setup summary generated: SETUP_SUMMARY.md"
}

# Main function
function Main {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "DevOps Playground Setup Script" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host
    
    # Check if running from project root
    if (-not (Test-Path "README.md") -or -not (Test-Path "terraform")) {
        Write-Error "Please run this script from the project root directory"
        exit 1
    }
    
    # Check prerequisites
    Test-Prerequisites
    
    # Get AWS configuration
    Get-AwsAccountInfo
    
    # Get user input if not provided as parameters
    if (-not $BucketName) {
        $BucketName = Read-Host "Enter a unique S3 bucket name for Terraform state"
    }
    
    if (-not $GitHubOrg) {
        $GitHubOrg = Read-Host "Enter your GitHub username/organization"
    }
    
    if (-not $BucketName -or -not $GitHubOrg) {
        Write-Error "Both S3 bucket name and GitHub organization are required"
        exit 1
    }
    
    # Create AWS resources
    New-S3Bucket $BucketName
    New-DynamoDBTable "devops-playground-terraform-state-lock"
    New-ECRRepositories
    
    # Update configuration files
    Update-ConfigFiles $BucketName $GitHubOrg
    
    # Generate summary
    New-SetupSummary $BucketName $GitHubOrg
    
    Write-Host
    Write-Success "Setup completed successfully!"
    Write-Host
    Write-Status "Next steps:"
    Write-Host "1. Review and update SETUP_SUMMARY.md"
    Write-Host "2. Configure GitHub secrets"
    Write-Host "3. Run 'make deploy-dev' to deploy the infrastructure"
    Write-Host
    Write-Warning "Remember to replace 'devops-playground.local' with your actual domain"
}

# Run main function
Main
