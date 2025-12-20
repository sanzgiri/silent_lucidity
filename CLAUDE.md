# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lucidity is a watchOS app designed to detect REM sleep phases and deliver subtle haptic cues to promote lucid dreaming. The app uses HealthKit data (heart rate and sleep analysis) combined with heuristic algorithms to approximate REM windows in real-time without relying on native OS sleep stage labels.

## Build Commands

### Opening and Building
```bash
# Open project in Xcode
open Lucidity/Lucidity.xcodeproj

# List available schemes
xcodebuild -list -project Lucidity/Lucidity.xcodeproj

# Build via CLI using -target (avoids container stub issues)
xcodebuild -project Lucidity/Lucidity.xcodeproj -target "Lucidity Watch App" -sdk watchos -configuration Debug build

# Build for simulator
xcodebuild -project Lucidity/Lucidity.xcodeproj -target "Lucidity Watch App" -sdk watchsimulator -configuration Debug build

# Build via convenience script (recommended)
cd Lucidity/Lucidity\ Watch\ App
./build_watch_app.sh build

# Build and install on connected Apple Watch
./build_watch_app.sh install

# Clean build artifacts
./build_watch_app.sh clean
```

**Important**: Use `-target` instead of `-scheme` when building from CLI. The scheme includes the iOS container stub which causes build errors ("Watch-Only Application Stubs are not available"). The build script has been updated to use the correct approach.

### Running and Testing
- Use Xcode to select an Apple Watch simulator or physical device
- Physical device recommended for accurate sensor behavior (heart rate, accelerometer)
- Refer to `walkthrough.md` for manual verification steps
- No automated tests currently exist; add XCTest targets if needed

### TestFlight Distribution
For installation on physical Apple Watch without Developer Mode:
- **Quick Start**: See `QUICK_START_TESTFLIGHT.md` for 6-step process
- **Detailed Guide**: See `TESTFLIGHT_SETUP.md` for complete walkthrough
- **Checklist**: See `TESTFLIGHT_CHECKLIST.md` for pre-flight verification
- Requires: Apple Developer Program enrollment ($99/year)

## Architecture

### Core Components

**HealthKitManager** (`HealthKitManager.swift`)
- Singleton `@MainActor` ObservableObject managing HealthKit authorization and data monitoring
- Monitors sleep analysis and heart rate via `HKObserverQuery` and `HKAnchoredObjectQuery`
- Implements REM detection heuristics using two approaches:
  1. Explicit REM samples (if available from HealthKit)
  2. Approximation based on 90-minute sleep cycles + heart rate variability (45-70 BPM range)
- Posts `remWindowDidChangeNotification` when REM status changes
- Published properties: `isAuthorized`, `latestSleepStart`, `latestSleepEnd`, `latestHeartRate`

**HapticCueManager** (`HapticCueManager.swift`)
- Singleton ObservableObject managing haptic feedback delivery
- Observes REM window changes from HealthKitManager via NotificationCenter
- Throttles haptic cues to max one per 30 seconds, with minimum 20-second intervals
- Suppresses cues when app is active (user is interacting with display)
- Logs cue delivery events to HistoryStore

**WorkoutSessionManager** (`WorkoutSessionManager.swift`)
- Singleton managing overnight HKWorkoutSession to keep app alive in background
- Uses `.mindAndBody` activity type optimized for low power consumption
- Enables continuous heart rate monitoring during sleep

**HistoryStore & HistoryView** (`History.swift`)
- Simple event logging system tracking haptic cue delivery
- MainActor singleton with published `events` array
- UI displays timestamped log entries

### Data Flow

1. User taps "Start Night" → requests HealthKit authorization if needed
2. WorkoutSessionManager starts background session
3. HealthKitManager begins monitoring sleep/heart rate with observers
4. Every heart rate/sleep update triggers REM evaluation:
   - Fetches recent sleep samples (last 8 hours)
   - Analyzes heart rate patterns during sleep cycles
   - Posts notification if REM status changes
5. HapticCueManager receives REM notifications
6. When REM=true and conditions met, delivers gentle haptic (.click + .start)
7. Haptic events logged to HistoryStore for user review

### REM Detection Algorithm

Core heuristic (see `algorithm_strategy.md`):
- **Formula**: `REM = (Motion ≈ 0) + (HR Volatility > Threshold)`
- Detects sleep onset when motion < 0.03g for 15+ minutes
- Suppresses triggers for first 80 minutes (deep sleep protection)
- Requires HR standard deviation > 5.0 over 5-minute window
- Blocks triggers when HR > 85 BPM (wakefulness guard)
- 20-minute cooldown between cues

### Key Files by Location

```
Lucidity/Lucidity Watch App/     # Main watchOS app
├── LucidityApp.swift            # App entry point
├── ContentView.swift            # Main UI with Start/Stop controls
├── HealthKitManager.swift       # Core REM detection logic
├── HapticCueManager.swift       # Haptic delivery system
├── WorkoutSessionManager.swift  # Background session management
├── History.swift                # Event logging UI and store
└── build_watch_app.sh           # Build convenience script

Root directory:                  # Legacy/prototype files
├── algorithm_strategy.md        # REM detection algorithm docs
├── Info_Config.md              # Required plist keys and capabilities
├── walkthrough.md              # Manual testing procedures
└── *.swift                     # Earlier prototype code (maintain consistency)
```

## HealthKit Configuration

Required Info.plist keys (see `Info_Config.md`):
- `NSHealthShareUsageDescription`: Heart rate access justification
- `NSHealthUpdateUsageDescription`: Workout session justification
- `WKBackgroundModes`: Array with `workout-processing`

Required capabilities:
- HealthKit
- Background Modes → Workout Processing

## Development Notes

### Code Style
- 4-space indentation (Xcode default)
- Types: PascalCase, methods/vars: lowerCamelCase
- Filenames match primary type
- Singletons use `.shared` pattern
- SwiftUI state via `ObservableObject` + `@Published`

### Important Constraints
- Requires watchOS 11+ (uses `@available(watchOS 11, *)` on HealthKitManager)
- All UI updates must be on `@MainActor`
- HealthKit queries run async; use proper Task/continuation patterns
- Keep last 8 hours of samples max to prevent memory growth

### Security & Privacy
- Never commit provisioning profiles or signing assets
- Do not log or export actual health data values
- All HealthKit usage requires explicit user authorization

## Project-Specific Patterns

When modifying HealthKit/haptics behavior:
1. Update both `Lucidity Watch App` files and root prototype files for consistency
2. Test on physical device for accurate sensor behavior
3. Document algorithm parameter changes in `algorithm_strategy.md`
4. Add manual test scenarios if changing REM detection logic
