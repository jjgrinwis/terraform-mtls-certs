output "created_txt_records" {
  description = "DNS TXT records created for validation"
  value       = { for k, r in akamai_dns_record.acme_txt : k => r.id }
}

output "validation_status" {
  description = "Status of certificate validation for each environment"
  value = {
    PROD = akamai_cps_dv_validation.prod.status
    ACC  = akamai_cps_dv_validation.acc.status
    TEST = akamai_cps_dv_validation.test.status
  }
}
