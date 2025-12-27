# First lookup contract as that contains information regarding contract and group ids.
data "akamai_contract" "contract" {
  group_name = var.group_name
}

/*
Sequential enrollment modules

IMPORTANT: The Akamai CPS API only allows one enrollment creation at a time. If
Terraform attempts to create multiple enrollments in parallel the CPS API will
return HTTP 409 errors ("you recently created another enrollment that is still
in process"). To avoid this we create the three enrollments sequentially by
calling the module three times and chaining them with `depends_on`.

If you change this layout, ensure the operations are still serialized (for
example by using `terraform apply -parallelism=1`), otherwise enrollment
creation may fail.

It will take around 2-3 minutes per enrollment to complete, so plan for that in
your Terraform runs.

There are some special security measures in CPS which prevents just removing certificates (destroy) or SAN entries.
Opened a support ticket with Akamai to clarify the exact behavior.

The merge() function combines var.cps_dv_enrollment_defaults with var.secure_network,
allowing the secure_network value to be controlled independently via the variable
while keeping all other defaults unchanged.
*/

module "enroll_prod" {
  source       = "./modules/cps_dv_enrollment"
  defaults     = merge(var.cps_dv_enrollment_defaults, { secure_network = var.secure_network })
  contract_id  = data.akamai_contract.contract.id
  enrollment   = var.enrollments["PROD"]
  custom_zones = var.custom_zones
}

module "enroll_acc" {
  source       = "./modules/cps_dv_enrollment"
  defaults     = merge(var.cps_dv_enrollment_defaults, { secure_network = var.secure_network })
  contract_id  = data.akamai_contract.contract.id
  enrollment   = var.enrollments["ACC"]
  custom_zones = var.custom_zones
  depends_on   = [module.enroll_prod]
}

module "enroll_test" {
  source       = "./modules/cps_dv_enrollment"
  defaults     = merge(var.cps_dv_enrollment_defaults, { secure_network = var.secure_network })
  contract_id  = data.akamai_contract.contract.id
  enrollment   = var.enrollments["TEST"]
  custom_zones = var.custom_zones
  depends_on   = [module.enroll_acc]
}

// DNS records and validation moved to separate dns/ project
