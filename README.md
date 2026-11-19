# 🃏 iVidiSolitaire

> Klondike Solitaire that teaches you to win: an Academy of strategy lessons, a coach at the table, and Game Center.

[Report Bug](https://github.com/VidiPT89/iSolitaire/issues) · [Request Feature](https://github.com/VidiPT89/iSolitaire/issues)

## ✨ Features

- ✅ **Academy** — 7 strategy lessons in PT-PT and English, each with exercises on real positions, explained mistakes and stars
- ✅ **Coach at the table** — comments on your moves (missed reveals, emptying a column with no King, rushing the foundations) and explains every hint
- ✅ **Game Center** — signs in at launch; leaderboards for high score, fastest win and total wins, plus 8 achievements
- ✅ Classic Klondike rules — draw 1 (with a fanned three-card waste in draw 3), unlimited or limited (1–5) passes through the deck
- ✅ Tap a card to play it to the best spot, or drag it — cards fly between piles, including the deal, undo and auto-complete
- ✅ Drop targets light up while dragging; invalid drops glide back to where they came from
- ✅ Smart hints that point at both the card and where it goes (or at the stock), and reliable "no moves left" detection
- ✅ Auto-complete as soon as the game is decided, even with cards left in the stock
- ✅ The game and its undo history (last 100 moves) survive closing the app
- ✅ Long columns squeeze to fit the screen; dedicated landscape layout with a side toolbar
- ✅ Redesigned cards (pip layouts on large screens), four table themes and five card backs
- ✅ Sound effects and haptics (each can be turned off), left-handed mode
- ✅ Statistics: games, wins, win rate, streaks, best/average time, best score, fewest moves — with a reset option
- ✅ Win celebration with personal-best badges
- ✅ PT-PT / English, Light/Dark/System, VoiceOver labels for every card
- ✅ Universal app — iPhone and iPad, portrait and landscape

## 🛠️ Tech Stack

| Category   | Technology          |
|------------|----------------------|
| Language   | Swift                |
| UI         | SwiftUI              |
| State      | Combine / ObservableObject |
| Persistence| UserDefaults (Codable) |
| IDE        | Xcode                |

## 🚀 Quick Start

### Prerequisites
- Xcode 16+
- iOS 17+ simulator or device

### Installation
```bash
git clone https://github.com/VidiPT89/iSolitaire.git
cd iSolitaire
open iSolitaire.xcodeproj
```

Build and run on any iPhone or iPad simulator/device.

## 📖 Usage

- Tap the stock pile to draw cards into the waste pile.
- Tap a card to send it to the best destination, or drag it (with any cards on top of it) onto another pile.
- Use the toolbar to undo, request a hint, finish a solved board automatically, or start a new game.
- Open Settings to change draw mode, passes through the deck, table theme, card back, left-handed mode, sounds, haptics, language and appearance.

## 🧪 Testing

The Klondike rules (move validation, scoring, hints, stuck detection, auto-complete planning) are pure functions in `KlondikeRules.swift`, covered by the `iSolitaireTests` unit tests, together with `GameModel` tests (undo, clock, saved games, stats, auto-complete) that run against an isolated `UserDefaults` suite:

```bash
xcodebuild -project iSolitaire.xcodeproj -scheme iSolitaire -destination 'platform=iOS Simulator,name=iPhone 17' test
```

The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml` (`xcodegen generate`).

## 🔒 Privacy

No accounts, analytics, ads or tracking. See [PRIVACY.md](PRIVACY.md).

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

## 👨‍💻 Author

**David Arsénio Martins**
🌐 Website: [ividi.dev](https://ividi.dev)
🐙 GitHub: [@VidiPT89](https://github.com/VidiPT89)

## 🤝 Contributing

Contributions, issues and feature requests are welcome. Feel free to check the [issues page](https://github.com/VidiPT89/iSolitaire/issues).

---

<p align="center">Developed by <a href="https://ividi.dev">David Arsénio Martins</a></p>
<p align="center">⭐ Star this repo if you like it!</p>
