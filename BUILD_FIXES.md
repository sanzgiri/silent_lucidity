# Build Fixes and Configuration Issues

## Issues Fixed

### 1. Build Error: "Watch-Only Application Stubs are not available"

**Problem**: When building using the scheme "Lucidity Watch App", the build failed with:
```
error: Watch-Only Application Stubs are not available when building for watchOS Simulator.
```

**Root Cause**: The Xcode project has two targets:
- `Lucidity` - iOS container app (product type: `com.apple.product-type.application.watchapp2-container`)
- `Lucidity Watch App` - Actual watchOS app

The container target uses the legacy watchOS 1.0 architecture that required an iOS companion app. When building via the scheme, both targets are built, and the container stub fails on watchOS simulator/device.

**Solution**: Build using `-target` instead of `-scheme`:
```bash
# ✅ Works - builds only the watch app target
xcodebuild -project Lucidity.xcodeproj -target "Lucidity Watch App" -sdk watchos build

# ❌ Fails - tries to build both targets including container stub
xcodebuild -project Lucidity.xcodeproj -scheme "Lucidity Watch App" build
```

The `build_watch_app.sh` script has been updated to use the correct approach.

### 2. Configuration Issues Identified

**Info.plist Configuration**:
- ✅ Has required HealthKit permission descriptions
- ✅ Has `WKBackgroundModes` with `workout-processing`
- ⚠️ Has `UIBackgroundModes` with generic `processing` and `fetch` (watchOS doesn't use these)

**Entitlements**:
- ✅ Has `com.apple.developer.healthkit` enabled
- ⚠️ Has `com.apple.developer.healthkit.access` with `health-records` (unnecessary for this app)

These don't prevent building but could be cleaned up.

## Can This App Run on iPhone?

**Short Answer**: No, not without significant architectural changes.

**Why It Won't Work**:

1. **Heart Rate Monitoring**:
   - Apple Watch: Continuous heart rate monitoring during sleep via `HKWorkoutSession`
   - iPhone: No built-in heart rate sensor; can only read historical HR data from paired Watch
   - iPhone cannot monitor real-time heart rate during sleep

2. **Haptic Feedback**:
   - Code uses `WKInterfaceDevice.current().play(.click)` (watchOS API)
   - iPhone equivalent is `UINotificationFeedbackGenerator()` with different capabilities
   - Watch haptics are designed to wake user subtly; phone haptics are different

3. **Background Execution**:
   - watchOS: `HKWorkoutSession` keeps app alive all night monitoring sensors
   - iOS: Different background modes; cannot continuously monitor sensors like Watch

4. **Root Directory Code**:
   - Files like `DreamDetector.swift` and `SessionManager.swift` in root use `WatchKit` APIs
   - These appear to be early prototypes/experiments for watchOS
   - Would need complete rewrite for iOS

**What Would Be Needed for iPhone Version**:
- Read historical heart rate data from HealthKit (delayed, not real-time)
- Use `CoreMotion` on iPhone to detect movement (different than Watch accelerometer)
- Replace `WKInterfaceDevice` haptics with `UIFeedbackGenerator`
- Accept that detection will be less accurate without continuous HR monitoring
- Possibly use phone on nightstand and rely on microphone/movement detection instead

## Workaround for "Can't Enable Developer Mode on Watch"

If you can't enable Developer mode on your Apple Watch:

**Option 1: Use Watch Simulator**
```bash
xcodebuild -project Lucidity.xcodeproj -target "Lucidity Watch App" -sdk watchsimulator build
```
- Limited: No real heart rate data, no sleep tracking
- Useful for UI testing only

**Option 2: TestFlight Distribution**
- Requires Apple Developer Program ($99/year)
- Build archive and upload to App Store Connect
- Install via TestFlight (no Developer mode needed)
- Full functionality with real sensors

**Option 3: Enable Developer Mode**
- watchOS 9+: Settings → Privacy & Security → Developer Mode
- Restart Watch after enabling
- If greyed out, may need to:
  - Unpair and re-pair Watch
  - Update watchOS to latest version
  - Check if device management profile is blocking it

## Recommended Next Steps

1. **For watchOS development**: Fix Developer Mode issue or use TestFlight
2. **For iPhone version**: This would be a significant rewrite - see above architectural changes needed
3. **Current project**: Can build and run on Watch simulator for UI testing, but needs physical device for real functionality

## App Icon Status

✅ **App icon has been added** (1024x1024px PNG)
- Location: `Lucidity/Lucidity Watch App/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- Features: Blue circle, moon, ZZZs, vibration waves, "REM ALERT" text
- Ready for TestFlight upload
