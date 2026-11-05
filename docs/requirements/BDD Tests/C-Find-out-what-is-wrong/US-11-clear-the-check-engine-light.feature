# Story: US-11 Clear the check-engine light (Done)
Feature: Clear the check-engine light
  As a car owner
  I want to clear fault codes after a repair
  So that I can see if the problem comes back

  Background:
    Given the car owner is connected to their car
    And they are on the Codes screen

  Scenario: The Clear button is hidden when there are no codes
    Given the car has no fault codes
    When the Codes screen is shown
    Then there is no Clear button

  Scenario: Clearing asks for confirmation and warns about readiness
    Given the car has the stored code P0301
    When the car owner taps Clear
    Then a confirmation opens
    And it warns that the readiness monitors will reset

  Scenario: Codes are cleared and read again
    Given the car has the stored code P0301
    And the car is stopped
    When the car owner confirms clearing the codes
    Then the app reads the codes again
    And it shows the result

  Scenario: Clearing is blocked while the car is moving
    Given the car has the stored code P0301
    And the car is moving at 40 km/h
    When the car owner tries to clear the codes
    Then the app does not clear them
    And it explains that the car must be stopped

  Scenario: Clearing is allowed when speed is unknown
    Given the car has the stored code P0301
    And the car does not report its speed
    When the car owner confirms clearing the codes
    Then the codes are cleared

  Scenario: The car refuses to clear the codes
    Given the car has the stored code P0301
    And the car is stopped
    And the car will refuse the clear request
    When the car owner confirms clearing the codes
    Then the app says the car refused
    And P0301 stays on screen
