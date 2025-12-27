terraform {
  # Terraform 1.6+ required for testing framework support (.tftest.hcl files)
  required_version = ">= 1.6"

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
