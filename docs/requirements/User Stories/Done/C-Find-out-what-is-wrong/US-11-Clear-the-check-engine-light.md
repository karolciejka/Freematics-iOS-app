# US-11 Clear the check-engine light

**Group:** C. Find out what is wrong  
**Status:** Done

**Description:** As a car owner, I want to clear fault codes after a repair, so that I can see if the problem comes back.

**Design:** [Codes screen](../../../../screenshots/codes-simple.png) (Clear button)

## Acceptance criteria

1. The Clear button is shown only when there is at least one code.
2. Tapping it opens a confirmation that warns the readiness monitors will reset.
3. Clearing is only allowed when the car is stopped (speed is 0 or unknown).
4. After clearing, the app reads the codes again and shows the result.
5. If the car refuses, the app says so and keeps the codes on screen.
