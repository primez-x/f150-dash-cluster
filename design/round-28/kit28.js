// Round 28 kit: shorter cards. Loads after round-27/kit27.js.
//
// User direction (2026-10-30): both cards are too tall; the right card has too much padding at the top and bottom, and the
// left card sits too close to the clock, date, and temperature stack.
// - Cards: 310 px tall (was 364), y 262 to 572. The card top moves 26 px down: 42 px clear of the stack (was 16 px).
//   The bottom moves 28 px up.
// - Temperature bars: 160 px (was 190), so the four columns fit the shorter card.
// - The speed group keeps the card lines: the bar on the card top line, the row of cruise, gear, and drive mode on the card
//   bottom line. kit28.css moves the digits, MPH, and the row; the bar follows CARD.top (kit26.js).
Object.assign(CARD, { top: 262, h: 310, bar: 160 });
