variable "dns_propagation_wait" {
  description = "Time to wait for DNS propagation before triggering CPS validation. Increase if validation fails due to DNS not being globally propagated."
  type        = string
  default     = "120s"
  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.dns_propagation_wait))
    error_message = "dns_propagation_wait must be a valid duration string (e.g., '120s', '3m', '1h')."
  }
}

variable "validation_timeout" {
  description = "Maximum time to wait for CPS DV validation to complete. Default is 5 minutes. Increase if validation takes longer."
  type        = string
  default     = "5m"
  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.validation_timeout))
    error_message = "validation_timeout must be a valid duration string (e.g., '5m', '10m', '1h')."
  }
}
