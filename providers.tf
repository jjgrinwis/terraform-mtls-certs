# Default Akamai provider for CPS operations (root stage only)
# Terraform >= 1.5 required for declarative import block support
provider "akamai" {
  edgerc         = "~/.edgerc"
  config_section = "gss-demo"
}
