# Repository Agent Checklist

## Local fork notes

- Local sideload signing uses team `Y6SAB8VUS3` and bundle `com.zedle.CloudNow` (not upstream `com.owenselles.CloudNow2`). BG token-refresh id / keychain service use `com.zedle.CloudNow.*`. Prefer `xcodebuild` + `devicectl device install app` over Xcode MCP RunProject for device installs.
- GFN Settings frame-rate eligibility (`GFNSettingsEligibilityPolicy.frameRates`) uses a **membership ceiling**: at the selected resolution, any candidate fps <= max entitled fps is membership-allowed. Display gating via `maximumFramesPerSecond` is unchanged (Apple TV HDMI is typically 60 Hz).
- GFN overlay trigger hold (`OverlayLongPressGesture` in `InputSender.swift`) forwards the trigger to the game live so in-game hold-Start actions work; after 216 ticks (~1.8 s) it opens the local menu and masks the trigger until physical release. A trigger still held when input resumes is `suppressedUntilRelease()`. Xbox (`XboxCloudOverlayGestureState`) still withholds Menu; see TODO.MD. Never install/launch on the user's Apple TV (Bedroom (2)) unless explicitly asked.
- Video presentation (GFN and Xbox share `VideoSurfaceView`): when the display refreshes at <= 30 Hz (measured from `CADisplayLink`), `WebRTCFrameRenderer` routes frames through `DisplayLockedFrameQueue` and enqueues at most one per refresh instead of presenting on arrival; this mode bypasses `AdaptiveFramePacer`. Above 30 Hz the original immediate/paced mailbox path is unchanged. Coverage: `CloudNowTests/Video/DisplayLockedFrameQueueTests.swift`.
- UI theme ("Neon Glass"): `CloudNow/UI/CloudNowTheme.swift` owns colors, `CloudNowBackdrop`, `CloudNowGlowButtonStyle`, `cloudNowGlass`, and `CloudNowSectionTitle`. The provider accent flows through `@Environment(\.cloudNowAccent)` set by `.cloudNowTheme(accent:)` in `CloudNowApp`; the production root forces `.preferredColorScheme(.dark)` (UI-test root still honors `--cloudnow-ui-color-scheme`). The tab-shell backdrop is static (no animation behind streams).
- GFN quality presets: `Session/StreamQualityPreset.swift` (`StreamQualityPresetPolicy.apply`) maps presets to resolution/fps/bitrate/codec/color/chroma/DRC, clamped by `GFNSettingsEligibilityPolicy.frameRates` and account resolutions (16:9 preferred). `StreamSettings.qualityPreset` / `adjustForPoorNetwork` decode with defaults (`.custom` / false). Settings rows use `presetTrackingBinding` so any manual change flips to Custom. `adjustForPoorNetwork` drives NVST `a=vqos.drc.enable` (`dfc` stays 0). UI in `UI/GFNStreamQualityControls.swift`. Coverage: `CloudNowTests/Session/StreamQualityPresetTests.swift`, `GFNStreamControllerTests` (drc line), UI test `testStreamQualityPresetAppliesAndManualBitrateEditSwitchesToCustom`.
- GFN analog sticks use per-slot `AnalogStickDeadzoneFilter` hysteresis (enter at deadzone, exit at `deadzone * 0.65`) via `mappedControllerState`. Clear stick filters and neutral-reinforce tokens on `detachController`, `stop()`, `applyRemoteMode`, and slot reuse in `attachController`. Overlay tap samples use `mappedControllerState` so mid-band sticks stay consistent. Coverage: `CloudNowTests/Streaming/AnalogStickDeadzoneFilterTests.swift`.

For every task that changes repository content, complete this checklist before reporting the task as finished:

1. Read the pinned SwiftFormat and SwiftLint versions from the `README.md` **Linting** section. The README is the source of truth; do not assume previously installed versions are current.
2. Verify the executables match those exact versions.
3. Run the non-mutating checks from the repository root:

   ```bash
   swiftformat --lint --config .swiftformat CloudNow CloudNowTests CloudNowUITests
   swiftlint --strict --config .swiftlint.yml CloudNow CloudNowTests CloudNowUITests
   ```

4. Do not mark the task complete until both checks pass. If a local executable has the wrong version, use the pinned CI/pre-commit tool environment instead of running the mismatched executable.
5. Report both check results in the final response.
