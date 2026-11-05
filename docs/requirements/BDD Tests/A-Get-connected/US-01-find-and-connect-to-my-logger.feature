# Story: US-01 Find and connect to my logger (Done)
Feature: Find and connect to my logger
  As a car owner
  I want to find my ONE+ and connect with one tap
  So that I see my car's data without any cables

  Background:
    Given the car owner has a ONE+ plugged into their car

  Scenario: Nearby loggers are listed with name and signal strength
    Given the following loggers are nearby:
      | Name         | Offers Freematics service | Signal |
      | ONE+ Garage  | yes                       | strong |
      | ONE+ Spare   | yes                       | weak   |
      | Other gadget | no                        | strong |
    And Bluetooth is on and allowed for the app
    When the app scans for loggers
    Then "ONE+ Garage" and "ONE+ Spare" are listed with their signal strength
    And "Other gadget" is not listed

  Scenario: Connecting to a logger opens the Live screen
    Given the ONE+ runs the OBD Live firmware and is listed on the Connect screen
    And the car's ignition is on
    When the car owner taps the logger
    Then the app connects to it
    And the Live screen opens within 10 seconds

  Scenario: No logger is found after a scan
    Given Bluetooth is on and allowed for the app
    And the ONE+ has no power, so it is not advertising
    When the app finishes scanning
    Then the screen tells the owner to check that the ONE+ has power and the right firmware

  Scenario: The last logger is offered first next time
    Given the car owner connected to "ONE+ Garage" last time
    And "ONE+ Garage" and "ONE+ Spare" are both nearby
    When the car owner opens the Connect screen again
    Then "ONE+ Garage" is offered first

  Scenario: Bluetooth is turned off
    Given Bluetooth is off on the iPhone
    When the car owner opens the Connect screen
    Then the app says Bluetooth is off
    And it offers a link to iPhone Settings

  Scenario: Bluetooth permission is not granted
    Given the app is not allowed to use Bluetooth
    When the car owner opens the Connect screen
    Then the app says it needs Bluetooth permission
    And it offers a link to iPhone Settings
