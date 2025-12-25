# Default Akamai provider (used for CPS validation)
provider "akamai" {
  edgerc         = "~/.edgerc"
  config_section = "gss-demo"
}

# Alias dedicated to EdgeDNS record management
provider "akamai" {
  alias          = "edgedns"
  edgerc         = "~/.edgerc"
  config_section = "gss-demo"
}
