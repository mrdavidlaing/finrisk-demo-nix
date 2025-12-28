@fast
Feature: SBOM Structure and Format
  As a compliance officer
  I want all SBOMs to follow the CycloneDX 1.6 specification
  So that they can be consumed by standard SBOM tooling

  Background:
    Given the SBOM directory "compliance/sboms" exists

  Scenario: All required SBOM files are generated
    Then the following SBOM files should exist:
      | sbom_type  | file_pattern          |
      | base       | base.cdx.json         |
      | runtime    | runtime-*.cdx.json    |
      | app        | app-*.cdx.json        |
      | container  | container-*.cdx.json  |

  Scenario Outline: Container SBOMs have correct metadata
    Given I load the SBOM file "compliance/sboms/<container_sbom>"
    Then the SBOM should have bomFormat "CycloneDX"
    And the SBOM should have specVersion "1.6"
    And the SBOM should have a valid serialNumber
    And the metadata component type should be "container"
    And the metadata component name should match "<image_name>"

    Examples:
      | container_sbom                  | image_name              |
      | container-api-gateway.cdx.json  | transferx/api-gateway   |
      | container-fee-service.cdx.json  | transferx/fee-service   |
      | container-kyc-service.cdx.json  | transferx/kyc-service   |

  Scenario Outline: Container SBOMs reference their constituent SBOMs
    Given I load the SBOM file "compliance/sboms/<container_sbom>"
    Then the metadata should contain externalReferences to:
      | base.cdx.json        |
      | <runtime_sbom>       |
      | <app_sbom>           |

    Examples:
      | container_sbom                  | runtime_sbom            | app_sbom                |
      | container-api-gateway.cdx.json  | runtime-native.cdx.json | app-api-gateway.cdx.json|
      | container-fee-service.cdx.json  | runtime-python.cdx.json | app-fee-service.cdx.json|
      | container-kyc-service.cdx.json  | runtime-dotnet.cdx.json | app-kyc-service.cdx.json|

  Scenario: Base SBOM contains expected system components
    Given I load the SBOM file "compliance/sboms/base.cdx.json"
    Then the components should include:
      | name       | type    |
      | glibc      | library |
      | bash       | library |
      | coreutils  | library |
      | tzdata     | library |
