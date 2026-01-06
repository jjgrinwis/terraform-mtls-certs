output "created_txt_records" {
  description = "DNS TXT records created for validation"
  value       = { for k, r in akamai_dns_record.acme_txt : k => r.id }
}
