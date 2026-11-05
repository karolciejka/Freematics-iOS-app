# US-02 Stay connected while I drive

**Group:** A. Get connected  
**Status:** Done

**Description:** As a car owner, I want the app to reconnect by itself and tell me what the logger is doing, so that I don't have to start over after a drop.

**Design:** [Live screen, Simple](../../../../screenshots/live-simple.png) (status bar at the top)

## Acceptance criteria

1. When the Bluetooth link drops, the app shows "Reconnecting" and tries again without any tap.
2. When the logger restarts because the car was started, the app reconnects and readings come back within 15 seconds.
3. When the car's computer does not answer, the app shows "No ECU" instead of empty or zero readings.
4. When the logger is in standby, the app shows "Standby" and wakes it on Connect.
5. Every status is shown in words, not only by color, so it works with VoiceOver.
