# Help: Settings and Tradeoffs

This document explains each setting in the watch app, how it affects detection, and the tradeoffs to expect.

## Overview
Lucidity estimates REM windows using sleep stages, heart rate trends, optional HRV and respiratory rate signals, and a motion stillness gate. It is a heuristic, not a medical tool.
If sleep stages arrive after waking, the app falls back to session start or stillness onset and uses historical REM timing to estimate windows.

## Monitoring
- Low Power: Increases cue interval minimums, slows motion polling, and skips workout sessions to save battery. Heart rate updates may be less frequent.
- Require Stillness: Blocks REM detection until the watch is still for the configured duration.
- Stillness Minutes: Lower values start monitoring sooner but can increase false starts.
- Auto Mode:
  - Motion-only (default): Auto start when still; auto stop when you move for several minutes.
  - Hybrid: Uses both motion and HealthKit sleep samples to start/stop.
  - HealthKit-only: Auto start/stop based only on recent sleep samples.

## Detection Strictness
- Lenient: Trusts explicit REM stages; inferred REM can pass with HR in range or support signals.
- Balanced (default): Uses HR in range and/or support signals when available; fewer false positives.
- Strict: Requires HR in range plus support signals when available; inferred REM requires support availability.

## Cues
- Cue Interval: How often cues can fire during a REM window.
- Min Cue Throttle: A safety floor that prevents rapid repeat cues (not configurable).
- Pulse Count: Number of haptic pulses per cue (3 to 15).
- Pulse Interval: Spacing between pulses (0.2 to 0.4 seconds).
- Haptic Type: Click-only, Start-only, or Click+Start. Test Haptic uses the current pattern.

## Signals
- Use HRV: Adds HRV support gating when recent samples exist.
- Use Respiratory: Adds respiratory support gating when recent samples exist.
- If support signals are disabled or stale, strictness may reduce detection sensitivity.

## Display
- Sleep Screen: Choose a background style for the overnight screen.
- Static backgrounds (Radial Glow, Moon Rings, Starfield) use less battery than animated Breathing Glow.

## History
History logs session start/stop, REM start/end windows, and cue deliveries for cross-checking against other sleep trackers.
Event timestamps are aligned to the REM window start/end (not the time the log is written), and events are sorted by time to keep order consistent.

## Summary
Summary shows the last session settings used and live diagnostics (workout state, HR age, motion status) to help troubleshoot missing cues.
