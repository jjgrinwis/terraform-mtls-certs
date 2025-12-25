variable "defaults" {
  description = "Defaults object for akamai_cps_dv_enrollment (pass var.cps_dv_enrollment_defaults)."
  type = object({
    acknowledge_pre_verification_warnings = bool
    secure_network                        = string
    sni_only                              = bool
    timeouts                              = map(string)
    admin_contact = object({
      first_name       = string
      last_name        = string
      phone            = string
      email            = string
      address_line_one = string
      address_line_two = string
      city             = string
      country_code     = string
      organization     = string
      postal_code      = string
      region           = string
      title            = string
    })
    tech_contact = object({
      first_name       = string
      last_name        = string
      phone            = string
      email            = string
      address_line_one = string
      address_line_two = string
      city             = string
      country_code     = string
      organization     = string
      postal_code      = string
      region           = string
      title            = string
    })
    certificate_chain_type = string
    csr = object({
      country_code        = string
      city                = string
      organization        = string
      organizational_unit = string
      state               = string
    })
    network_configuration = object({
      disallowed_tls_versions = list(string)
      clone_dns_names         = bool
      geography               = string
      ocsp_stapling           = string
      preferred_ciphers       = string
      must_have_ciphers       = string
      quic_enabled            = bool
    })
    signature_algorithm = string
    organization = object({
      name             = string
      phone            = string
      address_line_one = string
      address_line_two = string
      city             = string
      country_code     = string
      postal_code      = string
      region           = string
    })
  })
}

variable "contract_id" {
  type        = string
  description = "Contract id to use for the enrollment"
  validation {
    condition     = length(trimspace(var.contract_id)) > 0
    error_message = "The contract_id must be provided and cannot be empty."
  }
}

variable "enrollment" {
  description = <<-EOT
Single enrollment object to create. The module now accepts one object with `common_name`, `sans`, and optional `mtls_ca_set_name`.
Example: { common_name = "prod.example.com", sans = ["www.example.com"], mtls_ca_set_name = "my-ca-set" }

Note: SANs list can be empty - CPS automatically adds the common_name to the certificate's SANs.
EOT
  type = object({
    common_name      = string
    sans             = list(string)
    mtls_ca_set_name = optional(string, null)
  })
  validation {
    condition     = length(trimspace(var.enrollment.common_name)) > 0
    error_message = "The common_name must not be empty."
  }
  validation {
    condition     = !contains(var.enrollment.sans, var.enrollment.common_name)
    error_message = "The common_name should not be included in the SANs list - CPS automatically adds it to the certificate."
  }
}

variable "custom_zones" {
  description = "List of delegated DNS subzones for zone detection."
  type        = list(string)
  default     = []
}
