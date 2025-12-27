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

  # Compute zone for each challenge (supports delegated subzones)
  dns_records_to_create = {
    for ch in local.all_dns_challenges : ch.domain => {
      challenge = ch
      zone      = length(compact([for z in local.custom_zones : endswith(ch.domain, z) ? z : null])) > 0 ? element(compact([for z in local.custom_zones : endswith(ch.domain, z) ? z : null]), 0) : join(".", slice(split(".", ch.domain), max(length(split(".", ch.domain)) - 2, 0), length(split(".", ch.domain))))
    }
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
}

# Wait for DNS propagation (on initial creation and when DNS records change)
# Uses 'triggers' to recreate the sleep whenever DNS records are added/removed/modified
# This ensures a fresh propagation wait when new challenges arrive during certificate updates
resource "time_sleep" "wait_for_dns" {
  triggers = {
    # Recreate sleep when DNS records change (new challenges, cleared challenges, etc)
    dns_records = jsonencode(akamai_dns_record.acme_txt)
  }
  create_duration  = var.dns_propagation_wait
  destroy_duration = "0s"
}

# Trigger CPS DV validation for each environment
# Can timeout if certificate is being pushed to production; in that case, re-run the make target after some time.
# You can use timeout{} argument to adjust timeout duration if needed. Terraform default 20 minutes.
resource "akamai_cps_dv_validation" "prod" {
  enrollment_id                          = local.enrollment_ids["PROD"]
  sans                                   = local.enrollments["PROD"].sans
  acknowledge_post_verification_warnings = true
  depends_on                             = [time_sleep.wait_for_dns]
}

resource "akamai_cps_dv_validation" "acc" {
  enrollment_id                          = local.enrollment_ids["ACC"]
  sans                                   = local.enrollments["ACC"].sans
  acknowledge_post_verification_warnings = true
  depends_on                             = [time_sleep.wait_for_dns]
}

resource "akamai_cps_dv_validation" "test" {
  enrollment_id                          = local.enrollment_ids["TEST"]
  sans                                   = local.enrollments["TEST"].sans
  acknowledge_post_verification_warnings = true
  depends_on                             = [time_sleep.wait_for_dns]
}
