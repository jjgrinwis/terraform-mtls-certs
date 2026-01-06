variable "dns_propagation_wait" {
  description = "Time to wait for DNS propagation before triggering CPS validation. Increase if validation fails due to DNS not being globally propagated."
  type        = string
  default     = "120s"
  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.dns_propagation_wait))
    error_message = "dns_propagation_wait must be a valid duration string (e.g., '120s', '3m', '1h')."
  }
}

