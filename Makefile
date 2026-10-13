TERRAFORM ?= terraform
TERRAGRUNT ?= terragrunt
NEXUS_ENVIRONMENT ?= dev
NEXUS_REGION ?= us-east-1

LIVE_DIRECTORY := infrastructure/live/$(NEXUS_ENVIRONMENT)/$(NEXUS_REGION)
MODULE_DIRECTORIES := $(sort $(wildcard infrastructure/modules/*))

.PHONY: format check validate-modules graph plan apply destroy

format:
	$(TERRAFORM) fmt -recursive infrastructure
	$(TERRAGRUNT) hcl fmt

check:
	$(TERRAFORM) fmt -check -recursive infrastructure
	$(TERRAGRUNT) hcl validate --working-dir $(LIVE_DIRECTORY)
	git diff --check

validate-modules:
	@set -e; for module in $(MODULE_DIRECTORIES); do \
		echo "Validating $$module"; \
		$(TERRAFORM) -chdir=$$module init -backend=false -input=false > /dev/null; \
		$(TERRAFORM) -chdir=$$module validate; \
	done

graph:
	$(TERRAGRUNT) graph-dependencies --working-dir $(LIVE_DIRECTORY)

plan:
	$(TERRAGRUNT) run-all plan --working-dir $(LIVE_DIRECTORY)

apply:
	$(TERRAGRUNT) run-all apply --working-dir $(LIVE_DIRECTORY)

destroy:
	$(TERRAGRUNT) run-all destroy --working-dir $(LIVE_DIRECTORY)
