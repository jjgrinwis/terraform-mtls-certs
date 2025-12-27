# Stage 2: DNS Records and Validation (split project)
# Reads outputs from Stage 1 (root project's terraform.tfstate)

# Read Stage 1's state to get dns_challenges and enrollment info
# for now local backend is used; adjust as needed for your setup like S3, terraform Cloud, etc.
# https://developer.hashicorp.com/terraform/language/state/remote-state-data#alternative-ways-to-share-data-between-configurations
data "terraform_remote_state" "stage1" {
  backend = "local"
  config = {
    path = "${path.module}/../terraform.tfstate"
  }
}

locals {
  enrollment_ids = data.terraform_remote_state.stage1.outputs.certificate_enrollment_ids
  enrollments    = data.terraform_remote_state.stage1.outputs.enrollments
  custom_zones   = data.terraform_remote_state.stage1.outputs.custom_zones

  # Combine all dns_challenges from all enrollments
  all_dns_challenges = concat(
    tolist(data.terraform_remote_state.stage1.outputs.dns_challenges_prod),
    tolist(data.terraform_remote_state.stage1.outputs.dns_challenges_acc),
    tolist(data.terraform_remote_state.stage1.outputs.dns_challenges_test),
  )

  # Helper: find matching custom zone for a domain (returns null if no match)
  matching_custom_zones = {
    for ch in local.all_dns_challenges : ch.domain => try(
      element(compact([for z in local.custom_zones : endswith(ch.domain, z) ? z : null]), 0),
      null
    )
  }

  # Helper: extract apex zone from domain (last two labels, e.g., "example.com" from "api.prod.example.com")
  apex_zones = {
    for ch in local.all_dns_challenges : ch.domain => join(".",
      slice(
        split(".", ch.domain),
        max(length(split(".", ch.domain)) - 2, 0),
        length(split(".", ch.domain))
      )
    )
  }

  # Compute zone for each challenge (supports delegated subzones)
  dns_records_to_create = {
    for ch in local.all_dns_challenges : ch.domain => {
      challenge = ch
      # Use custom zone if domain matches, otherwise fall back to apex zone
      zone = local.matching_custom_zones[ch.domain] != null ? local.matching_custom_zones[ch.domain] : local.apex_zones[ch.domain]
    }
  }

  # Extract all unique zones that will be used (for validation)
  required_zones = toset([for record in local.dns_records_to_create : record.zone])
}

# Validate zone configuration using terraform_data with preconditions
# This provides clear error messages during planning if zones might be misconfigured
resource "terraform_data" "validate_zones" {
  for_each = local.required_zones

  lifecycle {
    precondition {
      condition     = length(each.value) > 0 && can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*$", each.value))
      error_message = <<-EOT
        Invalid DNS zone format: "${each.value}"

        DNS zones must be valid domain names (e.g., "example.com" or "subdomain.example.com").

        Troubleshooting:
        - Verify the zone exists in Akamai EdgeDNS
        - Check that custom_zones in terraform.tfvars matches your EdgeDNS zone configuration
        - Ensure domain names in enrollments are properly configured

        Required zones detected: ${jsonencode(local.required_zones)}
      EOT
    }
  }

  triggers_replace = {
    zone = each.value
  }
}

# Create DNS TXT records for ACME challenges
resource "akamai_dns_record" "acme_txt" {
  for_each = local.dns_records_to_create
  provider = akamai.edgedns

  zone       = each.value.zone
  name       = trim(each.value.challenge.full_path, ".")
  recordtype = "TXT"
  ttl        = 60
  target     = [each.value.challenge.response_body]

  # Ensure zone validation completes before creating records
  depends_on = [terraform_data.validate_zones]

  lifecycle {
    precondition {
      condition     = contains(keys(terraform_data.validate_zones), each.value.zone)
      error_message = <<-EOT
        DNS zone "${each.value.zone}" has not been validated.

        This zone must exist in Akamai EdgeDNS before DNS records can be created.
        Please verify:
        1. The zone "${each.value.zone}" is configured in EdgeDNS
        2. Your EdgeDNS credentials have access to this zone
        3. The zone is properly delegated and active

        Domain: ${each.value.challenge.domain}
        Challenge path: ${each.value.challenge.full_path}
      EOT
    }
  }
}

# Wait for DNS propagation (on initial creation and when DNS records change)
# Only runs if there are DNS records to create (skipped when challenges are empty)
# Uses 'triggers' to recreate the sleep whenever DNS records are added/removed/modified
# This ensures a fresh propagation wait when new challenges arrive during certificate updates
resource "time_sleep" "wait_for_dns" {
  count = length(local.dns_records_to_create) > 0 ? 1 : 0

  triggers = {
    # Recreate sleep when DNS records change (new challenges, cleared challenges, etc)
    dns_records = jsonencode(akamai_dns_record.acme_txt)
  }
  create_duration  = var.dns_propagation_wait
  destroy_duration = "0s"
}

# Trigger CPS DV validation for each environment
# Can timeout if certificate is being pushed to production; in that case, re-run the make target after some time.
# Note: depends_on references time_sleep.wait_for_dns which uses count. When count=1 (DNS records exist),
# Terraform treats it as a list and waits for propagation. When count=0 (no DNS records), it's empty.
# This allows make check-validation to run immediately when no DNS changes are needed, or wait when they are.
resource "akamai_cps_dv_validation" "prod" {
  enrollment_id                          = local.enrollment_ids["PROD"]
  sans                                   = local.enrollments["PROD"].sans
  acknowledge_post_verification_warnings = true
  depends_on                             = [time_sleep.wait_for_dns]

  timeouts {
    default = var.validation_timeout
  }
}

resource "akamai_cps_dv_validation" "acc" {
  enrollment_id                          = local.enrollment_ids["ACC"]
  sans                                   = local.enrollments["ACC"].sans
  acknowledge_post_verification_warnings = true
  depends_on                             = [time_sleep.wait_for_dns]

  timeouts {
    default = var.validation_timeout
  }
}

resource "akamai_cps_dv_validation" "test" {
  enrollment_id                          = local.enrollment_ids["TEST"]
  sans                                   = local.enrollments["TEST"].sans
  acknowledge_post_verification_warnings = true
  depends_on                             = [time_sleep.wait_for_dns]

  timeouts {
    default = var.validation_timeout
  }
}
