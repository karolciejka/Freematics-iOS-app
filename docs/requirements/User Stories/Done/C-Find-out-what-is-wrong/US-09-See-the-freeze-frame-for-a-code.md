# US-09 See the freeze frame for a code

**Group:** C. Find out what is wrong  
**Status:** Done

**Description:** As a car owner, I want to see what the engine was doing when a fault was stored, so that I can judge what caused it.

**Design:** [Codes screen with freeze frame](../../../../screenshots/codes-simple.png)

## Acceptance criteria

1. When the car has a freeze frame, the Codes screen shows it next to the code that caused it.
2. The freeze frame lists each saved reading with its value and unit.
3. When the car has no freeze frame, the section is hidden, not empty.
4. Readings the car did not save are left out instead of shown as 0.
