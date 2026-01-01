@fast
Feature: Nix Traceability with Scope Metadata
  As a security analyst
  I want ecosystem packages to have Nix build provenance with scope information
  So that I can trace vulnerabilities and understand deployment impact

  Background:
    Given the SBOM directory "compliance/sboms" exists

  Scenario Outline: All ecosystem packages must have complete Nix traceability
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    When I find all "<ecosystem>" packages
    Then each package should have a "nix:purl" property
    And each package should have a "nix:drv" property
    And each package should have a "nix:output" property
    And each package should have a "sbom:scope" property
    And each package should have an externalReference of type "build-system"

    Examples:
      | service     | ecosystem  |
      | fee-service | pkg:pypi/  |
      | smoke-tests | pkg:gem/   |

  Scenario Outline: Traceability coverage must be 100%
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    When I find all "<ecosystem>" packages
    Then all packages should have "nix:output" property
    And the traceability coverage should be 100%

    Examples:
      | service     | ecosystem  |
      | fee-service | pkg:pypi/  |
      | smoke-tests | pkg:gem/   |

  Scenario Outline: Runtime packages must have correct scope metadata
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    When I find all "<ecosystem>" packages
    And I filter packages by property "sbom:scope" with value "runtime"
    Then the package count should be at least <min_count>
    And each package should have scope "required" at component level

    Examples:
      | service     | ecosystem  | min_count |
      | fee-service | pkg:pypi/  | 15        |
      | smoke-tests | pkg:gem/   | 30        |

  Scenario: Python dev-only packages must be marked as excluded
    Given I load the SBOM file "compliance/sboms/container-fee-service.cdx.json"
    When I find all "pkg:pypi/" packages
    And I filter packages by property "sbom:scope" with value "dev-only"
    Then the package list should include "pytest"
    And the package list should include "pluggy"
    And the package list should include "iniconfig"
    And each package should have scope "excluded" at component level

  Scenario Outline: No duplicate Nix components after traceability mapping
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    When I find all "<ecosystem>" packages with "nix:purl" property
    Then there should be no component with that "nix:purl" as its primary purl

    Examples:
      | service     | ecosystem  |
      | fee-service | pkg:pypi/  |
      | smoke-tests | pkg:gem/   |

  Scenario Outline: Nix output paths must be valid store paths
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    When I find all "<ecosystem>" packages
    And I extract all "nix:output" property values
    Then each value should start with "/nix/store/"
    And each value should contain "<prefix>-"

    Examples:
      | service     | ecosystem  | prefix      |
      | fee-service | pkg:pypi/  | python3.11  |
      | smoke-tests | pkg:gem/   | ruby3.3     |

  Scenario Outline: External references must point to Nix store outputs
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    When I find all "<ecosystem>" packages
    Then each package should have an externalReference with URL starting with "nix:store:/nix/store/"

    Examples:
      | service     | ecosystem  |
      | fee-service | pkg:pypi/  |
      | smoke-tests | pkg:gem/   |
