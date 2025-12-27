terraform {
  required_version = ">= 1.5"
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
}
