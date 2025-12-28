@fast
Feature: CPE Validation
  As a vulnerability analyst
  I want all components to have valid CPEs that match NVD database entries
  So that CVEs can be accurately matched to affected components

  Background:
    Given the SBOM directory "compliance/sboms" exists

  Scenario: Components should have CPE identifiers
    When I examine all files matching "compliance/sboms/container-*.cdx.json"
    Then at least 50% of components should have CPE identifiers

  Scenario: CPEs should follow CPE 2.3 format
    When I examine all files matching "compliance/sboms/container-*.cdx.json"
    Then all CPEs should match format "cpe:2.3:TYPE:VENDOR:PRODUCT:VERSION"

  @enforce_fix
  Scenario: glibc should have correct CPE vendor (gnu, not glibc)
    Given I load the SBOM file "compliance/sboms/container-api-gateway.cdx.json"
    When I find the component "glibc"
    And I extract the CPE
    Then the CPE vendor should be "gnu"
    And the CPE product should be "glibc"

  @enforce_fix
  Scenario: CPE versions should not have Nix package suffixes
    Given I load the SBOM file "compliance/sboms/container-web-portal.cdx.json"
    When I find the component "glibc"
    And I extract the CPE version
    Then the version should NOT match pattern ".*-[0-9]+$"
    And the version should match pattern "^[0-9]+\.[0-9]+"

  Scenario Outline: Common system libraries should have correct CPE vendors
    Given I load the SBOM file "compliance/sboms/container-fee-service.cdx.json"
    When I find the component "<component_name>"
    And I extract the CPE
    Then the CPE vendor should be "<expected_vendor>"

    Examples:
      | component_name | expected_vendor |
      | bash           | gnu             |
      | openssl        | openssl         |
      | python3        | python          |

  @network @slow
  Scenario: glibc CPE should be found in NVD database
    Given I load the SBOM file "compliance/sboms/container-api-gateway.cdx.json"
    When I find the component "glibc"
    And I extract the CPE
    And I normalize the CPE vendor to "gnu"
    And I remove Nix suffix from CPE version
    Then the CPE should exist in NVD database

  @network @slow
  Scenario: Common components should have NVD-recognized CPEs
    Given I load the SBOM file "compliance/sboms/container-web-portal.cdx.json"
    When I collect CPEs for well-known components:
      | glibc    |
      | bash     |
      | openssl  |
    And I normalize all CPE vendors
    And I remove Nix suffixes from all CPE versions
    Then at least 33% of CPEs should exist in NVD database

  Scenario: CPE vendor mappings should be documented
    Given the fixtures directory "compliance/sbom-tests/fixtures" exists
    When I load the fixture file "nvd_cpe_mappings.yml"
    Then the mappings should include vendor for "glibc"
    And the vendor for "glibc" should be "gnu"
