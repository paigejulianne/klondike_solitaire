# Klondike Solitaire

A Klondike (classic) Solitaire game built with **Flutter**, targeting the **Web**
(Chrome, Edge, Firefox, Safari).

## How to play

- **Goal:** move all 52 cards onto the four foundation piles (top-right), each built
  up from Ace to King in a single suit.
- **Tableau (the 7 columns):** build down in alternating colors (e.g. a red 6 on a
  black 7). A face-down card flips up automatically once it becomes the bottom of a
  stack.
- **Stock/waste (top-left):** tap the stock to deal cards to the waste. When the
  stock is empty, tap it again to recycle the waste. Switch between **Draw 1** and
  **Draw 3** from the ⚙ (tune) menu in the app bar.
- **Only a King** may be moved onto an empty tableau column.

### Three ways to move cards
1. **Drag & drop** — press a card (or a valid run of cards) and drag it onto the
   destination pile. The moment you pick a card up, *every* legal destination
   gets a soft green glow; the pile actually under the pointer gets a bright
   ring and lifts, so you can see exactly which card you'd land on.
2. **Tap to place** — tap a card to pick it up (it lifts and gets an amber
   border, and legal destinations glow), then tap the destination pile to drop
   it. Tap the card again to cancel.
3. **Double-click** — double-click any exposed card to send it straight to a
   foundation if it fits.

### Solve, Hint and the rest

- **Solve** (✨, or `S`) plays the game forward for you, one visible card at a
  time. While cards are still face down it only sends up cards that are *safe*
  — a card is safe when no lower card of the opposite colour could still need
  it in the tableau — so it will never strip a card you were about to build on.
  Once nothing is face down and the outcome is decided, it drops the safety
  rule and runs the whole game out, drawing from the stock as needed. The
  entire cascade collapses into a **single undo step**, and any click on the
  table (or pressing `S` again) stops it.
- **Hint** (💡, or `H`) pulses the most useful move it can find, preferring
  moves that uncover a face-down card, and captions what it's suggesting.
- **No moves left** — when the position is genuinely dead, a banner says so
  instead of leaving you hunting for a move that doesn't exist.
- **Undo / Redo** — full history, both directions.
- **Timer and score** — standard Klondike scoring (+10 to a foundation, +5 for
  uncovering a card, +5 waste→tableau, −15 back off a foundation, a penalty for
  recycling the waste), plus a time bonus on a win.
- **Auto-save** — the game is written to browser storage as you play, so a
  refresh or an accidental tab close picks up exactly where you left off.
- Cards **glide** to their destination on every move and **flip** in 3D when
  they turn over; a new deal is dealt out card by card.

### Keyboard shortcuts

| Key | Action |
| --- | --- |
| `Space` | Draw from the stock |
| `S` | Solve / stop solving |
| `H` | Hint |
| `Ctrl+Z` | Undo |
| `Ctrl+Y` (or `Ctrl+Shift+Z`) | Redo |
| `N` | New game |
| `Esc` | Cancel the current selection |

App-bar controls: timer, move counter and score, **Hint**, **Solve**, **Undo**,
**Redo**, **New Game**, and a ⋮ menu with the Draw 1/3 toggle, appearance
settings and the shortcut list. On a narrow screen the title and New Game
button fold into the stats row and the menu.

## Project structure

```
lib/
  main.dart                     App entry point + theme
  models/
    card.dart                   Card, Suit, deck creation/shuffle, save encoding
    game_state.dart             All game rules: validation, solve, hints,
                                undo/redo, scoring, win logic, save/restore
    board_layout.dart           Where every pile and card sits, for a viewport
    app_theme.dart              Card-back and table colour schemes
  widgets/
    game_screen.dart            Scaffold, app bar, solve driver, keyboard, auto-save
    game_board.dart             The table: one positioned card layer + drop zones
    animated_card_slot.dart     Card position tweening and the 3D flip
    card_view.dart              Visual rendering of a single card / empty slot
    drag_feedback.dart          The card image shown under the pointer while dragging
    win_celebration.dart        The win cascade and panel
    appearance_sheet.dart       Card-back / table-colour picker
test/
  game_state_test.dart          Unit tests for the core rules
  solve_test.dart               Solve, hints, redo, scoring, save/restore
  widget_test.dart              Smoke tests, including the narrow layout
```

The UI layer (`widgets/`) is purely presentational; **all rules live in
`models/game_state.dart`**, which is plain Dart with no Flutter UI dependency, so
the game logic is fully unit-testable and identical on every platform.

The board is drawn as a single absolutely-positioned layer of cards, each keyed
by card identity, with its home computed by `board_layout.dart`. A move is
therefore just a change of coordinates and the card animates itself there —
there is no separate "flying card" machinery. Drop zones sit above the cards as
translucent hit areas, so a drag finds the pile while taps still reach the card
underneath.

## Building & running

Prerequisites: the Flutter SDK on your `PATH`. This repo was developed against
Flutter 3.44 (stable) / Dart 3.12.

```sh
flutter pub get          # fetch dependencies
flutter analyze          # static analysis (should report no issues)
flutter test             # run the unit + smoke tests
```

### Web
```sh
flutter run -d chrome                  # run in Chrome
flutter build web --release            # produce build\web\
```
The web build is fully responsive and works on mobile and desktop browsers.
