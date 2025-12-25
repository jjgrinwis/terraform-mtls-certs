/*
Module: cps_dv_enrollment

Note about sequencing:
The Akamai CPS API enforces a single enrollment creation in-flight per account.
Attempting to create multiple enrollments concurrently will produce 409
conflicts. When the root module needs multiple enrollments they should be invoked sequentially and
chained with `depends_on` (see root `main.tf`) so that each enrollment is
created only after the previous one completes.

Alternative: if callers prefer parallel calls across resources, run Terraform
with `-parallelism=1` to globally force serial operations. We prefer the
explicit sequential module approach to keep behavior deterministic.
*/

# Lookup mTLS CA set if specified
data "akamai_mtlstruststore_ca_set" "mtls" {
  count = var.enrollment.mtls_ca_set_name != null ? 1 : 0
  name  = var.enrollment.mtls_ca_set_name
}

resource "akamai_cps_dv_enrollment" "this" {
  # This module now creates a single enrollment from `var.enrollment`.
  contract_id                           = var.contract_id
  acknowledge_pre_verification_warnings = var.defaults.acknowledge_pre_verification_warnings
  common_name                           = var.enrollment.common_name
  sans                                  = var.enrollment.sans
  secure_network                        = var.defaults.secure_network
  sni_only                              = var.defaults.sni_only

  timeouts {
    default = var.defaults.timeouts["default"]
  }

  admin_contact {
    first_name       = var.defaults.admin_contact.first_name
    last_name        = var.defaults.admin_contact.last_name
    phone            = var.defaults.admin_contact.phone
    email            = var.defaults.admin_contact.email
    address_line_one = var.defaults.admin_contact.address_line_one
    address_line_two = var.defaults.admin_contact.address_line_two
    city             = var.defaults.admin_contact.city
    country_code     = var.defaults.admin_contact.country_code
    organization     = var.defaults.admin_contact.organization
    postal_code      = var.defaults.admin_contact.postal_code
    region           = var.defaults.admin_contact.region
    title            = var.defaults.admin_contact.title
  }

  tech_contact {
    first_name       = var.defaults.tech_contact.first_name
    last_name        = var.defaults.tech_contact.last_name
    phone            = var.defaults.tech_contact.phone
    email            = var.defaults.tech_contact.email
    address_line_one = var.defaults.tech_contact.address_line_one
    address_line_two = var.defaults.tech_contact.address_line_two
    city             = var.defaults.tech_contact.city
    country_code     = var.defaults.tech_contact.country_code
    organization     = var.defaults.tech_contact.organization
    postal_code      = var.defaults.tech_contact.postal_code
    region           = var.defaults.tech_contact.region
    title            = var.defaults.tech_contact.title
  }

  certificate_chain_type = var.defaults.certificate_chain_type

  csr {
    country_code        = var.defaults.csr.country_code
    city                = var.defaults.csr.city
    organization        = var.defaults.csr.organization
    organizational_unit = var.defaults.csr.organizational_unit
    state               = var.defaults.csr.state
  }

  network_configuration {
    disallowed_tls_versions = var.defaults.network_configuration.disallowed_tls_versions
    clone_dns_names         = var.defaults.network_configuration.clone_dns_names
    geography               = var.defaults.network_configuration.geography
    ocsp_stapling           = var.defaults.network_configuration.ocsp_stapling
    preferred_ciphers       = var.defaults.network_configuration.preferred_ciphers
    must_have_ciphers       = var.defaults.network_configuration.must_have_ciphers
    quic_enabled            = var.defaults.network_configuration.quic_enabled

    # mTLS client authentication configuration (optional)
    dynamic "client_mutual_authentication" {
      for_each = var.enrollment.mtls_ca_set_name != null ? [1] : []
      content {
        set_id                 = data.akamai_mtlstruststore_ca_set.mtls[0].id
        send_ca_list_to_client = true
        ocsp_enabled           = true
      }
    }
  }

  signature_algorithm = var.defaults.signature_algorithm

  organization {
    name             = var.defaults.organization.name
    phone            = var.defaults.organization.phone
    address_line_one = var.defaults.organization.address_line_one
    address_line_two = var.defaults.organization.address_line_two
    city             = var.defaults.organization.city
    country_code     = var.defaults.organization.country_code
    postal_code      = var.defaults.organization.postal_code
    region           = var.defaults.organization.region
  }


}

# DNS TXT records are managed separately in the dns/ subdirectory.
# This avoids for_each state issues when dns_challenges changes dynamically.
# 
# After running `terraform apply` in the root, run:
#   cd dns && terraform apply
#
# The dns_challenges output is consumed by dns/main.tf to create records.
