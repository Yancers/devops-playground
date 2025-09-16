# DevOps Playground - Publish to GitHub Script (PowerShell)
# This script helps publish all code to your GitHub repository

param(
    [Parameter(Mandatory=$false)]
    [switch]$Force
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
    
    if (-not (Test-Command "git")) {
        Write-Error "Git is not installed or not in PATH"
        exit 1
    }
    
    Write-Success "All prerequisites are installed"
}

# Function to check git status
function Test-GitStatus {
    Write-Status "Checking git status..."
    
    if (-not (Test-Path ".git")) {
        Write-Error "Not a git repository. Please initialize git first."
        exit 1
    }
    
    # Check if there are uncommitted changes
    $gitStatus = git status --porcelain
    if ($gitStatus -and -not $Force) {
        Write-Warning "You have uncommitted changes:"
        Write-Host $gitStatus
        $response = Read-Host "Do you want to continue anyway? (y/N)"
        if ($response -notmatch "^[Yy]$") {
            exit 1
        }
    }
    
    Write-Success "Git status check passed"
}

# Function to validate files
function Test-Files {
    Write-Status "Validating files..."
    
    $errors = 0
    
    # Check for required files
    $requiredFiles = @(
        "README.md",
        "terraform/envs/dev/main.tf",
        "charts/api/Chart.yaml",
        "charts/frontend/Chart.yaml",
        "argo-apps/api-app.yaml",
        "app/app.py",
        "app/Dockerfile",
        "app/frontend/Dockerfile"
    )
    
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            Write-Error "Required file missing: $file"
            $errors++
        }
    }
    
    # Check for syntax errors in key files
    if (Test-Command "terraform") {
        Write-Status "Validating Terraform files..."
        Push-Location "terraform/envs/dev"
        try {
            $terraformOutput = terraform validate 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Terraform validation failed: $terraformOutput"
                $errors++
            }
        }
        finally {
            Pop-Location
        }
    }
    
    if ($errors -gt 0) {
        Write-Error "Validation failed with $errors errors"
        exit 1
    }
    
    Write-Success "File validation passed"
}

# Function to add and commit files
function Add-CommitFiles {
    Write-Status "Adding and committing files..."
    
    # Add all files
    git add .
    
    # Check if there are changes to commit
    $gitDiff = git diff --cached
    if (-not $gitDiff) {
        Write-Warning "No changes to commit"
        return
    }
    
    # Commit with a descriptive message
    $commitMessage = @"
feat: Complete DevOps playground setup

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
- Complete CI/CD pipeline
"@
    
    git commit -m $commitMessage
    Write-Success "Files committed successfully"
}

# Function to push to GitHub
function Push-ToGitHub {
    Write-Status "Pushing to GitHub..."
    
    # Check if remote exists
    try {
        $remoteUrl = git remote get-url origin 2>$null
        if (-not $remoteUrl) {
            throw "No remote origin found"
        }
        Write-Status "Remote origin: $remoteUrl"
    }
    catch {
        Write-Error "No remote origin found. Please add your GitHub repository as origin."
        Write-Status "Example: git remote add origin https://github.com/Yancers/devops-playground.git"
        exit 1
    }
    
    # Push to main branch
    try {
        git push origin main
        Write-Success "Successfully pushed to GitHub"
    }
    catch {
        Write-Error "Failed to push to GitHub"
        Write-Status "You may need to set up authentication or check your remote URL"
        exit 1
    }
}

# Function to create GitHub repository if needed
function Set-GitHubRepo {
    Write-Status "Setting up GitHub repository..."
    
    $repoUrl = "https://github.com/Yancers/devops-playground"
    
    # Check if remote exists
    try {
        $currentRemote = git remote get-url origin 2>$null
        if (-not $currentRemote) {
            Write-Status "Adding GitHub remote..."
            git remote add origin "$repoUrl.git"
            Write-Success "Remote added: $repoUrl"
        } else {
            Write-Status "Current remote: $currentRemote"
        }
    }
    catch {
        Write-Status "Adding GitHub remote..."
        git remote add origin "$repoUrl.git"
        Write-Success "Remote added: $repoUrl"
    }
}

# Function to generate final instructions
function New-Instructions {
    Write-Status "Generating final instructions..."
    
    $instructions = @"
# GitHub Repository Setup Complete! 🎉

Your DevOps playground has been successfully published to GitHub!

## Next Steps

### 1. Configure GitHub Secrets
Go to your repository → Settings → Secrets and variables → Actions

Add these secrets:
- ``AWS_ACCESS_KEY_ID``: Your AWS access key
- ``AWS_SECRET_ACCESS_KEY``: Your AWS secret key
- ``AWS_ACCOUNT_ID``: Your AWS account ID

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
- **Grafana**: ``kubectl port-forward svc/grafana 3000:3000 -n monitoring``
- **Prometheus**: ``kubectl port-forward svc/prometheus 9090:9090 -n monitoring``
- **ArgoCD**: ``kubectl port-forward svc/argocd-server 8080:443 -n argocd``

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
"@

    $instructions | Out-File -FilePath "GITHUB_SETUP_INSTRUCTIONS.md" -Encoding UTF8
    Write-Success "Instructions generated: GITHUB_SETUP_INSTRUCTIONS.md"
}

# Main function
function Main {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "DevOps Playground - Publish to GitHub" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host
    
    # Check if running from project root
    if (-not (Test-Path "README.md") -or -not (Test-Path "terraform")) {
        Write-Error "Please run this script from the project root directory"
        exit 1
    }
    
    # Check prerequisites
    Test-Prerequisites
    
    # Check git status
    Test-GitStatus
    
    # Validate files
    Test-Files
    
    # Setup GitHub repository
    Set-GitHubRepo
    
    # Commit files
    Add-CommitFiles
    
    # Push to GitHub
    Push-ToGitHub
    
    # Generate instructions
    New-Instructions
    
    Write-Host
    Write-Success "Repository published successfully!"
    Write-Host
    Write-Status "Your DevOps playground is now available at:"
    Write-Host "https://github.com/Yancers/devops-playground"
    Write-Host
    Write-Status "Next steps:"
    Write-Host "1. Configure GitHub secrets (see GITHUB_SETUP_INSTRUCTIONS.md)"
    Write-Host "2. Run the setup script to configure AWS resources"
    Write-Host "3. Deploy the infrastructure and applications"
    Write-Host
    Write-Warning "Remember to replace 'devops-playground.local' with your actual domain"
}

# Run main function
Main
