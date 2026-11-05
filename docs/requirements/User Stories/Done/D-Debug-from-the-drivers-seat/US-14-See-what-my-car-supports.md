# US-14 See what my car supports

**Group:** D. Debug from the driver's seat  
**Status:** Done

**Description:** As a maker, I want a setup log of what the car told the app, so that I know which readings and request types it supports.

**Design:** [CAN bus screen](../../../../screenshots/can-simple.png) (setup log)

## Acceptance criteria

1. The setup log shows the VIN, the list of supported readings and whether the car accepts combined requests.
2. It is filled in each time the app connects to a car.
3. Readings are listed by PID number and name.
4. The log can be copied as plain text to attach to a bug report.
