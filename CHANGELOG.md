# Changelog

## v0.1.1 — 2025-12-27

- Patch: add `release` target; Makefile alignment

## v0.1.0 — 2025-12-27

- Split-stage Terraform setup: Stage 1 enrollments; Stage 2 DNS + CPS DV validation
- Makefile targets added: `all`, `check-validation`, `clean-dns`
- Conditional DNS propagation wait; configurable validation timeout
- Outputs centralized in [dns/outputs.tf](dns/outputs.tf)
