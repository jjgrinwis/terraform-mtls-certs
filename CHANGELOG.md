# Changelog

## v0.2.0 — 2026-01-06

- Architecture: Split CPS DV validation into a third stage (`validation/`), isolating DNS (TXT + wait) from validation runs to avoid stale challenge issues and Let’s Encrypt auto-validation races.
- Makefile: `all` now runs apply → validate (DNS only) → run-validation (Stage 3). Added init/lint across all three stages; simplified DNS apply (no targets).
- Cleanup: Removed test suite and helper `zone_detection` module from repo.
- Providers: DNS stage uses only EdgeDNS alias; validation stage uses default Akamai provider. Documentation updated for the three-phase workflow and provider split.
- Lint: Resolved unused locals in dns; `make lint` now covers all stages.

Upgrade Notes:

- Run `make init` to re-init all stages, then `make all` (or `make apply`, `make validate`, `make run-validation`).
- Validation now lives in `validation/`; DNS stage no longer runs CPS validation.
- Tests removed; no action needed unless you relied on them.

## v0.1.1 — 2025-12-27

- Patch: add `release` target; Makefile alignment

- Upgrade Notes:
  - No manual steps required.
  - Optional: use `make release-with-changelog VERSION=v0.1.2 NOTES="..."` for next patch tagging.

## v0.1.0 — 2025-12-27

- Architecture: Split-stage Terraform — Stage 1 enrollments; Stage 2 DNS + CPS DV validation via `terraform_remote_state` (local backend). Akamai provider alias `akamai.edgedns` scoped only to Stage 2.
- DNS Records: Create `akamai_dns_record.acme_txt` with zone prevalidation and lifecycle preconditions; supports custom zones and apex fallback.
- Propagation Wait: `time_sleep.wait_for_dns` with conditional `count`; triggers on DNS record changes to avoid unnecessary delays.
- Validation: `akamai_cps_dv_validation` for `prod`, `acc`, `test` with static `depends_on = [time_sleep.wait_for_dns]` and `timeouts { default = var.validation_timeout }` (default 5m).
- Makefile: Added `all`, `check-validation` (uses `-replace` to refresh status), `clean-dns` (uses `-target` and suppresses warnings), plus `output` for quick visibility.
- Documentation: README updated to reflect two-stage flow, provider alias usage, refresh limitations, and inclusion of [dns/outputs.tf](dns/outputs.tf).
- Outputs: Centralized Stage 2 outputs — `created_txt_records`, `validation_status` — in [dns/outputs.tf](dns/outputs.tf).

- Upgrade Notes:
  - After Stage 1 `make apply`, run `make validate` to create DNS TXT records and trigger validation.
  - If validation status appears stale, run `make check-validation` to force a status refresh.
  - When CPS clears challenge tokens, run `make clean-dns` to remove TXT records.
  - For `make destroy`, acknowledge certificate revocation in the CPS UI per provider requirements.
