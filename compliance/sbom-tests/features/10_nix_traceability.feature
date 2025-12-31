@fast
Feature: Nix Traceability
  As a security analyst
  I want ecosystem packages to have Nix build provenance
  So that I can trace vulnerabilities back to their build source

  Background:
    Given the SBOM directory "compliance/sboms" exists

  Scenario Outline: Ecosystem packages should have Nix traceability
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    When I find all "<ecosystem>" packages
    Then each package should have a "nix:purl" property
    And each package should have a "nix:drv" property
    And each package should have an externalReference of type "build-system"

    Examples:
      | service           | ecosystem  |
      | fee-service       | pkg:pypi/  |
      | smoke-tests       | pkg:gem/   |
      | sanctions-service | pkg:maven/ |
      | api-gateway       | pkg:golang/|
      | kyc-service       | pkg:nuget/ |
      | web-portal        | pkg:npm/   |
      | crypto-transfer   | pkg:cargo/ |

  Scenario Outline: No duplicate Nix components for mapped packages
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    When I find all "<ecosystem>" packages with "nix:purl" property
    Then there should be no component with that "nix:purl" as its primary purl

    Examples:
      | service           | ecosystem  |
      | fee-service       | pkg:pypi/  |
      | smoke-tests       | pkg:gem/   |
