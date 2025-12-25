variable "group_name" {
  description = "The Akamai Control Center group name where resources will be created. Used to look up contract and group IDs."
  type        = string
  default     = "acc_group"
}

variable "cps_dv_enrollment_defaults" {
  description = "Default values for `akamai_cps_dv_enrollment` resources to avoid repeating static fields."
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
      # Note: client_mutual_authentication is not included here
      # It is automatically added by the module when mtls_ca_set_name is set in the enrollment
      # The module uses send_ca_list_to_client=true and ocsp_enabled=true as defaults
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
  default = {
    acknowledge_pre_verification_warnings = true
    secure_network                        = "enhanced-tls"
    sni_only                              = true
    timeouts                              = { default = "2h" }
    admin_contact = {
      first_name       = "John"
      last_name        = "Smith"
      phone            = "1-617-555-6789"
      email            = "jsmith@example.com"
      address_line_one = "1234 Main St."
      address_line_two = "Suite 123"
      city             = "Cambridge"
      country_code     = "US"
      organization     = "Main Street Corporation"
      postal_code      = "02142"
      region           = "MA"
      title            = "Director of Operations"
    }
    tech_contact = {
      first_name       = "Janet"
      last_name        = "Smithson"
      phone            = "1-617-555-6789"
      email            = "jsmithson@example.com"
      address_line_one = "1234 Main St."
      address_line_two = "Suite 123"
      city             = "Cambridge"
      country_code     = "US"
      organization     = "Main Street Corporation"
      postal_code      = "02142"
      region           = "MA"
      title            = "Director of Platform Services"
    }
    certificate_chain_type = "default"
    csr = {
      country_code        = "US"
      city                = "Cambridge"
      organization        = "Main Street Corporation"
      organizational_unit = "IT"
      state               = "MA"
    }
    network_configuration = {
      disallowed_tls_versions = ["TLSv1", "TLSv1_1"]
      clone_dns_names         = true
      geography               = "core"
      ocsp_stapling           = "on"
      preferred_ciphers       = "ak-akamai-2020q1"
      must_have_ciphers       = "ak-akamai-2020q1"
      quic_enabled            = false
    }
    signature_algorithm = "SHA-256"
    organization = {
      name             = "Main Street Corporation"
      phone            = "1-617-555-6789"
      address_line_one = "1234 Main St."
      address_line_two = "Suite 123"
      city             = "Cambridge"
      country_code     = "US"
      postal_code      = "02142"
      region           = "MA"
    }
  }
}

variable "custom_zones" {
  description = "List of delegated DNS subzones. Used to correctly determine the zone name when creating DNS challenge records. If a hostname ends with one of these zones, that zone is used; otherwise, the last two labels are assumed to be the zone (e.g., 'example.com')."
  type        = list(string)
  default     = ["subzone.example.com"]
}


variable "secure_network" {
  description = "Network security configuration for the certificate. Either 'enhanced-tls' for advanced security or 'standard-tls' for standard configuration."
  type        = string
  default     = "enhanced-tls"
  validation {
    condition     = contains(["enhanced-tls", "standard-tls"], var.secure_network)
    error_message = "secure_network must be either 'enhanced-tls' or 'standard-tls'."
  }
}

variable "max_sans_per_enrollment" {
  description = "Maximum number of Subject Alternative Names (SANs) allowed per certificate enrollment. Let's Encrypt and most CAs limit this to 100."
  type        = number
  default     = 99
  validation {
    condition     = var.max_sans_per_enrollment > 0
    error_message = "max_sans_per_enrollment must be a positive number."
  }
}

# this should be the only variable customers need to modify to set up their enrollments
variable "enrollments" {
  description = <<-EOT
    Map of enrollments keyed by name (e.g. PROD, ACC, TEST). Each value is an object with common_name, sans list, and optional mtls_ca_set_name for mutual TLS.
    
    mtls_ca_set_name: Optional name of an existing mTLS CA set in Akamai Trust Store.
      - Set to null (or omit) to disable mTLS for this certificate
      - Provide the name of an active CA set to enable client certificate authentication
      - The CA set must already exist in your Akamai account (this configuration does not create CA sets)
      - Multiple certificates can share the same CA set or use different ones
    
    Example:
      PROD = { common_name = "prod.example.com", sans = ["www.prod.example.com"], mtls_ca_set_name = "production-ca-set" }
      ACC  = { common_name = "acc.example.com", sans = ["www.acc.example.com"], mtls_ca_set_name = null }  # No mTLS
  EOT
  type = map(object({
    common_name      = string
    sans             = list(string)
    mtls_ca_set_name = optional(string, null)
  }))
  validation {
    condition = (
      length(distinct(flatten([for k, e in var.enrollments : concat([e.common_name], e.sans)]))) == length(flatten([for k, e in var.enrollments : concat([e.common_name], e.sans)]))
      && alltrue([for k, e in var.enrollments : !contains(e.sans, e.common_name)])
      && alltrue([for k, e in var.enrollments : length(e.sans) <= var.max_sans_per_enrollment])
      && contains(keys(var.enrollments), "PROD")
      && contains(keys(var.enrollments), "ACC")
      && contains(keys(var.enrollments), "TEST")
    )
    error_message = "Enrollments must include keys PROD, ACC, TEST and each hostname (common_name and SANs) must be unique across all enrollments. A common_name cannot appear in its own SANs. Each enrollment's SANs list cannot exceed max_sans_per_enrollment."
  }
  default = {
    PROD = { common_name = "prod.example.com", sans = ["www.prod.example.com", "api.prod.example.com"], mtls_ca_set_name = null }
    ACC  = { common_name = "acc.example.com", sans = ["www.acc.example.com", "api.acc.example.com"], mtls_ca_set_name = null }
    TEST = { common_name = "test.example.com", sans = ["www.test.example.com", "api.test.example.com"], mtls_ca_set_name = null }
  }
}

