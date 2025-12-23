# Algorithmic Strategy: Real-Time REM Detection

This document outlines the heuristic engines used for REM detection across the prototype and the watch app.

## Core Concept
REM (Rapid Eye Movement) sleep is biologically characterized by two simultaneous states:
1.  **Sleep Atonia**: Complete muscle paralysis (to prevent acting out dreams).
2.  **Autonomic Activation**: The brain is active, causing irregular heart rate (HR) and breathing, unlike the steady, rhythmic rates of Deep Sleep.

**Formula:** `REM = (Motion ≈ 0) + (Autonomic Activation)`

## Watch App (HealthKitManager)

### 1. Inputs
*   **Sleep Analysis**: HealthKit sleep stages; explicit `.asleepREM` when available.
*   **Heart Rate**: Anchored stream from HealthKit (workout session keeps it live).
*   **HRV (SDNN)**: Optional support signal from HealthKit.
*   **Respiratory Rate**: Optional support signal from HealthKit.
*   **Motion Stillness**: Optional CoreMotion stillness gate (default on).

### 2. Sleep Session Windowing
*   Use the last 12 hours of sleep samples.
*   Merge contiguous samples; a gap > 30 minutes starts a new session.
*   The most recent session window defines the active sleep period.

### 3. REM Detection (Primary Path)
*   If an explicit REM stage exists and is recent (within a short grace period):
    *   Require stillness (if enabled).
    *   Accept based on **Detection Strictness** using HR range and support signals.

### 4. REM Detection (Fallback Path)
*   If no current explicit REM:
    *   Approximate 90-minute cycles from sleep start.
    *   Choose the current or previous cycle’s last 20-minute REM window.
    *   Apply **Detection Strictness** to HR range and support signals.

### 5. Dynamic HR Range
*   Uses recent heart rate samples (last ~2 hours) to compute a median baseline.
*   Range defaults to `45–70 BPM` if insufficient samples.

### 6. Stillness Gate
*   Motion stillness must be maintained for a configurable duration (default 10 minutes).
*   Can be disabled in settings to save battery or during testing.

### 7. Detection Strictness
*   **Lenient**: Trust explicit REM stages; inferred REM can pass with HR in range or support signals.
*   **Balanced**: Uses HR in range and/or support signals when available; default.
*   **Strict**: Requires HR in range plus support signals when available; inferred REM requires support availability.

### 8. Auto Start/Stop Modes
*   **Motion-only** (default): Start when still, stop after sustained movement.
*   **Hybrid**: Motion + HealthKit sleep samples can start/stop sessions.
*   **HealthKit-only**: Uses sleep samples only for session automation.

### 9. Session & REM Logging
*   History logs session start/stop and REM transitions (start/end) with window timestamps for cross-checking.

## Prototype (DreamDetector)

### 1. Inputs
*   **Accelerometer (1Hz)**: Measures user movement.
*   **Heart Rate (Variable)**: Updates from `HKWorkoutSession` (typically every 3-5 seconds).

### 2. State Machine

#### A. Sleep Onset Detection
*   **Logic**: Monitor `userAcceleration` magnitude.
*   **Condition**: If magnitude < `0.03g` for > 15 minutes continuously.
*   **Action**: Mark `sleepOnsetTime`.

#### B. Time Gating (The "Deep Sleep" Shield)
*   **Logic**: The first sleep cycle is predominantly Deep Sleep (NREM 3). Waking a user here causes grogginess (sleep inertia).
*   **Condition**: `minutesAsleep < 80`.
*   **Action**: Suppress all triggers.

#### C. Wakefulness Guard
*   **Logic**: If Heart Rate is high, the user is likely awake, restless, or having a nightmare.
*   **Condition**: `currentHR > 85 BPM` (Adjustable based on user's resting HR).
*   **Action**: Suppress triggers.

#### D. The REM Trigger (Volatility Check)
*   **Logic**: Calculate the Standard Deviation (SD) of Heart Rate over a rolling 5-minute window.
*   **Condition**:
    *   User is Still (Magnitude < 0.03g).
    *   `HR_StandardDeviation > 5.0` (Indicates variability).
*   **Action**: Fire Haptic Trigger.

### 3. Tuning Parameters

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `movementThreshold` | 0.03g | Sensitivity to movement. Lower = stricter stillness. |
| `remOnsetMinMinutes` | 80m | Time before first trigger is allowed. |
| `cooldownMinutes` | 20m | Minimum time between triggers to prevent spamming. |
| `volatilityThreshold` | 5.0 | How "erratic" the HR must be to count as REM. |
| `wakefulnessHRThreshold` | 85 BPM | Safety cutoff to avoid triggering when awake. |

## Battery Optimization
*   **Polling Rate**: Motion is polled at 1–2 Hz (low power).
*   **Computation**: Evaluation is event-driven by HealthKit updates.
*   **Workout Session**: Uses `.mindAndBody` to keep HR streaming (optional in Low Power mode).
