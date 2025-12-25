output "enrollment_id" {
  description = "ID of the created enrollment"
  value       = akamai_cps_dv_enrollment.this.id
}

output "dns_challenges" {
  description = "List of dns_challenges returned from the enrollment"
  value       = akamai_cps_dv_enrollment.this.dns_challenges
}

