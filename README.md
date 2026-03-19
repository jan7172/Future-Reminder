# Future Reminder

> **Reminders that find you. Not when the clock says so — when you arrive.**

[![iOS](https://img.shields.io/badge/iOS-17%2B-blue?logo=apple)](https://future-reminder.app)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5-blue)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![App Store](https://img.shields.io/badge/App%20Store-Coming%20Soon-lightgrey?logo=apple)](https://future-reminder.app)

---

## 🌐 Website

**[future-reminder.app](https://future-reminder.app)**

---

## 📱 About

Most reminder apps work with fixed times. But in real life, you don't think *"buy milk at 6pm"* — you think *"buy milk when I'm at the supermarket."*

**Future Reminder** changes the way you think about reminders. Instead of setting a time, you set a **place**. The app notifies you automatically the moment you arrive — no tapping, no checking, no missed tasks.

---

## ✨ Features

- 📍 **Location Triggers** — Set any address or point of interest as the trigger for your reminder
- 🔔 **Automatic Notifications** — Get notified the moment you enter the defined radius
- 🔒 **100% Private** — All data stays exclusively on your device. No cloud, no tracking, no accounts
- 🎚️ **Adjustable Radius** — Choose a trigger zone between 50 and 500 meters
- ✅ **Clean & Simple** — Create a reminder in seconds, no setup required
- 📱 **iPhone Native** — Built with SwiftUI and CoreLocation, deeply integrated with iOS
- 🌍 **Bilingual** — English and German, follows your system language automatically

---

## 🛠 Tech Stack

| Technology | Purpose |
|---|---|
| **Swift** | Programming language |
| **SwiftUI** | User interface |
| **SwiftData** | Local data persistence |
| **CoreLocation** | Geofencing & location triggers |
| **MapKit** | Map display & address search |
| **UNUserNotificationCenter** | Local notifications |

---

## 📂 Project Structure

```
FutureReminder/
├── FutureReminderApp.swift     # App entry point, AppDelegate
├── Reminder.swift              # SwiftData model
├── LocationManager.swift       # CoreLocation & geofencing logic
├── ContentView.swift           # Main list view
├── AddReminderView.swift       # Create new reminder
├── ReminderDetailView.swift    # View & edit existing reminder
├── OnboardingView.swift        # First launch onboarding
├── DebugView.swift             # Hidden debug menu (long press +)
└── Localizable.xcstrings       # EN + DE translations
```

---

## 🚀 Getting Started

### Requirements

- Xcode 15 or later
- iOS 17+ deployment target
- Apple Developer Account (for running on a real device)

### Setup

```bash
git clone https://github.com/jan7172/Future-Reminder.git
cd Future-Reminder
open FutureReminder.xcodeproj
```

Select your target device and hit **Run (▶️)**.

> **Note:** Location-based geofencing does not work in the Simulator. Test on a real iPhone for full functionality.

---

## 🔒 Privacy

Future Reminder is built with privacy as a core principle:

- **No data collection** — the app does not collect, store, or transmit any personal data
- **No third-party SDKs** — only Apple's native frameworks are used
- **On-device only** — all reminders and location data stay on your device
- **No accounts required** — no sign-up, no login, no cloud sync

📄 [Full Privacy Policy](https://future-reminder.app/privacy)

---

## 🐛 Debug Menu

A hidden debug menu is available for testing:

**Long press the `+` button** in the top right corner for 1.5 seconds.

The debug menu allows you to:
- Fire test notifications instantly
- Trigger any reminder manually
- Re-register all geofences
- Check location & notification permission status

---

## 🌍 Localization

All UI strings are stored in `Localizable.xcstrings`. The app currently supports:

| Language | Status |
|---|---|
| 🇬🇧 English | ✅ Complete |
| 🇩🇪 German | ✅ Complete |

To add a new language:
1. Open Xcode → Project → Info → Localizations → `+`
2. Add the new language
3. Fill in the translations in `Localizable.xcstrings`

No code changes required.

---

## 📸 Screenshots

| Home | New Reminder | Detail |
|---|---|---|
| *Coming soon* | *Coming soon* | *Coming soon* |

---

## 🗺️ Roadmap

- [ ] App Store release
- [ ] iCloud sync
- [ ] Home screen widget
- [ ] Reminder history & statistics
- [ ] Additional trigger types
- [ ] Automatic reminder suggestions

---

## 🔗 Links

| | |
|---|---|
| 🌐 Website | [future-reminder.app](https://future-reminder.app) |
| 🧑‍💻 Developer | [jan-bauer.de](https://jan-bauer.de) |
| 🖥️ Website Repo | [Future-Reminders-Website](https://github.com/jan7172/Future-Reminders-Website) |
| 📬 TestFlight | [Join Beta](https://testflight.apple.com/join/drbdnbf8) |

---

## 📄 License

© 2026 Jan Bauer. All rights reserved.
