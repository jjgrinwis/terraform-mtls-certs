# Terraform Akamai CPS DV Certificates with mTLS Support (PROD/ACC/TEST)

This project provisions three DV certificates (PROD, ACC, TEST) in Akamai CPS with optional mutual TLS (mTLS) configuration, automates DNS TXT records for ACME challenges in Edge DNS, and triggers token validation to issue and deploy certificates to Akamai's staging and production networks.

## Overview

- Stage 1 (root project): creates CPS DV enrollments for PROD/ACC/TEST sequentially and exposes outputs (`certificate_enrollment_ids`, `dns_challenges_*`, `enrollments`, `custom_zones`).
- Stage 2 (dns/ project): reads Stage 1 outputs via `terraform_remote_state`, creates DNS TXT records in Edge DNS, waits briefly for propagation, and triggers DV validation.
- After DV approval, CPS clears challenge tokens; on the next Stage 2 apply, Terraform removes TXT records automatically.

### Why two runs?

Terraform must know all `for_each` keys at plan time. The DNS TXT records depend on `dns_challenges` returned by CPS only after the enrollment resource has been created or updated. In a single pass, those challenges are "known after apply", so planning DNS records fails with "Invalid for_each argument". Splitting into two runs ensures Stage 2 plans against finalized outputs from Stage 1, making the DNS record keys concrete and the plan deterministic.

## Prerequisites

- Terraform CLI >= 1.5
- Akamai Terraform provider configured (EdgeGrid credentials)
- Access to Akamai Control Center group containing the contract

### Authenticate the Akamai provider

You can use either environment variables, `~/.edgerc` file or use direct in provider section.

Environment variables (EdgeGrid):

```bash
export AKAMAI_HOST="akab-xxxxxxxx.luna.akamaiapis.net"
export AKAMAI_CLIENT_TOKEN="xxxxx"
export AKAMAI_CLIENT_SECRET="xxxxx"
export AKAMAI_ACCESS_TOKEN="xxxxx"
```

Or with `~/.edgerc`:

```bash
export AKAMAI_EDGERC="$HOME/.edgerc"
export AKAMAI_SECTION="default"
```

**Provider credentials:** This project supports separate credentials: the default `akamai` provider for CPS operations and the `akamai.edgedns` alias for Edge DNS. See [providers.tf](providers.tf) for the two provider blocks and [main.tf](main.tf) for how the alias is passed to the module via the `providers` block. The module uses the default provider for CPS and the alias for DNS.

Example provider configuration (matches `providers.tf`):

```hcl
# Default Akamai provider for CPS operations
provider "akamai" {
  edgerc         = "~/.edgerc"
  config_section = "example"
}

# Edge DNS provider alias using separate credentials/section
provider "akamai" {
  alias          = "edgedns"
  edgerc         = "~/.edgerc"
  config_section = "example-demo"
}

# DNS records in Stage 2 use the edgedns alias
resource "akamai_dns_record" "acme_txt" {
  for_each = local.dns_records_to_create
  provider = akamai.edgedns

  zone       = each.value.zone
  name       = trim(each.value.challenge.full_path, ".")
  recordtype = "TXT"
  ttl        = 60
  target     = [each.value.challenge.response_body]
}
```

## Project Structure

- Stage 1 (root):
  - [main.tf](main.tf): Contract lookup and three sequential enrollments (`PROD → ACC → TEST`).
  - [variables.tf](variables.tf): Inputs (defaults object, `group_name`, `enrollments`, `custom_zones`, `secure_network`, `max_sans_per_enrollment`).
  - [outputs.tf](outputs.tf): Exposes `certificate_enrollment_ids`, `dns_challenges_*`, `enrollments`, `custom_zones`.
  - [terraform.tfvars](terraform.tfvars): Your values for group, contacts, enrollments, custom zones.
  - [modules/cps_dv_enrollment](modules/cps_dv_enrollment): Enrollment module.
- Stage 2 (dns/):
  - [dns/main.tf](dns/main.tf): Reads Stage 1 outputs via `terraform_remote_state`, creates TXT records, waits for DNS propagation (configurable), triggers validation for each environment.
  - [dns/outputs.tf](dns/outputs.tf): Exposes `created_txt_records` and `validation_status`.
  - [dns/variables.tf](dns/variables.tf): Configuration for DNS propagation wait time.
  - [dns/providers.tf](dns/providers.tf): Akamai provider for Edge DNS + CPS validation.
  - [dns/versions.tf](dns/versions.tf): Required providers.

## Key Concepts

### Sequential enrollments

CPS enforces “one enrollment at a time”. Creating multiple in parallel causes HTTP 409 errors. We therefore call the module three times and chain with `depends_on`:

- `enroll_prod` → `enroll_acc` → `enroll_test`

### Zone detection for DNS

For each challenge hostname:

- If hostname ends with an entry in `var.custom_zones` (e.g., `subzone01.example.com`) use that as the zone.
- Otherwise, use the last two labels (e.g., `example.com`).
- Record name is the full FQDN challenge path (`_acme-challenge.<host>.<zone>`), trimmed of trailing dot.

**Important:** Zones must already exist in Akamai EdgeDNS. This configuration does not create zones; it only creates TXT records within existing zones. Ensure all detected zones (from `custom_zones` or the fallback last-two-label logic) are already delegated and set up in EdgeDNS before applying.

## mTLS Configuration

This project supports optional mutual TLS (mTLS) for client certificate authentication on any or all certificates.

### Prerequisites for mTLS

1. **Create a CA Set in Akamai Trust Store** via the Control Center or API
2. **Upload your trusted CA certificates** to the CA set
3. **Note the CA set name** - you'll use this in the enrollment configuration

### Enabling mTLS

To enable mTLS for a certificate, add the `mtls_ca_set_name` parameter to your enrollment:

```hcl
enrollments = {
  PROD = {
    common_name      = "prod.example.com"
    sans             = ["www.prod.example.com"]
    mtls_ca_set_name = "production-ca-set"  # Enable mTLS with this CA set
  }
  ACC = {
    common_name      = "acc.example.com"
    sans             = ["www.acc.example.com"]
    mtls_ca_set_name = null  # No mTLS for this certificate
  }
  TEST = {
    common_name      = "test.example.com"
    sans             = ["www.test.example.com"]
    mtls_ca_set_name = "test-ca-set"  # Different CA set for test environment
  }
}
```

### mTLS Behavior

When `mtls_ca_set_name` is configured:

- Client certificate authentication is enabled on the certificate
- `send_ca_list_to_client = true`: Akamai will send the list of trusted CAs to clients during TLS handshake
- `ocsp_enabled = true`: OCSP validation is enabled for client certificates
- Different environments can use different CA sets or no mTLS at all

When `mtls_ca_set_name` is `null` or omitted:

- Standard server-side TLS only (no client certificate requirement)

### Why two-stage DNS validation

- **Solves for_each limitation**: Terraform's `for_each` cannot use keys derived from module outputs (unknown at plan time). By splitting into two stages, Stage 1 creates enrollments and outputs `dns_challenges`, then Stage 2 uses those concrete values as keys for DNS records.
- **Automatic cleanup**: When CPS clears challenge tokens after approval, Stage 1's `dns_challenges` becomes empty. Running `make clean-dns` syncs Stage 2, which automatically removes the corresponding TXT records.
- **Separation of concerns**: Stage 1 handles CPS enrollments, Stage 2 handles EdgeDNS records and validation triggers.
- **Flexible credential scoping**: EdgeDNS operations in Stage 2 can use different Akamai credentials/section via the `akamai.edgedns` provider alias.

## Inputs

Define enrollments and zones in [terraform.tfvars](terraform.tfvars):

```hcl
group_name = "Akamai Control Center group-a"

custom_zones = [
  "subzone01.example.com"
]

enrollments = {
  PROD = {
    common_name      = "prod.example.com"
    sans             = [
      "www.prod.example.com",
      "api.prod.example.com",
      "api.subzone01.example.com"
    ]
    mtls_ca_set_name = "production-ca-set"  # Optional: enable mTLS
  }
  ACC = {
    common_name      = "acc.example.com"
    sans             = [
      "www.acc.example.com",
      "api.acc.example.com"
    ]
    mtls_ca_set_name = null  # No mTLS
  }
  TEST = {
    common_name      = "test.example.com"
    sans             = [
      "www.test.example.com",
      "api.test.example.com"
    ]
    mtls_ca_set_name = null  # No mTLS
  }
}
```

### Stage 2 Configuration

Stage 2 (dns/) has the following configurable variable:

**dns_propagation_wait**: Time to wait for DNS TXT records to propagate globally before triggering CPS validation. Default is `"120s"` (2 minutes).

If you experience validation failures due to DNS not being propagated quickly enough, increase this value:

```hcl
# dns/terraform.tfvars (optional)
dns_propagation_wait = "180s"  # 3 minutes
```

Valid formats: `"120s"` (seconds), `"3m"` (minutes), `"1h"` (hours).

## Run (three-phase workflow)

The flow is split to avoid CPS 409s and Let’s Encrypt auto-validation races:

1. **Stage 1: enrollments (root)** – create/update CPS enrollments
2. **Stage 2: DNS (dns/)** – create ACME TXT records and wait for propagation
3. **Stage 3: validation (validation/)** – run CPS DV validation only if challenges remain

### Using Makefile (recommended)

```bash
make init            # init all three stages (root, dns, validation)
make apply           # Stage 1 only (enrollments)
make validate        # Stage 2 only (DNS TXT + wait, no CPS validation)
make run-validation  # Stage 3 only (CPS validation if challenges exist)
make all             # apply → validate → run-validation
make clean-dns       # sync/remove TXT records if challenges cleared
make check-validation # force refresh of validation status (validation/)
make output          # show enrollments, challenges, validation status
```

### Manual Terraform commands (three stages)

```bash
# Stage 1 (root)
cd terraform-mtls-certs
terraform init
terraform apply

# Stage 2 (dns) — TXT records + wait
cd dns
terraform init
terraform apply

# Stage 3 (validation) — optional, runs only if challenges still exist
cd ../validation
terraform init
terraform apply
```

## Importing Existing Certificates

If you already have CPS DV enrollments created outside of Terraform, you can import them into the Terraform state using the bulk import feature.

### Using the import.tf file

The [import.tf](import.tf) file contains the import configuration to bring existing enrollments into Terraform management:

```hcl
locals {
  certificate_id = "289609"  # Update with your enrollment ID
  contract_id    = data.akamai_contract.contract.id  # Uses the contract from main.tf
}

import {
  to = module.enroll_test.akamai_cps_dv_enrollment.this
  id = "${local.certificate_id},${local.contract_id}"
}
```

### Steps to import

1. **Update the certificate_id** in [import.tf](import.tf) with your enrollment ID from Akamai Control Center.

2. **Initialize and plan**:

```bash
terraform init
terraform plan
```

The plan will show the import action and any differences between the actual enrollment and your Terraform configuration.

3. **Apply the import**:

```bash
terraform apply
```

Or to import only without affecting other resources:

```bash
terraform apply -target=module.enroll_test.akamai_cps_dv_enrollment.this
```

4. **Clean up** (optional):
   - After the import is successful, you can delete or comment out the import block in [import.tf](import.tf).
   - The enrollment will remain in the Terraform state and can be managed normally.

### Import ID format

The Akamai provider requires the import ID in the format: `enrollment_id,contract_id`

- **enrollment_id**: The numeric ID of the enrollment (e.g., `289609`)
- **contract_id**: The contract ID from your Akamai account (e.g., `ctr_M-1YX7F61`)

The [import.tf](import.tf) example uses `data.akamai_contract.contract.id` to automatically fetch the contract ID from your configuration.

## Outputs

Stage 1 (root):

```bash
terraform output certificate_enrollment_ids
terraform output dns_challenges_prod
terraform output dns_challenges_acc
terraform output dns_challenges_test
```

Stage 2 (dns):

```bash
terraform output created_txt_records
```

Stage 3 (validation):

```bash
terraform output validation_status
```

## Using Terraform Cloud (share outputs, not whole state)

You can host Stage 1 state in Terraform Cloud and have Stage 2 read only its outputs. This gives you locking, RBAC, audit, and avoids coupling to the entire state file.

### Option A: Remote backend (read state via `terraform_remote_state`)

Configure Stage 1 to use Terraform Cloud:

```hcl
# Root (Stage 1): versions.tf
terraform {
  cloud {
    organization = "your-org"
    workspaces {
      name = "mtls-certs-stage1"
    }
  }
  required_providers {
    akamai = { source = "akamai/akamai" }
    time   = { source = "hashicorp/time" }
  }
}
```

Then Stage 2 reads those outputs via the Remote backend:

```hcl
# dns/main.tf (Stage 2)
data "terraform_remote_state" "stage1" {
  backend = "remote"
  config = {
    organization = "your-org"
    workspaces   = { name = "mtls-certs-stage1" }
  }
}

locals {
  enrollment_ids = data.terraform_remote_state.stage1.outputs.certificate_enrollment_ids
  enrollments    = data.terraform_remote_state.stage1.outputs.enrollments
  custom_zones   = data.terraform_remote_state.stage1.outputs.custom_zones
  all_dns_challenges = concat(
    tolist(data.terraform_remote_state.stage1.outputs.dns_challenges_prod),
    tolist(data.terraform_remote_state.stage1.outputs.dns_challenges_acc),
    tolist(data.terraform_remote_state.stage1.outputs.dns_challenges_test),
  )
}
```

Authentication: export a Terraform Cloud token locally (or use `terraform login`).

```bash
export TF_TOKEN_app_terraform_io=xxxxxx
```

### Option B: Terraform Cloud Outputs API (`tfe_outputs`)

If you prefer reading only outputs (not full state data), use the `tfe` provider and `data.tfe_outputs`. This fetches outputs via TFC’s API with workspace-level RBAC.

```hcl
# dns/versions.tf (add provider)
terraform {
  required_providers {
    akamai = { source = "akamai/akamai" }
    time   = { source = "hashicorp/time" }
    tfe    = { source = "hashicorp/tfe" }
  }
}

# dns/providers.tf (configure TFE)
provider "tfe" {}

# dns/main.tf (read outputs only)
data "tfe_outputs" "stage1" {
  organization = "your-org"
  workspace    = "mtls-certs-stage1"
}

locals {
  enrollment_ids     = data.tfe_outputs.stage1.values.certificate_enrollment_ids
  enrollments        = data.tfe_outputs.stage1.values.enrollments
  custom_zones       = data.tfe_outputs.stage1.values.custom_zones
  dns_challenges_prod = try(data.tfe_outputs.stage1.values.dns_challenges_prod, [])
  dns_challenges_acc  = try(data.tfe_outputs.stage1.values.dns_challenges_acc, [])
  dns_challenges_test = try(data.tfe_outputs.stage1.values.dns_challenges_test, [])
  all_dns_challenges = concat(
    tolist(local.dns_challenges_prod),
    tolist(local.dns_challenges_acc),
    tolist(local.dns_challenges_test),
  )
}
```

Authentication: same `TF_TOKEN_app_terraform_io` or `terraform login`.

### Why this is better

- Least privilege: Stage 2 reads only what it needs (outputs), not the whole state
- Access control: Workspace-level permissions in TFC
- Reliability: Locking, versioning, and audit for shared state
- CI-friendly: Clear dependency chain between workspaces

You can start local today and switch to Terraform Cloud later without changing Stage 2 logic—just update the data source configuration.

## Provider Usage (DNS + validation split)

- Stage 1 (root): default Akamai provider for CPS enrollments; no DNS writes.
- Stage 2 (dns): EdgeDNS alias only (no CPS validation here). See [dns/providers.tf](dns/providers.tf).
- Stage 3 (validation): default Akamai provider for CPS DV validation. See [validation/providers.tf](validation/providers.tf).

Bind DNS resources to the EdgeDNS alias in [dns/main.tf](dns/main.tf):

```hcl
resource "akamai_dns_record" "acme_txt" {
  for_each = local.dns_records_to_create
  provider = akamai.edgedns

  zone       = each.value.zone
  name       = trim(each.value.challenge.full_path, ".")
  recordtype = "TXT"
  ttl        = 60
  target     = [each.value.challenge.response_body]
}
```

Rationale:

- Least privilege: DNS credentials are isolated in Stage 2; validation uses CPS credentials in Stage 3.
- Separation of concerns: enrollments vs DNS vs validation.
- Clear audit trail: distinct credentials/sections per function.

Pitfalls:

- Forgetting `provider = akamai.edgedns` on DNS records will use the default provider.
- Running validation without refreshing Stage 1 may miss cleared challenges; use the three-phase flow (`apply` → `validate` → `run-validation`).

### Stage-2: step-by-step guide with `tfe_outputs`

1. Prepare Stage 1 (root) workspace in Terraform Cloud:

- Create workspace `mtls-certs-stage1` under your organization.
- Point the root project to it (see Remote backend example above).
- Ensure Stage 1 defines outputs: `certificate_enrollment_ids`, `dns_challenges_prod`, `dns_challenges_acc`, `dns_challenges_test`, `enrollments`, `custom_zones`.
- Run Stage 1 apply so outputs are populated.

2. Configure Stage 2 (dns) to read outputs only:

- Add the `tfe` provider in [dns/versions.tf](dns/versions.tf).
- Configure the provider in [dns/providers.tf](dns/providers.tf) and keep your Akamai provider.
- Add `data "tfe_outputs" "stage1"` pointing at your org/workspace.
- Map outputs to locals in [dns/main.tf](dns/main.tf) and build `all_dns_challenges` from the three outputs.

3. Authenticate to Terraform Cloud:

- Run `terraform login` or export `TF_TOKEN_app_terraform_io`.

4. Run Stage 2:

```bash
cd dns
terraform init
terraform plan
terraform apply
```

5. Pitfalls and tips:

- Outputs must exist in Stage 1; run a successful apply first.
- Keep output types consistent (lists/maps of objects) to avoid decoding issues.
- If you change workspace names or org, update `data.tfe_outputs` accordingly.
- You can use variable sets and workspace permissions in TFC to control access.

### Check validation progress

Since certificate validation can take some time, use the Makefile check-validation target to get the latest validation status:

```bash
# Fetch latest validation status from Akamai (forces validation resource recreation)
make check-validation
```

Note: Standard `terraform refresh` doesn't work for the validation resource because it doesn't update when enrollment_id and sans remain unchanged. The `make check-validation` target uses `-replace` to force recreation, which queries the CPS API for current status.

The `validation_status` output shows the current state of each certificate:

- `coordinate-domain-validation`: Initial state, CPS is coordinating with Let's Encrypt
- `wait-upload-third-party`: Waiting for Let's Encrypt to issue the certificate
- `wait-deploy-to-staging`: Certificate issued, deploying to Akamai staging
- `wait-deploy-to-prod`: Deploying to production network
- `complete`: Certificate fully deployed and active

## Monitoring & Verification

- Confirm TXT records propagate:

```bash
dig +short TXT _acme-challenge.prod.example.com @8.8.8.8
```

- Check validation status regularly:

```bash
make check-validation
```

- Watch validation progress in Akamai Control Center → CPS.

## Troubleshooting

- **DV validation fails** (DNS not propagated):
  - Increase `dns_propagation_wait` in `dns/terraform.tfvars` (e.g., `"180s"` or `"3m"`).
  - DNS propagation times vary by geography and DNS provider. The default 120s may be insufficient for global propagation.
  - Verify TXT records are visible: `dig +short TXT _acme-challenge.yourdomain.com @8.8.8.8`
- "Invalid value for a zone name" errors:
  - Ensure `custom_zones` includes delegated subzones that host the record.
  - Otherwise the fallback uses last two labels (apex zone).
- Null value for TXT record `target`:
  - Happens if `response_body` isn't present yet; we filter nulls so those entries don't create records.
  - Re-run after enrollment reports `dns_challenges`.
- CPS 409 errors (parallel enrollments):
  - Keep sequential module calls and avoid parallel creation.
- CPS 409 errors (CN already active on another enrollment):
  - CPS returns 409 if the common name (or a SAN) is already active on a different enrollment. Reuse the existing enrollment or remove/retire the conflicting certificate before creating a new one with the same CN/SAN.
- Masked values (`...`) in plans:
  - The provider sometimes redacts strings in plan; rely on apply and console verification (`terraform console`).

## Notes

- The Akamai Terraform provider for DV enrollments does not expose a distinct "certificate ID" for Let’s Encrypt DV certs. Use the **enrollment ID** to reference the certificate in CPS.
- After DV approval, CPS clears `dns_challenges`. Terraform then removes TXT records on the next plan/apply.
- Validation time varies (~30–90 minutes) including deployment to production.

## Frequently Asked Questions

- **Can I run all three enrollments in parallel?** No; CPS limits you to one at a time. The project enforces sequential creation.
- **Do I need HTTP validation?** DNS validation via TXT records is sufficient. CPS may also provide HTTP challenges; this config focuses on DNS.
- **Where do I see the certificate?** Use the enrollment ID in CPS UI, or query CPS APIs; Terraform tracks enrollments/validation but doesn't expose a separate certificate ID for DV.
- **How do I enable mTLS?** Create a CA set in Akamai Trust Store, then add `mtls_ca_set_name = "your-ca-set-name"` to your enrollment. Set to `null` to disable mTLS.
- **Can different environments use different CA sets?** Yes, each enrollment can specify its own `mtls_ca_set_name` or use `null` for no mTLS.
- **Does this project create the CA set?** No, the CA set must already exist in your Akamai account. This configuration only references existing CA sets.

---

This setup aims to be resilient, explicit, and compliant with CPS constraints while keeping DNS automation straightforward and auditable.
