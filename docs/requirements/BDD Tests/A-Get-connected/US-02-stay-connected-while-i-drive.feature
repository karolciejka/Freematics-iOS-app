# Story: US-02 Stay connected while I drive (Done)
Feature: Stay connected while I drive
  As a car owner
  I want the app to reconnect by itself and tell me what the logger is doing
  So that I don't have to start over after a drop

  Background:
    Given the car owner is connected to their ONE+
    And the Live screen is showing readings

  Scenario: The app reconnects by itself after a Bluetooth drop
    When the Bluetooth link drops
    Then the status shows "Reconnecting"
    And the app tries to connect again without any tap

  Scenario: Readings return after the logger restarts on engine start
    Given the logger restarts because the car was started
    When the logger becomes reachable again
    Then the app reconnects on its own
    And readings come back within 15 seconds

  Scenario: The car's computer does not answer
    When the car's computer stops answering the logger
    Then the status shows "No ECU"
    And the readings are not shown as empty or zero

  Scenario: The logger is in standby
    Given the logger has gone into standby
    When the car owner taps Connect
    Then the status shows "Standby" until the logger wakes
    And the app wakes the logger

  Scenario: Every status is readable by VoiceOver
    Given VoiceOver is on
    When the connection status changes
    Then the status is announced in words, not only shown by color
