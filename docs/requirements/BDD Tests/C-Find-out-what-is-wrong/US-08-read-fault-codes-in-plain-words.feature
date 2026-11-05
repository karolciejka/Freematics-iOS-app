# Story: US-08 Read fault codes in plain words (Done)
Feature: Read fault codes in plain words
  As a car owner
  I want to see my car's fault codes with a plain description
  So that I understand why the warning light is on

  Background:
    Given the car owner is connected to their car

  Scenario: Stored and pending codes are shown in separate groups
    Given the car has the following fault codes:
      | Code  | Kind    |
      | P0301 | stored  |
      | P0420 | stored  |
      | P0171 | pending |
    When the car owner opens the Codes screen
    Then P0301 and P0420 are listed under stored codes
    And P0171 is listed under pending codes

  Scenario: A code shows its number and a plain description
    Given the car has the stored code P0301
    When the car owner opens the Codes screen
    Then P0301 is shown with a one-line description in plain words, such as "Cylinder 1 misfire detected"

  Scenario: A code without a known description still shows its number
    Given the car has a stored code the app has no description for
    When the car owner opens the Codes screen
    Then the code number is shown
    And it says "No description available"

  Scenario: No fault codes found
    Given the car has no stored or pending codes
    When the car owner opens the Codes screen
    Then it says "No fault codes found"
    And it shows when it last checked

  Scenario: Codes match a second scanner on most cars
    Given a set of test cars that each have a stored code
    When their codes are read with the app and with a second scanner
    Then the codes match on at least 9 in 10 cars
