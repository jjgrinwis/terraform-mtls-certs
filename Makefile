# Makefile for terraform-mtls-certs (split stages)
#
# Stage 1 (root): enrollments
# Stage 2 (dns): DNS TXT records + validation

# Declare targets as commands, not files. Without this, make would skip targets
# if files with the same name exist in the directory (e.g., a file named "init").
.PHONY: init plan apply apply-prompt validate all clean-dns destroy check-validation output release release-with-changelog

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

# Run both stages sequentially (Stage 1 then Stage 2)
all: apply validate

# Clean up DNS TXT records that are no longer needed
# 1. Refreshes Stage 1 state to fetch latest dns_challenges from CPS API
# 2. Applies only DNS records in Stage 2 using -target to avoid recreating validation resources
# 3. Terraform automatically removes TXT records for cleared challenges and keeps active ones
# Note: All terraform output suppressed to hide expected -target warnings (intentional partial apply)
clean-dns:
	@echo "Refreshing Stage 1 state to check latest dns_challenges..." && \
	terraform refresh >/dev/null 2>&1 && \
	echo "Syncing DNS records with current challenges..." && \
	cd dns && terraform apply -target='akamai_dns_record.acme_txt' -auto-approve >/dev/null 2>&1 && \
	echo "✓ DNS records synced successfully"

# Destroy everything (DNS first, then enrollments)
# CPS has some extra validations so you will need to acknowledge in the CPS UI that the certificates are being revoked.
# you can also use terraform state rm module.enroll_{ENV}.akamai_cps_dv_enrollment.this to remove the enrollment from state without destroying it.
destroy:
	cd dns && terraform destroy -auto-approve || true
	terraform destroy -auto-approve

# Check validation status from Stage 2 (read-only, no changes made)
# Forces recreation of validation resources with -replace to fetch latest status from Akamai CPS
# Note: -refresh-only doesn't work here because the validation resource doesn't update its status
# when enrollment_id and sans remain unchanged. The -replace flag forces Terraform to recreate
# the resources, which queries CPS API for current validation state (coordinate-domain-validation → 
# wait-deploy-to-prod → complete). This is safe as the validation resource is read-only.
# can timeout if certificate is being pushed to production; in that case, re-run the make target after some time.
check-validation:
	@echo "=== Update Validation Status ==="
	@echo "will replace akamai_cps_dv_validations to fetch latest status from CPS..."
	@echo "will timeout if already being pushed to productions. If so, re-run this command after some time."
	@cd dns && terraform apply -replace=akamai_cps_dv_validation.prod -replace=akamai_cps_dv_validation.acc -replace=akamai_cps_dv_validation.test -auto-approve >/dev/null 2>&1 && terraform output validation_status

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

# Tag and publish a release
# Usage: make release VERSION=v0.1.1 NOTES="Brief summary of changes"
release:
	@test -n "$(VERSION)" || (echo "VERSION is required (e.g., v0.1.1)"; exit 1)
	@git tag -a "$(VERSION)" -m "$(NOTES)"
	@git push origin "$(VERSION)"
	@command -v gh >/dev/null 2>&1 && gh release create "$(VERSION)" --title "$(VERSION)" --notes "$(NOTES)" || echo "gh CLI not found; skipped GitHub release creation."

# Tag, publish a release, and update CHANGELOG.md automatically
# Usage: make release-with-changelog VERSION=v0.1.2 NOTES="Brief summary of changes"
release-with-changelog:
	@test -n "$(VERSION)" || (echo "VERSION is required (e.g., v0.1.2)"; exit 1)
	@test -n "$(NOTES)" || (echo "NOTES is required (brief summary)"; exit 1)
	@touch CHANGELOG.md
	@printf "## $(VERSION) — $$(date +%Y-%m-%d)\n- $(NOTES)\n\n" | cat - CHANGELOG.md > CHANGELOG.md.new && mv CHANGELOG.md.new CHANGELOG.md
	@git add CHANGELOG.md
	@git commit -m "docs: update CHANGELOG for $(VERSION)" || echo "No changes to commit"
	@git tag -a "$(VERSION)" -m "$(NOTES)"
	@git push origin "$(VERSION)"
	@command -v gh >/dev/null 2>&1 && gh release create "$(VERSION)" --title "$(VERSION)" --notes "$(NOTES)" || echo "gh CLI not found; skipped GitHub release creation."
