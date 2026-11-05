# US-13 Watch the OBD traffic live

**Group:** D. Debug from the driver's seat  
**Status:** Done

**Description:** As a maker, I want to see every request the logger sends and every reply the car gives, so that I can debug my firmware without a laptop.

**Design:** [CAN bus screen, Simple](../../../../screenshots/can-simple.png) · [Racing](../../../../screenshots/can-racing.png)

## Acceptance criteria

1. Each line shows the time, direction (sent or received), CAN ID and data bytes.
2. New lines appear as they happen, and the user can pause and resume the list.
3. A note explains that on a real car only OBD requests and replies are shown, not all bus traffic.
4. The list keeps the last 500 lines so the phone stays fast.
5. The user can copy or share the shown lines as plain text.
