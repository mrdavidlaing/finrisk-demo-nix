@fast
Feature: SBOM Quality Gates
  As a security governance lead
  I want SBOMs to contain only legitimate software components
  So that vulnerability analysis is accurate and actionable

  Background:
    Given the SBOM directory "compliance/sboms" exists

  @enforce_fix
  Scenario: SBOMs should not contain GitHub workflow files
    When I examine all files matching "compliance/sboms/container-*.cdx.json"
    Then no component names should match pattern "\.github/workflows/"

  @enforce_fix
  Scenario: SBOMs should not contain CI configuration files
    When I examine all files matching "compliance/sboms/container-*.cdx.json"
    Then no component names should match pattern "^\.(gitlab-ci|travis|circleci)"

  Scenario: All components should be of valid types
    When I examine all files matching "compliance/sboms/container-*.cdx.json"
    Then all component types should be one of:
      | library     |
      | application |
      | framework   |
      | container   |
      | file        |

  Scenario: Components should have required fields
    When I examine all files matching "compliance/sboms/container-*.cdx.json"
    Then all components should have a "name" field
    And all components should have a "type" field

  Scenario Outline: Layer SBOMs should have appropriate component counts
    Given I load the SBOM file "compliance/sboms/<sbom_file>"
    When I count all components
    Then the count should be greater than or equal to <min_components>

    Examples:
      | sbom_file              | min_components |
      | base.cdx.json          | 5              |
      | runtime-node.cdx.json  | 5              |
      | runtime-python.cdx.json| 5              |
      | runtime-native.cdx.json| 0              |
      | runtime-dotnet.cdx.json| 5              |

  @enforce_fix
  Scenario: Application components should not be in base layer
    When I examine all files matching "compliance/sboms/base.cdx.json"
    Then no component names should match pattern "express|flask|spring-boot|dotnet"

  Scenario: Container SBOMs should have reasonable component counts
    Given I load the SBOM file "compliance/sboms/container-web-portal.cdx.json"
    When I count all components
    Then the count should be greater than 10
