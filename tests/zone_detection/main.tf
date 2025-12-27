locals {
  # Helper: find matching custom zone for a domain (returns null if no match)
  matching_custom_zones = {
    for ch in var.dns_challenges : ch.domain => try(
      element(compact([for z in var.custom_zones : endswith(ch.domain, z) ? z : null]), 0),
      null
    )
  }

  # Helper: extract apex zone from domain (last two labels)
  apex_zones = {
    for ch in var.dns_challenges : ch.domain => join(".",
      slice(
        split(".", ch.domain),
        max(length(split(".", ch.domain)) - 2, 0),
        length(split(".", ch.domain))
      )
    )
  }

  # Compute zone for each challenge (supports delegated subzones)
  dns_records_to_create = {
    for ch in var.dns_challenges : ch.domain => {
      challenge = ch
      zone      = local.matching_custom_zones[ch.domain] != null ? local.matching_custom_zones[ch.domain] : local.apex_zones[ch.domain]
    }
  }
}

output "zones" {
  description = "Computed zone per challenge domain"
  value       = { for k, v in local.dns_records_to_create : k => v.zone }
}

output "record_names" {
  description = "Computed record names (trimmed full_path)"
  value       = { for ch in var.dns_challenges : ch.domain => trim(ch.full_path, ".") }
}
