Feature: Service Health
  As a platform operator
  I want all services to be healthy
  So that transfers can be processed reliably

  Scenario: All services respond to health checks
    Then the api-gateway should be healthy
    And the kyc-service should be healthy
    And the fee-service should be healthy
    And the sanctions-service should be healthy
    And the crypto-transfer service should be healthy
    And the audit-service should be healthy

