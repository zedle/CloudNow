# CloudNow fork goals

Local fork of [owenselles/CloudNow](https://github.com/owenselles/CloudNow) for Apple TV GeForce NOW, with REA-assisted validation against `/Applications/GeForceNOW.app` **2.0.90.126**.

## Open

- [ ] On-device verify Bluetooth stick feel + 4K60 after Bedroom(2) sideload
- [ ] Consider advertising `enablePartiallyReliableTransferGamepad:65535` for non-AV1 when handshake will use protocol v3
- [ ] Optional: deeper REA on Bifrost `sendGamepadEvent` / PR sequence path
- [ ] Xbox: same hold-Start withholding bug in `XboxCloudOverlayGestureState` / `XboxCloudOverlayInputSequence` (Menu is withheld for the whole press, short press replayed as a 17 ms tap). Port the GFN live-forward fix and update `XboxCloudInputDriverTests` short/long/replay cases.
- [ ] On-device verify GFN hold-Start pass-through (in-game hold actions + 1.8 s CloudNow menu)
- [ ] `GamesViewModel` permanently clamps and saves `streamSettings.fps` to `screen.maximumFramesPerSecond`; a temporary 30 Hz output leaves the saved preference at 30. Clamp only the requested value instead.
- [ ] Consider display-locked presentation at 60 Hz too (currently only <= 30 Hz to avoid changing 60 Hz latency)
- [ ] On-device verify "Adjust for Poor Network Conditions" -> NVST `a=vqos.drc.enable` actually drops resolution under loss (mapping is inferred from the native client, not yet confirmed)
- [ ] Visual pass of the Neon Glass theme on the TV (simulator screenshots only so far; real artwork not shown in fixtures)
- [ ] Xbox quality presets (Xbox currently gets the theme only; it exposes only proven controls)

## Done

- [x] Neon Glass dark theme (`CloudNowTheme`): forced dark, provider accent (GFN green / Xbox green), glow buttons, glass cards, backdrop; applied to service picker, login, device code, tab shell, Home/Library/catalog, Xbox login/rails
- [x] GFN native-style quality presets (Balanced / Data Saver / Competitive / Cinematic / Custom) clamped to entitlement + display, bitrate meter with GB/hr estimate, "Adjust for Poor Network Conditions" toggle (default off) wired to NVST `vqos.drc.enable`; manual edits flip to Custom. Unit tests in `StreamQualityPresetTests` + `GFNStreamControllerTests`, UI test `testStreamQualityPresetAppliesAndManualBitrateEditSwitchesToCustom`

- [x] Display-locked presentation at <= 30 Hz output: `CADisplayLink` releases at most one frame per refresh through `DisplayLockedFrameQueue` (capacity 2, 1 s backlog trim) so jitter-bunched frames no longer evict each other (tests 5/5). Verified on Bedroom(2) Release build at 4K30: `piqca_gmstats_dump` reports `enqueued: 180, displayed: 180, evicted: 0` (was 3-13 evicted per 180 before)

- [x] GFN overlay trigger (Start/Options) forwards live to the game; the 1.8 s hold still opens CloudNow's menu and masks the trigger until release (`OverlayLongPressGesture`, tests 4/4)
- [x] Sideload Debug build to Bedroom(2) (`com.zedle.CloudNow`, team `Y6SAB8VUS3`) and launch
- [x] Clone upstream into `/Users/gage/Git/CloudNow`
- [x] Confirm local GFN install; real stack is `libGeronimo` / `libBifrost2` (streamer is a stub)
- [x] Thin arm64 REA targets under `.rea-targets/`
- [x] FPS eligibility ceiling fix (Ultimate 4K@120 unlocks 60 within display limit) - tests 7/7
- [x] Stick hysteresis + neutral reinforce + lifecycle clear - AnalogStickDeadzoneFilterTests 7/7
- [x] Route replaceable gamepad snapshots onto `input_channel_partially_reliable` (was opened but unused)
- [x] Subagent research: `gamepad_channel_v1` is RI stats name; wire create label remains `input_channel_partially_reliable`

## Notes

- Apple TV HDMI tops out at **60 Hz**, so account “5K @ 120fps” cannot select 120 on ATV; 4K/5K @ 60 should.
- Prefer Adaptive Frame Pacing **off** when input feels laggy.
