# US-05 See live readings

**Group:** B. Watch my car live  
**Status:** Done

**Description:** As a car owner, I want to see my engine's key numbers update live, so that I know what the car is doing right now.

**Design:** [Live screen, Simple](../../../../screenshots/live-simple.png) · [Racing](../../../../screenshots/live-racing.png)

## Acceptance criteria

1. The Live screen shows engine speed, speed, load, throttle, coolant and intake temperature, battery voltage, timing and fuel rate.
2. The app asks only for readings the car says it supports.
3. A reading the car does not support shows "—", never 0.
4. Values refresh at least twice a second on a car that accepts combined requests.
5. Each value shows its unit, and temperatures and speed follow the phone's region (°C or °F, km/h or mph).
