# Story: US-06 Graph one reading (Done)
Feature: Graph one reading
  As a car owner
  I want to see one reading as a chart over the last few seconds
  So that I can spot spikes and trends

  Background:
    Given the car owner is connected to a car with the engine running
    And the Live screen is showing readings

  Scenario: Tapping a reading opens its graph
    When the car owner taps engine speed
    Then the graph for engine speed opens

  Scenario: The graph shows a scrolling 18-second window
    Given the car owner is viewing the engine speed graph
    When new engine speed values arrive
    Then the graph shows the last 18 seconds
    And it scrolls to include the new values

  Scenario: Min, average and max are shown for the window
    Given the engine speed values in the last 18 seconds were between 800 and 3000 rpm
    When the car owner views the engine speed graph
    Then the minimum, average and maximum for the shown window are displayed under the chart

  Scenario: Missing values leave a gap
    Given the car did not answer for engine speed for 2 seconds
    When the car owner views the engine speed graph
    Then the line has a gap for those 2 seconds
    And it does not drop to zero

  Scenario: History is kept when going back and returning
    Given the car owner has viewed the engine speed graph for 10 seconds
    When they go back to Live and return to the engine speed graph
    Then the history already collected is still shown
