# Stage 3: CPS DV validation (separate from DNS)

# Read Stage 1 state for enrollment IDs, SANs, and current challenges
data "terraform_remote_state" "stage1" {
  backend = "local"
  config = {
    path = "${path.module}/../terraform.tfstate"
  }
}

locals {
  enrollment_ids = data.terraform_remote_state.stage1.outputs.certificate_enrollment_ids
  enrollments    = data.terraform_remote_state.stage1.outputs.enrollments

  env_dns_challenges = {
    PROD = tolist(data.terraform_remote_state.stage1.outputs.dns_challenges_prod)
    ACC  = tolist(data.terraform_remote_state.stage1.outputs.dns_challenges_acc)
    TEST = tolist(data.terraform_remote_state.stage1.outputs.dns_challenges_test)
  }
}

# Run validation only when challenges are present
resource "akamai_cps_dv_validation" "prod" {
  count                                  = length(local.env_dns_challenges["PROD"]) > 0 ? 1 : 0
  enrollment_id                          = local.enrollment_ids["PROD"]
  sans                                   = local.enrollments["PROD"].sans
  acknowledge_post_verification_warnings = true

  timeouts {
    default = var.validation_timeout
  }
}

resource "akamai_cps_dv_validation" "acc" {
  count                                  = length(local.env_dns_challenges["ACC"]) > 0 ? 1 : 0
  enrollment_id                          = local.enrollment_ids["ACC"]
  sans                                   = local.enrollments["ACC"].sans
  acknowledge_post_verification_warnings = true

  timeouts {
    default = var.validation_timeout
  }
}

resource "akamai_cps_dv_validation" "test" {
  count                                  = length(local.env_dns_challenges["TEST"]) > 0 ? 1 : 0
  enrollment_id                          = local.enrollment_ids["TEST"]
  sans                                   = local.enrollments["TEST"].sans
  acknowledge_post_verification_warnings = true

  timeouts {
    default = var.validation_timeout
  }
}
