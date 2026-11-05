# Story: US-12 Know which car I'm connected to (Done)
Feature: Know which car I'm connected to
  As a car owner
  I want the app to read and decode my car's VIN
  So that I know the data comes from the right car

  Scenario: The VIN is read and decoded after connecting
    Given a car with the following details:
      | VIN        | WVWZZZ1JZ3W386752 |
      | Maker      | Volkswagen        |
      | Model year | 2003              |
    When the car owner connects to the car
    Then the app shows the 17-character VIN "WVWZZZ1JZ3W386752"
    And it shows the maker "Volkswagen" and model year 2003

  Scenario: A car that does not share its VIN
    Given an older car that refuses to give its VIN
    When the car owner connects to the car
    Then the app explains that some older cars don't share their VIN

  Scenario: The VIN can be copied
    Given the car owner is connected and the VIN is shown
    When they long-press the VIN
    Then the VIN is copied
