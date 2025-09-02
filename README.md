# SmartReceipt (skeleton)

SmartReceipt — Personal Receipt Scanner & Expense Assistant (Flutter skeleton)

This repository is a runnable skeleton for the *first step* of the project:
on first run it shows the onboarding / auth flow including a **Skip for now (guest mode)** button.
Guest mode limits scans to 2 and disables cloud sync and collaboration.

What you get:
- Minimal, clean Flutter app using Riverpod + GoRouter.
- Localization (10+ languages) skeleton in assets/translations.
- TODO_KEYS.md and placeholders for Firebase, Billing, Sentry, Fastlane.
- GitHub Actions and Fastlane skeleton files.
- Tests: a sample widget test.
- A zip file created for download.

How to run:
1. Install Flutter (stable).
2. Open the folder in VS Code or Cursor.
3. Run `flutter pub get`.
4. Run `flutter run -d <device>`.

First step implemented:
- On app open you will be taken to the onboarding -> auth page with Sign-in options (placeholders) and "Skip for now" guest mode.

Next steps:
We will proceed step-by-step. You asked to split into 10 steps; this is step 1 (project structure + auth UI).
See TODO_KEYS.md for where to insert platform credentials.

