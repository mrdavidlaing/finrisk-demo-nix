@fast
Feature: Component Provenance Tracking
  As a security analyst
  I want to trace each component back to its layer (base/runtime/app)
  So that I can understand the supply chain and prioritize vulnerability remediation

  Background:
    Given the SBOM directory "compliance/sboms" exists

  Scenario Outline: Container SBOMs reference their layer SBOMs
    Given I load the SBOM file "compliance/sboms/<container_sbom>"
    Then the metadata should contain externalReferences to:
      | base.cdx.json          |
      | <runtime_sbom>         |
      | <app_sbom>             |

    Examples:
      | container_sbom                    | runtime_sbom           | app_sbom                 |
      | container-api-gateway.cdx.json    | runtime-native.cdx.json| app-api-gateway.cdx.json |
      | container-kyc-service.cdx.json    | runtime-dotnet.cdx.json| app-kyc-service.cdx.json |
      | container-fee-service.cdx.json    | runtime-python.cdx.json| app-fee-service.cdx.json |
      | container-web-portal.cdx.json     | runtime-node.cdx.json  | app-web-portal.cdx.json  |

  @current_state
  Scenario: Container SBOMs have compositions section
    Given I load the SBOM file "compliance/sboms/container-api-gateway.cdx.json"
    Then the SBOM should have a compositions section
    And the compositions should include aggregate "complete"

  @current_state
  Scenario: Compositions reference layer SBOMs
    Given I load the SBOM file "compliance/sboms/container-web-portal.cdx.json"
    Then the compositions should reference:
      | base.cdx.json                 |
      | runtime-node.cdx.json         |
      | app-web-portal.cdx.json       |

  @enforce_fix
  Scenario: Base components should have provenance tags
    Given I load the SBOM file "compliance/sboms/container-api-gateway.cdx.json"
    When I find the component "glibc"
    Then the component should have property "layer" with value "base"

  @enforce_fix
  Scenario: Runtime components should have provenance tags
    Given I load the SBOM file "compliance/sboms/runtime-node.cdx.json"
    When I find the component "nodejs"
    Then the component should have property "layer" with value "runtime"

  @enforce_fix
  Scenario: App components should have provenance tags
    Given I load the SBOM file "compliance/sboms/container-api-gateway.cdx.json"
    When I find the component "api-gateway"
    Then the component should have property "layer" with value "app"
