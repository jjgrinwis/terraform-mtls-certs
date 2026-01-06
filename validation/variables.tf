variable "validation_timeout" {
  description = "Maximum time to wait for CPS DV validation to complete."
  type        = string
  default     = "5m"
  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.validation_timeout))
    error_message = "validation_timeout must be a valid duration string (e.g., '5m', '10m', '1h')."
  }
}
