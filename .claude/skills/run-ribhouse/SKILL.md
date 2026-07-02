---
name: run-ribhouse
description: Use when asked to run, launch, demo, or visually verify the RibHouse example app (Examples/RibHouse) on the iOS simulator — including capturing screenshots or checking live streaming behavior (pit summary, Pit Board, last-call banner).
---

# Running RibHouse on the iOS Simulator

`xcodebuild … test` works headlessly, but SEEING the app needs `simctl` + the Simulator app. `simctl` cannot tap — drive interactions with the UI tests.

## Launch and screenshot

```bash
UDID=$(xcrun simctl list devices available | grep -E '^\s+iPhone 17 \(' | head -1 | grep -oE '[A-F0-9-]{36}')
xcrun simctl boot "$UDID" 2>/dev/null; open -a Simulator
cd Examples/RibHouse
xcodebuild -project RibHouse.xcodeproj -scheme RibHouse \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath /tmp/rhdd build
xcrun simctl install "$UDID" /tmp/rhdd/Build/Products/Debug-iphonesimulator/RibHouse.app
xcrun simctl launch "$UDID" com.napkin.example.RibHouse -fastTicks
sleep 3 && xcrun simctl io "$UDID" screenshot /tmp/rh-launch.png
```

- `-fastTicks` shrinks the PitService/SpecialsService intervals (0.5s / 0.75s) so streaming is visible within seconds. Omit it for the real cadence (4s / 6s).
- LOOK at the screenshot (Read tool). Expected at launch: cream "Step inside the smokehouse" LoggedOut screen. A blank frame means the launch failed.

## Driving interactions (login → Pit Board → logout)

There is no `simctl` tap. Drive the real UI with the XCUITests while a parallel loop screenshots the simulator:

```bash
for i in $(seq -w 1 60); do xcrun simctl io "$UDID" screenshot /tmp/drive-$i.png; sleep 1.5; done &
xcodebuild -project RibHouse.xcodeproj -scheme RibHouse \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:RibHouseUITests/RibHouseUITests/testLoginRevealsBarbecueFoodsAndLogoutReturns test
```

Frame sizes hint at content when picking which to Read: cream LoggedOut ≈158KB; dark LoggedIn/PitBoard ≈195–250KB; multi-MB frames are mid-transition blends (often the best evidence that streams are animating).

## Gotchas

- New Swift files or newly recorded snapshot PNGs are invisible to the tracked `.xcodeproj` until `xcodegen` runs from `Examples/RibHouse/` — the generated project is an explicit file list.
- The test harness reinstalls and relaunches the app itself; args from a manual `simctl launch` don't apply to test-driven runs (the fastTicks UI test passes its own launch argument).
- Full suite command lives in AGENTS.md: `xcodebuild … -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" test`.
