terraform {
  required_providers {
    akamai = {
      source  = "akamai/akamai"
      version = ">= 9.2.0"
    }
  }
}

# This module uses only the default Akamai provider for CPS enrollment operations.
# DNS operations are handled separately in the dns/ project.
