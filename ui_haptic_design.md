# UI & Haptic Design Strategy

This document outlines the user experience philosophy for the Lucid Dreaming induction app, focusing on the delicate balance between **signaling** the subconscious and **waking** the conscious mind.

## 1. Watch App Cueing (HealthKitManager)
The watch app uses a gentle, repeating cue during REM windows.

*   **The Pattern**: `.click` followed by a subtle `.start` haptic.
*   **Cadence**: Configurable interval (default ~30s); throttled so cues do not fire too frequently.
*   **Suppression**: Cues are suppressed while the app is active to avoid waking the user.
*   **Low Power Mode**: Increases cue interval and can skip workout sessions to reduce battery drain.
*   **Pulse Configuration**: Pulse count, interval, and haptic type (click/start) are configurable and apply to both cues and Test Haptic.
*   **Test Haptic**: A settings control triggers the current pulse pattern for verification.

## 2. Prototype Cueing (DreamDetector)
The prototype uses a stronger "totem" pattern designed to be unmistakable.

### The "Totem" Haptic Pattern
The core interaction is the haptic cue delivered during REM sleep.

*   **The Pattern**: A "Double-Tap" sequence (`Click-Click` ... pause ... `Click-Click`).
*   **Duration**: ~2.5 seconds per cycle.
*   **Philosophy**:
    *   **Artificiality**: Nature does not produce precise double-clicks. This distinct, artificial rhythm is designed to pierce through the dream narrative as an anomaly, prompting a "Reality Check."
    *   **Subtlety**: We use the `.click` haptic (crisp, light) rather than `.notification` (heavy, vibrating) to minimize the risk of waking the user.

## 3. The "Lucidity vs. Waking" Trade-off
The app is designed to **fail safely**.
*   **Success**: User recognizes the cue in the dream -> Becomes Lucid.
*   **Safe Failure**: User sleeps through the cue -> Normal sleep continues.
*   **Critical Failure**: User wakes up -> Sleep is disrupted.

**Auto-Stop**: The haptic pattern **always auto-stops**. It is not an alarm. If the user does not feel it, the app waits for the next REM cycle (90 mins later) rather than escalating volume.

## 4. Configuration Strategy (Deep Sleepers)
Users have different arousal thresholds. The **Settings** menu allows tuning:

### A. Intensity (The "Volume")
*   **Low**: `.click` (Sharp, light). Best for light sleepers.
*   **Medium**: `.directionUp` (Tactile nudge). Balanced.
*   **High**: `.start` (Heavy thump). For deep sleepers.

### B. Repetitions (The "Duration")
*   **Standard (2-3 reps)**: ~3-5 seconds. Sufficient for most users to notice the anomaly.
*   **Extended (5-10 reps)**: ~8-15 seconds.
    *   **Reasoning**: Deep sleepers may need a longer stimulus to bridge the gap from deep immersion to noticing the sensation.
    *   **Strategy**: It is better to **increase duration** before intensity. A long, gentle tapping is less likely to startle the user awake than a short, violent thump.

## 5. Visual Feedback
If the user wakes up (false awakening) or checks the watch:
*   **Screen**: Displays a purple **"REALITY CHECK"** banner.
*   **Purpose**: Confirms that the sensation was real and not hallucinated, reinforcing the habit of performing a reality check (e.g., counting fingers) whenever the vibration is felt.
