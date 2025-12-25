# Default Akamai provider for CPS operations (root stage only)
provider "akamai" {
  edgerc         = "~/.edgerc"
  config_section = "gss-demo"
}
