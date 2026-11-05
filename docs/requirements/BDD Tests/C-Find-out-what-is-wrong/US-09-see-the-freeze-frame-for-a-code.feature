# Story: US-09 See the freeze frame for a code (Done)
Feature: See the freeze frame for a code
  As a car owner
  I want to see what the engine was doing when a fault was stored
  So that I can judge what caused it

  Background:
    Given the car owner is connected to their car
    And the car has the stored code P0301

  Scenario: The freeze frame is shown next to its code
    Given the car saved a freeze frame for P0301 with these readings:
      | Reading             | Value | Unit |
      | Engine speed        | 2450  | rpm  |
      | Coolant temperature | 92    | °C   |
      | Engine load         | 63    | %    |
    When the car owner opens the Codes screen
    Then the freeze frame is shown next to P0301
    And each saved reading is listed with its value and unit

  Scenario: Readings the car did not save are left out
    Given the freeze frame for P0301 has no saved speed
    When the car owner opens the Codes screen
    Then speed is not listed in the freeze frame
    And no reading is shown as 0 just because it is missing

  Scenario: No freeze frame hides the section
    Given the car has no freeze frame
    When the car owner opens the Codes screen
    Then the freeze frame section is hidden, not shown empty
