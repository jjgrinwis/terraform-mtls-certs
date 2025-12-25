terraform {
  required_providers {
    akamai = {
      source                = "akamai/akamai"
      version               = ">= 9.2.0"
      configuration_aliases = [akamai.edgedns]
    }
  }
}

# The module now supports separate credentials for EdgeDNS operations.
# In your root module, configure the akamai.edgedns provider alias with different credentials
# and pass it to the module via the providers block.
#
# Example in root module:
#   provider "akamai" {
#     edgerc = "~/.edgerc"
#     config_section = "default"  # For CPS operations
#   }
#
#   provider "akamai" {
#     alias = "edgedns"
#     edgerc = "~/.edgerc"
#     config_section = "dns"  # Different credentials for DNS
#   }
#
#   module "enroll_prod" {
#     source = "./modules/cps_dv_enrollment"
#     ...
#     providers = {
#       akamai.edgedns = akamai.edgedns
#     }
#   }
