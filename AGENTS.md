# Repository Guidelines

## Project Structure & Module Organization

- `Lucidity/Lucidity.xcodeproj`: Xcode project for the app targets.
- `Lucidity/Lucidity Watch App/`: primary watchOS app source (SwiftUI UI, HealthKit integration, haptics) plus `Assets.xcassets`.
- `*.swift` at the repo root: earlier/prototype SwiftUI + session/detector code (keep changes consistent with existing usage in the Xcode project).
- `*.md` at the repo root: design and verification docs (see `walkthrough.md`, `Info_Config.md`, `algorithm_strategy.md`, `ui_haptic_design.md`).

## Build, Test, and Development Commands

- Open in Xcode: `open Lucidity/Lucidity.xcodeproj`
- List targets/schemes: `xcodebuild -list -project Lucidity/Lucidity.xcodeproj`
- Build (CLI): `xcodebuild -project Lucidity/Lucidity.xcodeproj -scheme "Lucidity Watch App" -configuration Debug build`
- Run locally: use Xcode to select an Apple Watch simulator or (recommended) a physical Watch for sensor/background behavior; follow `walkthrough.md` for manual verification steps.

## Coding Style & Naming Conventions

- Use Xcode’s default Swift formatting (4-space indentation) and keep diffs small.
- Naming: types in `PascalCase`, methods/vars in `lowerCamelCase`, filenames match the primary type (e.g., `HealthKitManager.swift`).
- Keep watch-specific code in `Lucidity/Lucidity Watch App/`; follow existing patterns (e.g., `*.shared` manager singletons and SwiftUI `ObservableObject` state).

## Testing Guidelines

- No automated test targets are currently checked in. If you add tests, use XCTest, name files `TypeNameTests.swift`, and methods like `testFeature_expectedBehavior()`.
- When changing HealthKit/haptics/session behavior, add a short, reproducible manual test plan (device vs simulator expectations).

## Commit & Pull Request Guidelines

- Current git history uses short, plain-English summaries (example: `Initial implementation of Silent Lucidity WatchOS app`). Keep the first line ≤72 chars and write in the imperative mood.
- PRs should include: a clear description, steps to run/verify (including device/simulator notes), and screenshots/screen recordings for UI changes. Link related issues/tasks when available.

## Security & Configuration Tips

- Do not commit signing assets, provisioning profiles, or exported Health data/logs that could contain sensitive information.
- When modifying HealthKit/background execution, ensure required `Info.plist` keys and capabilities are updated per `Info_Config.md`.
