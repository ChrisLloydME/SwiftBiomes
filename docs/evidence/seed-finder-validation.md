# Seed Finder validation evidence

Validated on 2026-07-13 with Xcode beta because the installed stable Xcode cannot open this project's object version 110.

## Core flow

The macOS UI test launches SwiftBiomes, opens **Find Seeds**, searches the inclusive range `260...264` for Mushroom Fields at `(0, 0)`, selects result `262`, presses **Use Seed**, waits for the sheet to close, and verifies that the main window's Seed field contains `262`.

Command:

```sh
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
  -project SwiftBiomes.xcodeproj \
  -scheme SwiftBiomes \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/SwiftBiomes-seed-finder-derived \
  -parallel-testing-enabled NO \
  -only-testing:SwiftBiomesUITests/SwiftBiomesUITests/testSeedFinderCoreFlow \
  -resultBundlePath /private/tmp/SwiftBiomes-seed-finder-ui-5.xcresult \
  -quiet test
```

Result: exit code 0. The test completed the end-to-end seed-finder flow and retained `seed-finder-result.png` at the result-selection state. One earlier evidence-only run missed the toolbar click while UI automation was busy; its activity log was inspected and the test now performs one bounded retry before failing.

## Unit regression

Command:

```sh
/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild \
  -project SwiftBiomes.xcodeproj \
  -scheme SwiftBiomes \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/SwiftBiomes-seed-finder-derived \
  -parallel-testing-enabled NO \
  -skip-testing:SwiftBiomesUITests \
  -quiet test
```

Result: exit code 0. The serial unit suite passed, including catalog filtering, bounded numeric search, request validation, and Qt-compatible seed splitting tests. Parallel testing was intentionally disabled after the Swift Testing runner itself crashed during an earlier parallel attempt.

## Visual check

The first captured result exposed an undersized results table. After correcting its sizing and alignment, the final screenshot shows a native AppKit sheet with standard controls, restrained hierarchy, consistent spacing, a determinate progress indicator, and a full-width result table. No custom visual asset or non-native control was introduced.

The only recurring build output was Xcode's warning that both arm64 and x86_64 variants match the generic `platform=macOS` destination; Xcode selected arm64 and all final checks passed.
