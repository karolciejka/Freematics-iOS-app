# US-08 Read fault codes in plain words

**Group:** C. Find out what is wrong  
**Status:** Done

**Description:** As a car owner, I want to see my car's fault codes with a plain description, so that I understand why the warning light is on.

**Design:** [Codes screen, Simple](../../../../screenshots/codes-simple.png) · [Racing](../../../../screenshots/codes-racing.png)

## Acceptance criteria

1. The Codes screen lists stored and pending codes in two separate groups.
2. Each code shows its number (for example P0301) and a one-line description in plain words.
3. A code with no known description still shows its number and "No description available".
4. With no codes, the screen says "No fault codes found" and when it last checked.
5. Codes match a second scanner on at least 9 in 10 test cars that have a stored code.
