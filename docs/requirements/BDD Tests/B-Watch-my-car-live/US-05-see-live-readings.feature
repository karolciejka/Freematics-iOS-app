# Story: US-05 See live readings (Done)
Feature: See live readings
  As a car owner
  I want to see my engine's key numbers update live
  So that I know what the car is doing right now

  Background:
    Given the car owner is connected to a car with the engine running

  Scenario: The Live screen shows the key engine readings
    Given the car supports all the key readings
    When the Live screen opens
    Then it shows these readings:
      | Reading            |
      | Engine speed       |
      | Speed              |
      | Engine load        |
      | Throttle           |
      | Coolant temperature|
      | Intake temperature |
      | Battery voltage    |
      | Timing advance     |
      | Fuel rate          |

  Scenario: The app asks only for supported readings
    Given the car says it does not support fuel rate
    When the Live screen starts updating
    Then the app never asks the car for fuel rate

  Scenario: An unsupported reading shows a dash, never zero
    Given the car says it does not support fuel rate
    When the Live screen opens
    Then fuel rate shows "—"
    And fuel rate is never shown as 0

  Scenario: Values refresh at least twice a second
    Given the car accepts combined requests
    When the Live screen is showing readings
    Then each value refreshes at least twice a second

  Scenario Outline: Units follow the phone's region
    Given the phone's region uses <system> units
    When the Live screen opens
    Then speed is shown in <speed unit>
    And temperatures are shown in <temperature unit>

    Examples:
      | system   | speed unit | temperature unit |
      | metric   | km/h       | °C               |
      | imperial | mph        | °F               |
