# Terraform AWS Web Infrastructure — Makefile
# Uses Docker images for portability. Override TF_IMAGE for different versions.

TF_IMAGE   := hashicorp/terraform:1.7
TD_IMAGE   := quay.io/terraform-docs/terraform-docs:latest
WORKDIR    := /workspace
DOCKER_TF  := docker run --rm -v "$(CURDIR):$(WORKDIR)" -w $(WORKDIR) $(TF_IMAGE)
DOCKER_TD  := docker run --rm -v "$(CURDIR):$(WORKDIR)" $(TD_IMAGE)

.PHONY: help fmt validate lint lint-fix docs \
        init-dev init-staging init-prod \
        plan-dev plan-staging plan-prod \
        clean

##@ General

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

fmt: ## Run terraform fmt on all files
	$(DOCKER_TF) fmt -recursive

validate: ## Validate all modules and environments
	@echo "=== Validating modules ==="
	@for mod in modules/*/; do \
		if [ -f "$${mod}main.tf" ]; then \
			echo "  $${mod}"; \
			$(DOCKER_TF) -chdir="$${mod}" init -backend=false > /dev/null 2>&1; \
			$(DOCKER_TF) -chdir="$${mod}" validate; \
		fi; \
	done
	@echo "=== Validating environments ==="
	@for env in environments/*/; do \
		if [ -f "$${env}main.tf" ]; then \
			echo "  $${env}"; \
			$(DOCKER_TF) -chdir="$${env}" init -backend=false > /dev/null 2>&1; \
			$(DOCKER_TF) -chdir="$${env}" validate; \
		fi; \
	done
	@echo "=== All validations passed ==="

lint: ## Run tflint on all modules
	@echo "tflint must be installed locally or run via CI."
	@which tflint > /dev/null 2>&1 && tflint --recursive || \
		echo "tflint not found — run in CI pipeline instead."

docs: ## Regenerate terraform-docs for all modules
	./scripts/gen-docs.sh

clean: ## Remove .terraform directories and lock files
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@echo "Cleaned."

##@ Environments

init-dev: ## terraform init for dev
	$(DOCKER_TF) -chdir=environments/dev init

init-staging: ## terraform init for staging
	$(DOCKER_TF) -chdir=environments/staging init

init-prod: ## terraform init for prod
	$(DOCKER_TF) -chdir=environments/prod init

plan-dev: ## terraform plan for dev
	$(DOCKER_TF) -chdir=environments/dev plan

plan-staging: ## terraform plan for staging
	$(DOCKER_TF) -chdir=environments/staging plan

plan-prod: ## terraform plan for prod
	$(DOCKER_TF) -chdir=environments/prod plan

apply-dev: ## terraform apply for dev (use with caution)
	$(DOCKER_TF) -chdir=environments/dev apply

apply-staging: ## terraform apply for staging (use with caution)
	$(DOCKER_TF) -chdir=environments/staging apply

apply-prod: ## terraform apply for prod (use with caution)
	$(DOCKER_TF) -chdir=environments/prod apply

destroy-dev: ## terraform destroy for dev (irreversible)
	$(DOCKER_TF) -chdir=environments/dev destroy

destroy-staging: ## terraform destroy for staging (irreversible)
	$(DOCKER_TF) -chdir=environments/staging destroy

destroy-prod: ## terraform destroy for prod (irreversible)
	$(DOCKER_TF) -chdir=environments/prod destroy
