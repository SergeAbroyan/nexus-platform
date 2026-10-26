TERRAFORM ?= terraform
TERRAGRUNT ?= terragrunt
NEXUS_ENVIRONMENT ?= dev
NEXUS_REGION ?= us-east-1
NEXUS_AWS_ACCOUNT_ID ?= 123456789012
NEXUS_PROJECT_NAME ?= nexus
NEXUS_DNS_ZONE_NAME ?= platform.com
NEXUS_INGRESS_HOST ?= nexus.$(NEXUS_DNS_ZONE_NAME)
EKS_PUBLIC_ACCESS_CIDR ?=

export EKS_PUBLIC_ACCESS_CIDR
export NEXUS_DNS_ZONE_NAME
export NEXUS_INGRESS_HOST

LIVE_DIRECTORY := infrastructure/live/$(NEXUS_ENVIRONMENT)/$(NEXUS_REGION)
MODULE_DIRECTORIES := $(sort $(wildcard infrastructure/modules/*))
STATE_BUCKET := $(NEXUS_PROJECT_NAME)-terraform-state-$(NEXUS_AWS_ACCOUNT_ID)

.PHONY: format check validate-modules bootstrap-init aws-preflight domain-preflight preflight graph apply-dns dns-nameservers plan apply destroy

format:
	$(TERRAFORM) fmt -recursive infrastructure
	$(TERRAGRUNT) hcl fmt

check:
	$(TERRAFORM) fmt -check -recursive infrastructure
	$(TERRAGRUNT) hcl fmt --check
	$(TERRAGRUNT) hcl validate --working-dir $(LIVE_DIRECTORY)
	git diff --check

validate-modules:
	@set -e; data_root=$$(mktemp -d); trap 'rm -rf "$$data_root"' EXIT; for module in $(MODULE_DIRECTORIES); do \
		echo "Validating $$module"; \
		TF_DATA_DIR="$$data_root/$$(basename $$module)" $(TERRAFORM) -chdir=$$module init -backend=false -input=false > /dev/null; \
		TF_DATA_DIR="$$data_root/$$(basename $$module)" $(TERRAFORM) -chdir=$$module validate; \
	done

bootstrap-init:
	$(TERRAFORM) -chdir=infrastructure/bootstrap init -migrate-state \
		-backend-config="bucket=$(STATE_BUCKET)" \
		-backend-config="key=bootstrap/terraform.tfstate" \
		-backend-config="region=$(NEXUS_REGION)" \
		-backend-config="encrypt=true" \
		-backend-config="use_lockfile=true"

aws-preflight:
	@command -v aws > /dev/null || (echo "AWS CLI is required." >&2; exit 1)
	@test "$$(aws sts get-caller-identity --query Account --output text)" = "$(NEXUS_AWS_ACCOUNT_ID)" || (echo "The active AWS account is not $(NEXUS_AWS_ACCOUNT_ID)." >&2; exit 1)

domain-preflight:
	@test -n "$(NEXUS_DNS_ZONE_NAME)" || (echo "Set NEXUS_DNS_ZONE_NAME to a domain that you own." >&2; exit 1)
	@test -n "$(NEXUS_INGRESS_HOST)" || (echo "Set NEXUS_INGRESS_HOST to the Nexus application hostname." >&2; exit 1)
	@case "$(NEXUS_INGRESS_HOST)" in *."$(NEXUS_DNS_ZONE_NAME)") ;; *) echo "NEXUS_INGRESS_HOST must be a subdomain of NEXUS_DNS_ZONE_NAME." >&2; exit 1;; esac

preflight: aws-preflight domain-preflight
	@test -n "$(EKS_PUBLIC_ACCESS_CIDR)" || (echo "Set EKS_PUBLIC_ACCESS_CIDR to your public IP in CIDR form, for example 203.0.113.10/32." >&2; exit 1)
	@case "$(EKS_PUBLIC_ACCESS_CIDR)" in */*) ;; *) echo "EKS_PUBLIC_ACCESS_CIDR must use CIDR notation." >&2; exit 1;; esac

graph:
	$(TERRAGRUNT) dag graph --working-dir $(LIVE_DIRECTORY)

apply-dns: aws-preflight domain-preflight
	$(TERRAGRUNT) apply --working-dir $(LIVE_DIRECTORY)/dns

dns-nameservers: aws-preflight domain-preflight
	$(TERRAGRUNT) output name_servers --working-dir $(LIVE_DIRECTORY)/dns

plan: preflight
	$(TERRAGRUNT) run --all plan --working-dir $(LIVE_DIRECTORY)

apply: preflight
	$(TERRAGRUNT) run --all apply --working-dir $(LIVE_DIRECTORY)

destroy: preflight
	$(TERRAGRUNT) run --all destroy --working-dir $(LIVE_DIRECTORY)
