# Test file for enrollments variable validation
# Tests the constraints defined in variables.tf:
# - Enrollments must include keys PROD, ACC, TEST
# - Keys can optionally have numeric suffixes: PROD-1, PROD-22, etc. (1-2 digits only)
# - Hostnames must be unique across all enrollments
# - common_name cannot appear in its own SANs
# - SANs count cannot exceed max_sans_per_enrollment

variables {
  group_name = "test-group"
  custom_zones = []
  secure_network = "enhanced-tls"
  max_sans_per_enrollment = 99
}

# Test 1: Valid configuration with all required keys
run "valid_enrollments_with_required_keys" {
  command = plan

  variables {
    enrollments = {
      PROD = {
        common_name      = "prod.example.com"
        sans             = ["www.prod.example.com", "api.prod.example.com"]
        mtls_ca_set_name = null
      }
      ACC = {
        common_name      = "acc.example.com"
        sans             = ["www.acc.example.com"]
        mtls_ca_set_name = null
      }
      TEST = {
        common_name      = "test.example.com"
        sans             = ["www.test.example.com"]
        mtls_ca_set_name = null
      }
    }
  }

  # Skip the plan command and just validate the variables
  expect_failures = []
}

# Test 2: Missing required keys (should fail validation)
run "missing_required_keys" {
  command = plan

  variables {
    enrollments = {
      PROD = {
        common_name      = "prod.example.com"
        sans             = ["www.prod.example.com"]
        mtls_ca_set_name = null
      }
      # Missing ACC and TEST
    }
  }

  expect_failures = [
    var.enrollments,
  ]
}

# Test 3: Duplicate hostname across enrollments (should fail validation)
run "duplicate_hostname_across_enrollments" {
  command = plan

  variables {
    enrollments = {
      PROD = {
        common_name      = "shared.example.com"
        sans             = ["www.shared.example.com"]
        mtls_ca_set_name = null
      }
      ACC = {
        common_name      = "acc.example.com"
        sans             = ["www.shared.example.com"]  # Duplicate!
        mtls_ca_set_name = null
      }
      TEST = {
        common_name      = "test.example.com"
        sans             = ["www.test.example.com"]
        mtls_ca_set_name = null
      }
    }
  }

  expect_failures = [
    var.enrollments,
  ]
}

# Test 4: common_name appears in its own SANs (should fail validation)
run "common_name_in_own_sans" {
  command = plan

  variables {
    enrollments = {
      PROD = {
        common_name      = "prod.example.com"
        sans             = ["prod.example.com"]  # Error: common_name in SANs!
        mtls_ca_set_name = null
      }
      ACC = {
        common_name      = "acc.example.com"
        sans             = ["www.acc.example.com"]
        mtls_ca_set_name = null
      }
      TEST = {
        common_name      = "test.example.com"
        sans             = ["www.test.example.com"]
        mtls_ca_set_name = null
      }
    }
  }

  expect_failures = [
    var.enrollments,
  ]
}

# Test 5: Too many SANs (exceeds max_sans_per_enrollment)
run "exceeds_max_sans" {
  command = plan

  variables {
    max_sans_per_enrollment = 3
    enrollments = {
      PROD = {
        common_name      = "prod.example.com"
        sans             = ["san1.prod.example.com", "san2.prod.example.com", "san3.prod.example.com", "san4.prod.example.com"]  # 4 SANs > max of 3
        mtls_ca_set_name = null
      }
      ACC = {
        common_name      = "acc.example.com"
        sans             = ["www.acc.example.com"]
        mtls_ca_set_name = null
      }
      TEST = {
        common_name      = "test.example.com"
        sans             = ["www.test.example.com"]
        mtls_ca_set_name = null
      }
    }
  }

  expect_failures = [
    var.enrollments,
  ]
}

# Test 6: Valid configuration with numbered variants
run "valid_enrollments_with_numbered_variants" {
  command = plan

  variables {
    enrollments = {
      PROD = {
        common_name      = "prod.example.com"
        sans             = ["www.prod.example.com"]
        mtls_ca_set_name = null
      }
      PROD-1 = {
        common_name      = "prod1.example.com"
        sans             = ["www.prod1.example.com"]
        mtls_ca_set_name = null
      }
      PROD-22 = {
        common_name      = "prod22.example.com"
        sans             = ["www.prod22.example.com"]
        mtls_ca_set_name = null
      }
      ACC = {
        common_name      = "acc.example.com"
        sans             = ["www.acc.example.com"]
        mtls_ca_set_name = null
      }
      TEST = {
        common_name      = "test.example.com"
        sans             = ["www.test.example.com"]
        mtls_ca_set_name = null
      }
    }
  }

  expect_failures = []
}

# Test 7: Invalid numeric suffix (3 digits, exceeds 1-2 digit limit)
run "invalid_numeric_suffix_too_many_digits" {
  command = plan

  variables {
    enrollments = {
      PROD = {
        common_name      = "prod.example.com"
        sans             = ["www.prod.example.com"]
        mtls_ca_set_name = null
      }
      PROD-123 = {
        common_name      = "prod123.example.com"
        sans             = ["www.prod123.example.com"]
        mtls_ca_set_name = null
      }
      ACC = {
        common_name      = "acc.example.com"
        sans             = ["www.acc.example.com"]
        mtls_ca_set_name = null
      }
      TEST = {
        common_name      = "test.example.com"
        sans             = ["www.test.example.com"]
        mtls_ca_set_name = null
      }
    }
  }

  expect_failures = [
    var.enrollments,
  ]
}

# Test 8: mTLS enabled for specific environments
run "mtls_configuration" {
  command = plan

  variables {
    enrollments = {
      PROD = {
        common_name      = "prod.example.com"
        sans             = ["www.prod.example.com"]
        mtls_ca_set_name = "prod-ca-set"  # mTLS enabled
      }
      ACC = {
        common_name      = "acc.example.com"
        sans             = ["www.acc.example.com"]
        mtls_ca_set_name = null  # No mTLS
      }
      TEST = {
        common_name      = "test.example.com"
        sans             = ["www.test.example.com"]
        mtls_ca_set_name = "test-ca-set"  # Different CA set
      }
    }
  }

  assert {
    condition     = var.enrollments.PROD.mtls_ca_set_name == "prod-ca-set"
    error_message = "PROD should have mTLS enabled"
  }

  assert {
    condition     = var.enrollments.ACC.mtls_ca_set_name == null
    error_message = "ACC should have mTLS disabled"
  }

  assert {
    condition     = var.enrollments.TEST.mtls_ca_set_name == "test-ca-set"
    error_message = "TEST should use test-ca-set"
  }
}

# Test 9: Invalid key pattern (wrong environment name)
run "invalid_key_pattern" {
  command = plan

  variables {
    enrollments = {
      PROD = {
        common_name      = "prod.example.com"
        sans             = ["www.prod.example.com"]
        mtls_ca_set_name = null
      }
      DEV = {
        common_name      = "dev.example.com"
        sans             = ["www.dev.example.com"]
        mtls_ca_set_name = null
      }
      ACC = {
        common_name      = "acc.example.com"
        sans             = ["www.acc.example.com"]
        mtls_ca_set_name = null
      }
      TEST = {
        common_name      = "test.example.com"
        sans             = ["www.test.example.com"]
        mtls_ca_set_name = null
      }
    }
  }

  expect_failures = [
    var.enrollments,
  ]
}