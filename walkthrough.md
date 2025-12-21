# Verification Walkthrough

Since the app relies on physical sensors and long-running background sessions, verification must be done on a physical device or simulator.

## 1. Setup in Xcode
1.  Create a new **watchOS App** project in Xcode.
2.  Copy the provided Swift files into the project:
    *   `SessionManager.swift`
    *   `DreamDetector.swift`
    *   `ContentView.swift`
    *   `LucidApp.swift` (Replace the default App file)
3.  Configure `Info.plist` as described in `Info_Config.md`.
4.  Enable **HealthKit** and **Background Modes** capabilities.

## 2. Simulator Verification
1.  Select the **Apple Watch Series 10** simulator.
2.  Run the app.
3.  Click **Start Sleep Session**.
4.  **Verify**:
    *   The status changes to "Session Active".
    *   The "Monitoring..." text appears.
    *   Debug logs show "Monitoring started".

## 3. Device Verification (Field Test)
1.  Deploy to your Apple Watch.
2.  Open the app and tap **Start Sleep Session**.
3.  **Verify**:
    *   A green workout icon appears at the top of the watch face (indicating background execution).
    *   Lock the screen or lower your wrist.
    *   Wait 15 minutes (or modify `DreamDetector.swift` to 1 minute for testing).
    *   **Verify**: The debug log (if visible or saved) shows "Sleep Onset Detected".

## 4. Deployment with Free Apple ID
You can deploy without a paid Developer Program account ($99/yr), with these limitations:
*   **7-Day Expiry**: The app will stop working after 7 days and must be re-installed from Xcode.
*   **3 App Limit**: You can only have 3 free apps installed at once.

**Steps:**
1.  **Xcode Signing**: In "Signing & Capabilities", select your personal Team (created when you sign in with your Apple ID).
2.  **Trust Developer**: On your iPhone (Watch app or Settings), go to **General > VPN & Device Management**, tap your email, and **Trust** it.
3.  **Developer Mode**: On Apple Watch, go to **Settings > Privacy & Security > Developer Mode** and enable it (requires restart).

## 5. Verifying Advanced Algorithms
To verify the new heuristics without sleeping for 8 hours:
1.  **Modify Thresholds**: In `DreamDetector.swift`, temporarily set:
    *   `remOnsetMinMinutes = 0` (Disable time gating)
    *   `volatilityThreshold = 1.0` (Make it very sensitive)
2.  **Simulate Conditions**:
    *   Start the session.
    *   Keep the watch perfectly still (on a table).
    *   **Simulate HR Volatility**: If testing on a device, do some light activity (jumping jacks) then sit still to make your HR fluctuate while the accelerometer is stable. (Or use the Simulator's "Variable Heart Rate" mode).
3.  **Verify Trigger**: The debug log should show `REM Trigger! Vol: X.X`.

## 6. Watch App HealthKit Monitoring (Current App)
**Device (recommended):**
1.  Install the watch app target on a physical Apple Watch.
2.  Open the app and tap **Start Night**.
3.  **Verify**:
    *   HealthKit authorization prompt appears.
    *   Status changes to "Monitoring active" and heart rate starts updating.
    *   Workout indicator appears on the watch face (background execution).
4.  Open **Settings**:
    *   Toggle **Low Power** on and restart monitoring; confirm the status shows "low power."
    *   Adjust **Cue Interval** and verify cues are less frequent.
    *   Tap **Test Haptic** to verify cue delivery.
    *   Toggle **Require Stillness** and confirm the "Still:" indicator updates when you keep the watch motionless.
5.  Open **History** after a short session:
    *   Verify entries for session start/stop and REM detected/ended windows.

**Simulator:**
1.  Run on an Apple Watch simulator.
2.  Tap **Start Night**.
3.  **Expect**: "Health data unavailable" (or permission denied) and no HR/sleep updates, since HealthKit data is typically unavailable in the simulator.
