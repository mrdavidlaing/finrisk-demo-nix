@fast
Feature: Dependency Graph Completeness
  As a security analyst
  I want SBOMs to contain complete dependency graph information
  So that Dependency Track can build accurate vulnerability paths and impact analysis

  Background:
    Given the SBOM directory "compliance/sboms" exists

  Scenario Outline: Container SBOM structure and completeness
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    Then the dependencies should contain an entry for "container:<service>"
    And the dependency "container:<service>" should depend on exactly 3 components
    When I get the dependencies for "container:<service>"
    And it should depend on a component matching "base.cdx.json"
    And it should depend on a component matching "<runtime_layer>.cdx.json"
    And it should depend on a component matching "app-<service>.cdx.json"
    When I collect all dependency refs
    Then every ref should match a component bom-ref
    And all bom-refs in dependsOn arrays should reference existing components
    And the dependency graph should not contain cycles

    Examples:
      | service           | runtime_layer      |
      | web-portal        | runtime-node       |
      | api-gateway       | runtime-native     |
      | audit-service     | runtime-perl       |
      | crypto-transfer   | runtime-native     |
      | fee-service       | runtime-python     |
      | kyc-service       | runtime-dotnet     |
      | sanctions-service | runtime-java       |
      | smoke-tests       | runtime-ruby       |
      | swift-gateway     | runtime-native     |

  Scenario Outline: Application Package Presence
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    Then the components should include at least <min_count> packages of type "<type_prefix>"
    And the components should include a package with purl starting with "<type_prefix>"

    Examples:
      | service           | type_prefix | min_count |
      | web-portal        | pkg:npm/    | 10        |
      | api-gateway       | pkg:golang/ | 2         |
      | crypto-transfer   | pkg:cargo/  | 2         |
      | fee-service       | pkg:pypi/   | 2         |
      | sanctions-service | pkg:maven/  | 2         |
      | smoke-tests       | pkg:gem/    | 2         |
      | audit-service     | pkg:nix/    | 5         |
      | kyc-service       | pkg:nix/    | 5         |
      | swift-gateway     | pkg:nix/    | 2         |

  Scenario Outline: Package Manager Dependency Graph
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    When I find a package component of type "<type_prefix>"
    Then its bom-ref should have a corresponding dependency entry
    And that dependency entry should have at least 0 dependsOn entries

    Examples:
      | service           | type_prefix |
      | web-portal        | pkg:npm/    |
      | api-gateway       | pkg:golang/ |
      | crypto-transfer   | pkg:cargo/  |
      | fee-service       | pkg:pypi/   |
      | sanctions-service | pkg:maven/  |
      | smoke-tests       | pkg:gem/    |
      | audit-service     | pkg:nix/    |
      | kyc-service       | pkg:nix/    |
      | swift-gateway     | pkg:nix/    |

  @enforce_fix
  Scenario Outline: Application packages are reachable from container entry
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    When I find a package component of type "<type_prefix>"
    And I build dependency graph
    Then there should be a path from "container:<service>" to that package
    And the path should have at least 2 levels

    Examples:
      | service           | type_prefix |
      | web-portal        | pkg:npm/    |
      | api-gateway       | pkg:golang/ |
      | crypto-transfer   | pkg:cargo/  |
      | fee-service       | pkg:pypi/   |
      | sanctions-service | pkg:maven/  |
      | smoke-tests       | pkg:gem/    |
      | audit-service     | pkg:nix/    |
      | kyc-service       | pkg:nix/    |
      | swift-gateway     | pkg:nix/    |

  Scenario Outline: Dependency graph has minimum depth
    Given I load the SBOM file "compliance/sboms/container-<service>.cdx.json"
    When I calculate the longest dependency path from "container:<service>"
    Then the path depth should be at least 4

    Examples:
      | service           |
      | web-portal        |
      | api-gateway       |
      | audit-service     |
      | crypto-transfer   |
      | fee-service       |
      | kyc-service       |
      | sanctions-service |
      | smoke-tests       |
      | swift-gateway     |
