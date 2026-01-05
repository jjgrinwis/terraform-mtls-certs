locals {
  certificate_id = "289609"
  contract_id    = data.akamai_contract.contract.id
}

import {
  to = module.enroll_test.akamai_cps_dv_enrollment.this
  id = "${local.certificate_id},${local.contract_id}"
}
