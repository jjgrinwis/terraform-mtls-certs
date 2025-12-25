output "certificate_enrollment_ids" {
  description = "Enrollment IDs associated with the DV certificates per environment"
  value = {
    PROD = module.enroll_prod.enrollment_id
    ACC  = module.enroll_acc.enrollment_id
    TEST = module.enroll_test.enrollment_id
  }
}

output "dns_challenges_prod" {
  description = "DNS challenges for PROD enrollment"
  value       = module.enroll_prod.dns_challenges
}

output "dns_challenges_acc" {
  description = "DNS challenges for ACC enrollment"
  value       = module.enroll_acc.dns_challenges
}

output "dns_challenges_test" {
  description = "DNS challenges for TEST enrollment"
  value       = module.enroll_test.dns_challenges
}

output "enrollments" {
  description = "Enrollment configuration (for validation SANs)"
  value       = var.enrollments
}

output "custom_zones" {
  description = "Custom zones for DNS zone detection"
  value       = var.custom_zones
}

// DNS validation outputs are now produced by the separate dns/ project

