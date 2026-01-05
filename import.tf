# example import.tf file for importing an existing Akamai CPS DV Enrollment resource
# Update certificate_id which can be found in the Akamai Control Center (CPS) or via API.
# make sure the SANS and COMMON_NAME in terraform.tfvars match the existing resource, otherwise Terraform will try to update the resource on next apply!
locals {
  certificate_id = "289609"
  contract_id    = data.akamai_contract.contract.id
}

import {
  to = module.enroll_test.akamai_cps_dv_enrollment.this
  id = "${local.certificate_id},${local.contract_id}"
}
