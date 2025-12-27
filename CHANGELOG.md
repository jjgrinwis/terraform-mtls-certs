# Changelog

## v0.1.1 — 2025-12-27

- Patch: add `release` target; Makefile alignment

## v0.1.0 — 2025-12-27

- Architecture: Split-stage Terraform — Stage 1 enrollments; Stage 2 DNS + CPS DV validation via `terraform_remote_state` (local backend). Akamai provider alias `akamai.edgedns` scoped only to Stage 2.
- DNS Records: Create `akamai_dns_record.acme_txt` with zone prevalidation and lifecycle preconditions; supports custom zones and apex fallback.
- Propagation Wait: `time_sleep.wait_for_dns` with conditional `count`; triggers on DNS record changes to avoid unnecessary delays.
- Validation: `akamai_cps_dv_validation` for `prod`, `acc`, `test` with static `depends_on = [time_sleep.wait_for_dns]` and `timeouts { default = var.validation_timeout }` (default 5m).
- Makefile: Added `all`, `check-validation` (uses `-replace` to refresh status), `clean-dns` (uses `-target` and suppresses warnings), plus `output` for quick visibility.
- Documentation: README updated to reflect two-stage flow, provider alias usage, refresh limitations, and inclusion of [dns/outputs.tf](dns/outputs.tf).
- Outputs: Centralized Stage 2 outputs — `created_txt_records`, `validation_status` — in [dns/outputs.tf](dns/outputs.tf).
