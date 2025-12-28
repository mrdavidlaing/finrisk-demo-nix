@fast
Feature: PURL Validation
  As a security analyst
  I want all components to have valid Package URLs (PURLs)
  So that I can accurately track packages across ecosystems

  Background:
    Given the SBOM directory "compliance/sboms" exists
    And I load all container SBOMs

  Scenario: All components should have PURLs
    When I examine all container SBOMs
    Then all components with type "library" should have a PURL
    And all components with type "application" should have a PURL

  Scenario Outline: PURLs should follow correct format for each ecosystem
    When I find all components with PURL type "<purl_type>"
    Then all PURLs should match the pattern "<expected_pattern>"

    Examples:
      | purl_type | expected_pattern                      |
      | nix       | ^pkg:nix/[^@]+@[^@]+$                |
      | npm       | ^pkg:npm/[^@]+@[^@]+$                |
      | pypi      | ^pkg:pypi/[^@]+@[^@]+$               |
      | maven     | ^pkg:maven/[^/]+/[^@]+@[^@]+$        |
      | nuget     | ^pkg:nuget/[^@]+@[^@]+$              |
      | cargo     | ^pkg:cargo/[^@]+@[^@]+$              |
      | gem       | ^pkg:gem/[^@]+@[^@]+$                |

  Scenario: Nix packages should have well-formed PURLs
    When I find all components with PURL type "nix"
    Then all PURLs should have a name
    And all PURLs should have a version
