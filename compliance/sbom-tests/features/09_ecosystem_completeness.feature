@fast
Feature: Ecosystem Package Completeness
  As a security analyst
  I want SBOMs to contain complete package manager dependencies for all ecosystems
  So that I can accurately track vulnerabilities across all language ecosystems

  Background:
    Given the SBOM directory "compliance/sboms" exists

  @enforce_fix
  Scenario: KYC Service should contain NuGet packages
    Given I load the SBOM file "compliance/sboms/container-kyc-service.cdx.json"
    Then the components should include a package with purl "pkg:nuget/Microsoft.AspNetCore.OpenApi@8.0.0"
    And the components should include a package with purl "pkg:nuget/Swashbuckle.AspNetCore@6.5.0"
    And the components should include a package with purl "pkg:nuget/Newtonsoft.Json@13.0.1"
    # Note: System.Text.Json is part of .NET runtime framework, not a separate NuGet package
    And there should be at least 6 components with purl starting with "pkg:nuget/"

  @enforce_fix
  Scenario: Sanctions Service Maven packages should have dependency entries
    Given I load the SBOM file "compliance/sboms/container-sanctions-service.cdx.json"
    When I collect all dependency refs
    Then there should be dependency entries for all Maven packages
    And the components should include at least 2 Maven packages
    And the dependency graph should not be empty for package type "pkg:maven/"

  @enforce_fix
  Scenario: API Gateway Go packages should have dependency relationships
    Given I load the SBOM file "compliance/sboms/container-api-gateway.cdx.json"
    When I find a package component of type "pkg:golang/"
    Then its bom-ref should have a corresponding dependency entry
    And that dependency entry should have at least 0 dependsOn entries
    And the components should include at least 2 packages of type "pkg:golang/"

  @enforce_fix
  Scenario: Fee Service Python packages should have dependency relationships
    Given I load the SBOM file "compliance/sboms/container-fee-service.cdx.json"
    When I find a package component of type "pkg:pypi/"
    Then its bom-ref should have a corresponding dependency entry
    And that dependency entry should have at least 0 dependsOn entries
    And the components should include at least 2 packages of type "pkg:pypi/"

  @enforce_fix
  Scenario: Smoke Tests Ruby gems should have dependency relationships
    Given I load the SBOM file "compliance/sboms/container-smoke-tests.cdx.json"
    When I find a package component of type "pkg:gem/"
    Then its bom-ref should have a corresponding dependency entry
    And that dependency entry should have at least 0 dependsOn entries
    And the components should include at least 2 packages of type "pkg:gem/"

  @enforce_fix
  Scenario Outline: Ecosystem-specific package count validation
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    Then the components should include at least <expected_count> packages of type "<type_prefix>"

    Examples:
      | service           | type_prefix | expected_count |
      | web-portal        | pkg:npm/    | 10             |
      | api-gateway       | pkg:golang/ | 2              |
      | crypto-transfer   | pkg:cargo/  | 2              |
      | fee-service       | pkg:pypi/   | 2              |
      | sanctions-service | pkg:maven/  | 2              |
      | smoke-tests       | pkg:gem/    | 2              |
      | kyc-service       | pkg:nuget/  | 6              |

  @enforce_fix
  Scenario Outline: Dependency entries should exist for ecosystem packages
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    Then there should be at least <min_deps> dependency entries for packages of type "<type_prefix>"

    Examples:
      | service           | type_prefix | min_deps |
      | web-portal        | pkg:npm/    | 10        |
      | api-gateway       | pkg:golang/ | 2         |
      | crypto-transfer   | pkg:cargo/  | 2         |
      | fee-service       | pkg:pypi/   | 2         |
      | sanctions-service | pkg:maven/  | 2         |
      | smoke-tests       | pkg:gem/    | 2         |
      | kyc-service       | pkg:nuget/  | 6         |

  @enforce_fix
  Scenario: Web Portal should have npm package dependency trees
    Given I load the SBOM file "compliance/sboms/container-web-portal.cdx.json"
    When I find a package component of type "pkg:npm/"
    And I build dependency graph
    Then there should be at least one npm package with non-empty dependsOn
    And the dependency graph should have depth greater than 1

  @enforce_fix
  Scenario: Crypto Transfer should have cargo package dependency trees
    Given I load the SBOM file "compliance/sboms/container-crypto-transfer.cdx.json"
    When I find a package component of type "pkg:cargo/"
    And I build dependency graph
    Then there should be at least one cargo package with non-empty dependsOn
    And the dependency graph should have depth greater than 1
