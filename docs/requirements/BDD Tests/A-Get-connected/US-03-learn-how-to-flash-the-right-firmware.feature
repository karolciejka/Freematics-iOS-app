# Story: US-03 Learn how to flash the right firmware (ToDo)
@wip
Feature: Learn how to flash the right firmware
  As a car owner
  I want step-by-step help to put the OBD Live firmware on my ONE+
  So that the app works without me searching forums

  Scenario: The setup link is visible before any logger is found
    Given no logger has been found yet
    When the car owner opens the Connect screen
    Then a "Set up your logger" link is visible

  Scenario: The guide lists what is needed and the steps in order
    Given the car owner is on the Connect screen
    When they open "Set up your logger"
    Then the guide lists what is needed:
      | Item            |
      | ONE+ model      |
      | USB cable       |
      | A computer      |
    And the steps are shown in order with one picture per step

  Scenario: The guide links to the exact firmware build
    Given the car owner is reading the firmware guide
    When they reach the download step
    Then the guide links to the exact firmware build from the "obd-live-ble" branch

  Scenario: The last step explains how to check it worked
    Given the car owner is reading the firmware guide
    When they reach the last step
    Then it tells them the flash worked when the logger shows up on the Connect screen

  Scenario: The guide is available without a connection
    Given the iPhone has no internet connection
    When the car owner opens "Set up your logger"
    Then the guide opens and can be read in full

  Scenario: The guide is short
    Given a car owner who has not flashed a ONE+ before
    When they read the whole guide
    Then they finish reading it in under 5 minutes
