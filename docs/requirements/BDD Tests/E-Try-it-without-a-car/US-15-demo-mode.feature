# Story: US-15 Demo mode (Done)
Feature: Demo mode
  As a new user
  I want to try the app with made-up car data
  So that I can see what it does before I set up my logger

  Scenario: Demo starts without Bluetooth or a logger
    Given Bluetooth is off
    And no logger is nearby
    When the new user taps "Try demo" on the Connect screen
    Then the Live screen opens with made-up readings

  Scenario Outline: Every screen works in demo mode
    Given the app is in demo mode
    When the new user opens the <screen>
    Then it shows <content> from demo data
    And a "Demo" label is shown

    Examples:
      | screen          | content          |
      | Live screen     | live readings    |
      | Graph screen    | a moving graph   |
      | Codes screen    | fault codes      |
      | Codes screen    | a freeze frame   |
      | Codes screen    | readiness monitors |
      | CAN bus screen  | bus traffic      |

  Scenario: Clearing codes works in demo mode
    Given the app is in demo mode
    And the demo car has fault codes
    When the new user confirms clearing the codes
    Then the codes are cleared
    And the result is shown

  Scenario: Leaving demo mode returns to Connect
    Given the app is in demo mode
    When the new user leaves demo mode
    Then the Connect screen is shown
