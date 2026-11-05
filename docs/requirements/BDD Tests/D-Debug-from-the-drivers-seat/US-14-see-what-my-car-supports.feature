# Story: US-14 See what my car supports (Done)
Feature: See what my car supports
  As a maker
  I want a setup log of what the car told the app
  So that I know which readings and request types it supports

  Scenario: The setup log shows what the car reported
    Given a car with the following setup:
      | VIN                       | WVWZZZ1JZ3W386752                     |
      | Supported readings        | 0C Engine speed, 0D Speed, 05 Coolant |
      | Accepts combined requests | yes                                   |
    When the maker connects to the car
    Then the setup log shows the VIN
    And it lists the supported readings by PID number and name
    And it says the car accepts combined requests

  Scenario: The setup log is refreshed on each connect
    Given the maker connected to one car earlier
    When they connect to a different car
    Then the setup log shows the details of the new car

  Scenario: The setup log can be copied for a bug report
    Given the setup log is filled in
    When the maker copies the setup log
    Then it is copied as plain text
