# US-04 Tell me when my firmware is wrong

**Group:** A. Get connected  
**Status:** ToDo

**Description:** As a car owner, I want a clear message when my logger runs the wrong or an old firmware, so that I know how to fix it instead of staring at empty readings.

**Design:** None yet. Shown on the Connect screen after a failed connect.

## Acceptance criteria

1. After connecting, the app checks that the logger answers the `PIDS` and `RAW` commands.
2. If it does not, the app shows "This logger needs the OBD Live firmware" and does not open an empty Live screen.
3. The message links to the firmware guide from [US-03](US-03-Learn-how-to-flash-the-right-firmware.md).
4. If the firmware is older than the app needs, the message names the version found and the version needed.
5. The check takes no more than 3 seconds, so a correct logger is not slowed down.
