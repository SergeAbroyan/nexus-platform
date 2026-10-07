TERRAFORM ?= terraform
TERRAGRUNT ?= terragrunt
NEXUS_ENVIRONMENT ?= dev
NEXUS_REGION ?= us-east-1

LIVE_DIRECTORY := infrastructure/live/$(NEXUS_ENVIRONMENT)/$(NEXUS_REGION)

.PHONY: format check graph plan apply destroy

format:
	$(TERRAFORM) fmt -recursive infrastructure
	$(TERRAGRUNT) hcl fmt

check:
	$(TERRAFORM) fmt -check -recursive infrastructure
	$(TERRAGRUNT) hcl validate --working-dir $(LIVE_DIRECTORY)
	git diff --check

graph:
	$(TERRAGRUNT) graph-dependencies --working-dir $(LIVE_DIRECTORY)

plan:
	$(TERRAGRUNT) run-all plan --working-dir $(LIVE_DIRECTORY)

apply:
	$(TERRAGRUNT) run-all apply --working-dir $(LIVE_DIRECTORY)

destroy:
	$(TERRAGRUNT) run-all destroy --working-dir $(LIVE_DIRECTORY)
