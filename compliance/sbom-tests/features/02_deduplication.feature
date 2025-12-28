@fast
Feature: Component Deduplication Across Containers
  As a vulnerability management analyst
  I want identical components to have identical PURLs across all containers
  So that I can accurately track which containers are affected by a CVE

  Background:
    Given the SBOM directory "compliance/sboms" exists
    And I load all container SBOMs

  Scenario: glibc has identical PURL across all containers
    When I find all components named "glibc" across all container SBOMs
    Then all instances should have the same PURL
    And the PURL should be "pkg:nix/glibc@2.40-66"
    And all instances should have the same version "2.40-66"

  Scenario Outline: Common base components have consistent PURLs
    When I find all components named "<component_name>" across all container SBOMs
    Then all instances should have identical PURLs
    And all instances should have identical versions

    Examples:
      | component_name |
      | bash           |
      | coreutils      |
      | tzdata         |
      | nss-cacert     |

  Scenario: Runtime-specific components appear only in appropriate containers
    When I analyze component distribution across containers
    Then "nodejs" should appear in containers using "runtime-node.cdx.json"
    And "dotnet" components should appear only in containers using "runtime-dotnet.cdx.json"

  Scenario: No duplicate bom-refs within a single SBOM
    When I examine all container SBOMs
    Then all bom-refs should be unique within each SBOM
    And no SBOM should have duplicate bom-refs
