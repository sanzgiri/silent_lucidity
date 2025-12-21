# Info.plist Configuration

To ensure the app runs correctly in the background and has access to necessary sensors, you must configure the `Info.plist` file in your Xcode project.

## Required Keys

1.  **HealthKit Permissions**
    *   **Key**: `NSHealthShareUsageDescription`
    *   **Value**: "We need access to your heart rate to detect sleep stages."
    *   **Key**: `NSHealthUpdateUsageDescription`
    *   **Value**: "We use workout sessions to keep the app alive while you sleep."

2.  **Motion Usage (Stillness Gate)**
    *   **Key**: `NSMotionUsageDescription`
    *   **Value**: "We use motion sensors to detect stillness during sleep for better REM detection."

3.  **Background Modes**
    *   **Key**: `WKBackgroundModes` (Array)
    *   **Item 0**: `workout-processing`

## Steps in Xcode

1.  Open your project in Xcode.
2.  Select the **Target** for your Watch App.
3.  Go to the **Info** tab.
4.  Add the keys listed above.
5.  Go to the **Signing & Capabilities** tab.
6.  Click **+ Capability**.
7.  Add **HealthKit**.
8.  Add **Background Modes** and check **Workout Processing**.
9.  Add **Motion & Fitness** if required by your provisioning profile.
