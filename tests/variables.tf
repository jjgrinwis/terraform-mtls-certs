# Minimal variables for testing (prevents data source evaluation)

variable "group_name" {
  description = "The Akamai Control Center group name where resources will be created."
  type        = string
  default     = "test-group"
}

variable "custom_zones" {
  description = "List of delegated DNS subzones."
  type        = list(string)
  default     = []
}

variable "secure_network" {
  description = "Network security configuration for the certificate."
  type        = string
  default     = "enhanced-tls"
  validation {
    condition     = contains(["enhanced-tls", "standard-tls"], var.secure_network)
    error_message = "secure_network must be either 'enhanced-tls' or 'standard-tls'."
  }
}

variable "max_sans_per_enrollment" {
  description = "Maximum number of Subject Alternative Names (SANs) allowed per certificate enrollment."
  type        = number
  default     = 99
  validation {
    condition     = var.max_sans_per_enrollment > 0
    error_message = "max_sans_per_enrollment must be a positive number."
  }
}

variable "enrollments" {
  description = "Map of enrollments keyed by name (e.g. PROD, ACC, TEST)."
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
