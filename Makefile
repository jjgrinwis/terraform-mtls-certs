# Makefile for terraform-mtls-certs (split stages)
#
# Stage 1 (root): enrollments
# Stage 2 (dns): DNS TXT records + validation

.PHONY: init plan apply apply-prompt validate destroy status output

# Initialize both stages
init:
	terraform init
	cd dns && terraform init

# Plan changes
plan:
	terraform plan

# Apply Stage 1 (enrollments)
apply:
	terraform apply -auto-approve

# Apply with confirmation prompts
apply-prompt:
	terraform apply

# Apply Stage 2 (DNS + validation)
validate:
	cd dns && terraform apply -auto-approve

# Destroy everything (DNS first, then enrollments)
destroy:
	cd dns && terraform destroy -auto-approve || true
	terraform destroy -auto-approve

# Show validation status from Stage 2
status:
	@cd dns && terraform refresh 2>/dev/null && terraform output validation_status

# Show all outputs
output:
	@echo "=== Enrollments ==="
	@terraform output certificate_enrollment_ids
	@echo ""
	@echo "=== DNS Challenges ==="
	@terraform output dns_challenges_prod
	@terraform output dns_challenges_acc
	@terraform output dns_challenges_test
	@echo ""
	@echo "=== Validation Status ==="
	@cd dns && terraform output validation_status 2>/dev/null || echo "Run 'make validate' first"
