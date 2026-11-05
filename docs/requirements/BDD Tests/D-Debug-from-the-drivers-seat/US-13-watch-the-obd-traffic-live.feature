# Story: US-13 Watch the OBD traffic live (Done)
Feature: Watch the OBD traffic live
  As a maker
  I want to see every request the logger sends and every reply the car gives
  So that I can debug my firmware without a laptop

  Background:
    Given the maker is connected to a real car
    And they are on the CAN bus screen

  Scenario: Each line shows time, direction, CAN ID and data
    When the logger asks the car for engine speed
    Then a "sent" line shows the time, CAN ID and data bytes of the request
    And a "received" line shows the time, CAN ID and data bytes of the reply

  Scenario: New lines appear live
    Given the list is running
    When the car answers a new request
    Then the new line appears straight away

  Scenario: Pausing stops the list from moving
    Given the list is running
    When the maker pauses the list
    Then no new lines are added until they resume

  Scenario: Resuming continues the live list
    Given the list is paused
    When the maker resumes the list
    Then new lines appear again as they happen

  Scenario: A note explains what is shown on a real car
    When the CAN bus screen opens
    Then a note explains that only OBD requests and replies are shown, not all bus traffic

  Scenario: The list keeps only the last 500 lines
    Given the list already holds 500 lines
    When a new line arrives
    Then the oldest line is removed
    And the list still holds 500 lines

  Scenario: Shown lines can be shared as plain text
    Given the list shows some lines
    When the maker shares the list
    Then the shown lines are shared as plain text
