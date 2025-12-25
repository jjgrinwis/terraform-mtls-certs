terraform {
  required_providers {
    akamai = {
      source  = "akamai/akamai"
      version = ">= 9.2.0"
    }
    # Required for the time_sleep resource to wait for DNS propagation
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
  # Requires >= 1.5.0 for improved variable validation features and optional object attributes
  required_version = ">= 1.5.0"
}
