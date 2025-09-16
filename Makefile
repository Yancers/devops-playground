# DevOps Playground Makefile

.PHONY: help install test lint format build deploy clean

# Default target
help: ## Show this help message
	@echo "DevOps Playground - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Development
install: ## Install development dependencies
	pip install -r app/requirements.txt
	pip install -r app/requirements-dev.txt

test: ## Run tests
	cd app && python -m pytest test_app.py -v --cov=. --cov-report=html --cov-report=term

lint: ## Run linting
	cd app && flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
	cd app && flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics

format: ## Format code
	cd app && black .
	cd app && isort .

# Docker
build-api: ## Build API Docker image
	cd app && docker build -t devops-playground-api:latest .

build-frontend: ## Build frontend Docker image
	cd app/frontend && docker build -t devops-playground-frontend:latest .

build: build-api build-frontend ## Build all Docker images

# Terraform
tf-init-dev: ## Initialize Terraform for dev environment
	cd terraform/envs/dev && terraform init -backend-config="../../backend-config.hcl"

tf-plan-dev: ## Plan Terraform changes for dev environment
	cd terraform/envs/dev && terraform plan -var-file="../../terraform.tfvars"

tf-apply-dev: ## Apply Terraform changes for dev environment
	cd terraform/envs/dev && terraform apply -var-file="../../terraform.tfvars"

tf-destroy-dev: ## Destroy dev environment
	cd terraform/envs/dev && terraform destroy -var-file="../../terraform.tfvars"

tf-init-staging: ## Initialize Terraform for staging environment
	cd terraform/envs/staging && terraform init -backend-config="../../backend-config.hcl"

tf-plan-staging: ## Plan Terraform changes for staging environment
	cd terraform/envs/staging && terraform plan -var-file="../../terraform.tfvars"

tf-apply-staging: ## Apply Terraform changes for staging environment
	cd terraform/envs/staging && terraform apply -var-file="../../terraform.tfvars"

tf-init-prod: ## Initialize Terraform for prod environment
	cd terraform/envs/prod && terraform init -backend-config="../../backend-config.hcl"

tf-plan-prod: ## Plan Terraform changes for prod environment
	cd terraform/envs/prod && terraform plan -var-file="../../terraform.tfvars"

tf-apply-prod: ## Apply Terraform changes for prod environment
	cd terraform/envs/prod && terraform apply -var-file="../../terraform.tfvars"

# Kubernetes
kube-config: ## Configure kubectl for dev cluster
	aws eks update-kubeconfig --region us-east-1 --name dev-devops-playground

kube-deploy-api: ## Deploy API using Helm
	helm upgrade --install api charts/api --namespace default

kube-deploy-frontend: ## Deploy frontend using Helm
	helm upgrade --install frontend charts/frontend --namespace default

kube-deploy-observability: ## Deploy observability stack
	kubectl apply -f observability/prometheus/
	kubectl apply -f observability/grafana/
	kubectl apply -f observability/alertmanager/

# ArgoCD
argocd-install: ## Install ArgoCD
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

argocd-apps: ## Deploy ArgoCD applications
	kubectl apply -f argo-apps/

# Security
security-scan: ## Run security scans
	trivy image devops-playground-api:latest
	trivy fs .
	trivy config .

# Cleanup
clean: ## Clean up temporary files
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	find . -type d -name ".pytest_cache" -delete
	rm -rf app/htmlcov/
	rm -rf app/.coverage

# Full deployment pipeline
deploy-dev: tf-init-dev tf-plan-dev tf-apply-dev kube-config kube-deploy-observability argocd-apps ## Full deployment to dev environment

deploy-staging: tf-init-staging tf-plan-staging tf-apply-staging ## Full deployment to staging environment

deploy-prod: tf-init-prod tf-plan-prod tf-apply-prod ## Full deployment to prod environment
