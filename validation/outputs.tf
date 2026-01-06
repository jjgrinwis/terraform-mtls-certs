output "validation_status" {
  description = "Status of certificate validation for each environment"
  value = {
    PROD = length(akamai_cps_dv_validation.prod) > 0 ? akamai_cps_dv_validation.prod[0].status : "skipped"
    ACC  = length(akamai_cps_dv_validation.acc) > 0 ? akamai_cps_dv_validation.acc[0].status : "skipped"
    TEST = length(akamai_cps_dv_validation.test) > 0 ? akamai_cps_dv_validation.test[0].status : "skipped"
  }
}
