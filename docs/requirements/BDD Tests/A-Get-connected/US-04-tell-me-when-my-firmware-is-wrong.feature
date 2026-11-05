# Story: US-04 Tell me when my firmware is wrong (ToDo)
@wip
Feature: Tell me when my firmware is wrong
  As a car owner
  I want a clear message when my logger runs the wrong or an old firmware
  So that I know how to fix it instead of staring at empty readings

  Background:
    Given the car owner is on the Connect screen
    And a ONE+ is listed

  Scenario: A logger with the right firmware passes the check quickly
    Given the logger runs the OBD Live firmware it needs
    And it answers the "PIDS" and "RAW" commands
    When the car owner connects to the logger
    Then the firmware check finishes within 3 seconds
    And the Live screen opens

  Scenario: A logger without the OBD Live firmware is explained
    Given the logger runs stock firmware that does not answer "PIDS" and "RAW"
    When the car owner connects to the logger
    Then the app shows "This logger needs the OBD Live firmware"
    And the Live screen is not opened
    And the message links to the firmware guide

  Scenario: An outdated firmware names the versions found and needed
    Given the logger runs OBD Live firmware older than the app needs
    When the car owner connects to the logger
    Then the message names the firmware version found
    And it names the firmware version needed
    And it links to the firmware guide
