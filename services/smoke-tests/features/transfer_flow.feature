Feature: Money Transfer
  As a TransferX user
  I want to transfer funds between accounts
  So that I can send money domestically and internationally

  Background:
    Given the API gateway is available

  Scenario: Successful SWIFT transfer
    Given a verified user "alice"
    And a recipient "bob" not on any sanctions list
    When I submit a SWIFT transfer of $1000 USD from "alice" to "bob"
    Then the transfer should be accepted
    And the response should include a transfer ID
    And the fee should be at least $30
    And the transaction should be logged in the audit service

  Scenario: Successful CRYPTO transfer
    Given a verified user "alice"
    And a recipient "charlie" not on any sanctions list
    When I submit a CRYPTO transfer of $500 USDT from "alice" to "charlie"
    Then the transfer should be accepted
    And the response should include a transaction hash

  Scenario: Transfer blocked by sanctions screening
    Given a verified user "alice"
    And a recipient "BADACTOR001" on the OFAC sanctions list
    When I submit a SWIFT transfer of $500 USD from "alice" to "BADACTOR001"
    Then the transfer should be rejected with "Sanctions screening failed"

  Scenario: Transfer rejected for unverified user
    Given an unverified user with empty ID
    When I submit a SWIFT transfer of $100 USD to "bob"
    Then the transfer should be rejected with "KYC verification failed"


