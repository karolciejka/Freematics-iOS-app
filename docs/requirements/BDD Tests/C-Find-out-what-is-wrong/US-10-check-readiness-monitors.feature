# Story: US-10 Check readiness monitors (Done)
Feature: Check readiness monitors
  As a car owner
  I want to see which emission self-tests are done
  So that I know if my car is ready for an inspection

  Background:
    Given the car owner is connected to their car

  Scenario: Supported monitors are listed with their state
    Given the car reports these monitors:
      | Monitor            | Supported | State        |
      | Catalyst           | yes       | complete     |
      | Oxygen sensor      | yes       | not complete |
      | EGR system         | no        |              |
    When the car owner opens the Codes screen
    Then Catalyst is listed as "Complete"
    And Oxygen sensor is listed as "Not complete"
    And EGR system is not shown

  Scenario: A note explains why monitors may be not complete
    Given at least one monitor is not complete
    When the car owner views the readiness section
    Then a short note explains that "Not complete" is normal right after codes were cleared or the battery was disconnected

  Scenario: Pulling down refreshes the monitors
    Given the Oxygen sensor monitor was shown as "Not complete"
    And it has since completed in the car
    When the car owner pulls down on the Codes screen
    Then Oxygen sensor is listed as "Complete"
