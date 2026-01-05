# Tests for custom zone matching and apex fallback using test module

# Run: custom zone matches delegated subzone
run "custom_zone_match" {
  command = plan

  module {
    source = "./tests/zone_detection"
  }

  variables {
    custom_zones = ["subzone01.example.com"]
    dns_challenges = [
      {
        domain        = "api.subzone01.example.com"
        full_path     = "_acme-challenge.api.subzone01.example.com."
        response_body = "abc"
      },
      {
        domain        = "www.example.com"
        full_path     = "_acme-challenge.www.example.com."
        response_body = "def"
      }
    ]
  }

  assert {
    condition     = output.zones["api.subzone01.example.com"] == "subzone01.example.com"
    error_message = "Expected delegated subzone match for api.subzone01.example.com"
  }

  assert {
    condition     = output.zones["www.example.com"] == "example.com"
    error_message = "Expected apex fallback for www.example.com"
  }
}

# Run: multiple nested domains, ensure apex fallback works
run "apex_fallback_for_nested_domains" {
  command = plan

  module {
    source = "./tests/zone_detection"
  }

  variables {
    custom_zones   = []
    dns_challenges = [
      {
        domain        = "foo.bar.baz.example.com"
        full_path     = "_acme-challenge.foo.bar.baz.example.com."
        response_body = "ghi"
      },
      {
        domain        = "service.us-east-1.example.com"
        full_path     = "_acme-challenge.service.us-east-1.example.com."
        response_body = "jkl"
      }
    ]
  }

  assert {
    condition     = output.zones["foo.bar.baz.example.com"] == "example.com"
    error_message = "Expected apex zone for nested domain foo.bar.baz.example.com"
  }

  assert {
    condition     = output.zones["service.us-east-1.example.com"] == "example.com"
    error_message = "Expected apex zone for service.us-east-1.example.com"
  }
}
