# Klondike Solitaire

A cross-platform Klondike (classic) Solitaire game built with **Flutter**, so the
entire game — rules, rendering, and input — is a single shared Dart codebase that
runs natively on:

- **Windows** (desktop)
- **Android phones**
- **Android tablets**

(Apple platforms are intentionally not targeted.)

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

### Two ways to move cards
1. **Drag & drop** — press a card (or a valid run of cards) and drag it onto the
   destination pile. Valid targets highlight green.
2. **Tap to place** — tap a card to pick it up (it lifts and gets an amber border),
   then tap the destination pile to drop it. Tap the card again to cancel.

**Shortcut:** tapping a playable top card will auto-send it to a foundation if a
legal foundation move exists.

App-bar controls: move counter, Draw 1/3 toggle, **Undo**, and **New Game**.

## Project structure

```
lib/
  main.dart                     App entry point + theme
  models/
    card.dart                   Card, Suit, deck creation/shuffle
    game_state.dart             All game rules, move validation, undo, win logic
  widgets/
    game_screen.dart            Scaffold, app bar, new-game/undo, win dialog
    game_board.dart             Responsive layout (phone / tablet / desktop)
    tableau_column.dart         A tableau column: stacked cards, drag + tap
    foundation_pile.dart        A foundation pile (drop target)
    stock_waste.dart            Stock + fanned waste pile
    card_view.dart              Visual rendering of a single card / empty slot
    drag_feedback.dart          The card image shown under the pointer while dragging
test/
  game_state_test.dart          Unit tests for the game rules
  widget_test.dart              Smoke test that the app boots
```

The UI layer (`widgets/`) is purely presentational; **all rules live in
`models/game_state.dart`**, which is plain Dart with no Flutter UI dependency, so
the game logic is fully unit-testable and identical on every platform.

## Building & running

Prerequisites: the Flutter SDK on your `PATH`. This repo was developed against
Flutter 3.44 (stable) / Dart 3.12.

```sh
flutter pub get          # fetch dependencies
flutter analyze          # static analysis (should report no issues)
flutter test             # run the unit + smoke tests
```

### Windows desktop
```sh
flutter run -d windows                 # run in debug
flutter build windows --release        # produce build\windows\x64\runner\Release\
```
Requires Visual Studio with the **Desktop development with C++** workload
(MSVC toolchain, C++ CMake tools, Windows SDK).

### Android (phone or tablet)
```sh
flutter devices                        # list attached devices/emulators
flutter run -d <device-id>             # build, install, and launch
flutter build apk --release            # universal release APK -> build\app\outputs\flutter-apk\
flutter build appbundle --release      # Play Store bundle
```
Requires the Android SDK + platform-tools and an accepted set of SDK licenses
(`flutter doctor --android-licenses`).

The same APK adapts its layout to phones and tablets automatically: card sizes are
computed from the available width, and the board scrolls if a column grows taller
than the screen.
