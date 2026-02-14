.PHONY: help init plan apply destroy fmt validate output clean

TF ?= terraform

help:
	@echo "Targets:"
	@echo "  make init       - terraform init (use BACKEND_CONFIG=... optionally)"
	@echo "  make plan       - terraform plan"
	@echo "  make apply      - terraform apply"
	@echo "  make destroy    - terraform destroy"
	@echo "  make fmt        - terraform fmt -recursive"
	@echo "  make validate   - terraform validate"
	@echo "  make output     - terraform output"
	@echo "  make clean      - remove .terraform and lock (non-destructive)"
	@echo ""
	@echo "Vars:"
	@echo "  TF=tofu|terraform"
	@echo "  BACKEND_CONFIG=backend.gcs.tfbackend (passed to init)"

init:
	@if [ -n "$(BACKEND_CONFIG)" ]; then \
		$(TF) init -upgrade -backend-config=$(BACKEND_CONFIG); \
	else \
		$(TF) init -upgrade; \
	fi

plan:
	$(TF) plan

apply:
	$(TF) apply

destroy:
	$(TF) destroy

fmt:
	$(TF) fmt -recursive

validate:
	$(TF) validate

output:
	$(TF) output

clean:
	rm -rf .terraform .terraform.lock.hcl
