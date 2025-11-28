# Algorithmic Strategy: Real-Time REM Detection

This document outlines the heuristic engine used to detect REM sleep phases in real-time without access to native OS sleep stage labels.

## Core Concept
REM (Rapid Eye Movement) sleep is biologically characterized by two simultaneous states:
1.  **Sleep Atonia**: Complete muscle paralysis (to prevent acting out dreams).
2.  **Autonomic Activation**: The brain is active, causing irregular heart rate (HR) and breathing, unlike the steady, rhythmic rates of Deep Sleep.

**Formula:** `REM = (Motion ≈ 0) + (HR Volatility > Threshold)`

## The Algorithm

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
*   **Polling Rate**: Motion is polled at 1Hz (very low power).
*   **Computation**: Volatility is calculated only on new HR samples (event-driven), not in a tight loop.
*   **Workout Session**: Uses `.mindAndBody` activity type, which is optimized for lower sampling rates compared to `.running`.
