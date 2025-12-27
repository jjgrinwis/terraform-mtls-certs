variable "custom_zones" {
  description = "List of delegated DNS subzones for zone detection."
  type        = list(string)
}

variable "dns_challenges" {
  description = "List of DNS challenge objects (domain, full_path, response_body)."
  type = list(object({
    domain        = string
    full_path     = string
    response_body = string
  }))
}
