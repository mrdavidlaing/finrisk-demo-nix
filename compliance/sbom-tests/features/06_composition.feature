@fast
Feature: SBOM Composition Integrity
  As a supply chain security officer
  I want container SBOMs to properly declare their composition from layer SBOMs
  So that I can understand the complete software supply chain

  Background:
    Given the SBOM directory "compliance/sboms" exists

  Scenario: All container SBOMs have compositions
    When I examine all files matching "compliance/sboms/container-*.cdx.json"
    Then each SBOM should have a compositions section

  Scenario Outline: Container compositions declare complete aggregation
    Given I load the SBOM file "compliance/sboms/<container_sbom>"
    Then the compositions should include aggregate "complete"

    Examples:
      | container_sbom                    |
      | container-api-gateway.cdx.json    |
      | container-kyc-service.cdx.json    |
      | container-fee-service.cdx.json    |
      | container-web-portal.cdx.json     |

  @enforce_fix
  Scenario Outline: Compositions should reference SBOM files not Nix paths
    Given I load the SBOM file "compliance/sboms/<container_sbom>"
    Then the compositions should reference exactly 3 assemblies
    And the assemblies should include "base.cdx.json"
    And the assemblies should include "<runtime_sbom>"
    And the assemblies should include "<app_sbom>"

    Examples:
      | container_sbom                    | runtime_sbom           | app_sbom                 |
      | container-api-gateway.cdx.json    | runtime-native.cdx.json| app-api-gateway.cdx.json |
      | container-kyc-service.cdx.json    | runtime-dotnet.cdx.json| app-kyc-service.cdx.json |
      | container-fee-service.cdx.json    | runtime-python.cdx.json| app-fee-service.cdx.json |
      | container-web-portal.cdx.json     | runtime-node.cdx.json  | app-web-portal.cdx.json  |

  @enforce_fix
  Scenario: Composition assemblies should reference SBOM files
    Given I load the SBOM file "compliance/sboms/container-api-gateway.cdx.json"
    When I extract all assembly refs from compositions
    Then all assembly refs should end with ".cdx.json"
    And each referenced SBOM file should exist in "compliance/sboms"

  Scenario: Composition metadata should be consistent
    Given I load the SBOM file "compliance/sboms/container-web-portal.cdx.json"
    Then the compositions should have at least 1 entry
    And each composition should have assemblies array

  @enforce_fix
  Scenario: Compositions should have bom-ref for traceability
    Given I load the SBOM file "compliance/sboms/container-web-portal.cdx.json"
    Then each composition should have a bom-ref
