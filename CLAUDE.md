# CLAUDE.md

## Rules

- Every time you finish a task and write a summary of the implemented changes, include
  the name of the build that contains them, for example `build-30-1bca82e`. Branch
  builds are named `build-<run_number>-<sha7>`. Builds of `main` are tagged `0.x.0`.
- Write code comments, Markdown files and every identifier in English. That includes
  classes, structs, functions, methods, properties, variables and instances.

## Project notes

- SwiftUI app plus a WidgetKit extension, generated with XcodeGen from `project.yml`.
  Don't add third-party dependencies.
- `App/` is the app target, `Widget/` is the widget extension, and `Shared/` is
  compiled into both. `Config/` holds the Info.plist and entitlements files.
- Bundle IDs: `com.leonardoramirezr.24hclock` and `com.leonardoramirezr.24hclock.widget`.
  The project and CI set them through the `APP_BUNDLE_ID` / `WIDGET_BUNDLE_ID` build
  settings. Extensions use `<bundle>.<suffix>`.
- Don't use App Groups or any capability that needs registration in the developer
  portal: CI signs with an App Store Connect API key only. The widget reads the app's
  data from a shared keychain access group (`Shared/Storage/SharedSnapshotStore.swift`).
- Localization: the keys are the English source strings, in
  `Shared/Resources/{en,es}.lproj/Localizable.strings` (`InfoPlist.strings` lives per
  target). Add every new user-facing string in both languages.
- Swift language mode 5, deployment target iOS 17.
- Building needs macOS (`xcodegen generate`, then `xcodebuild`). In a Linux session,
  push the branch and read the logs of the `Build` workflow. Its run number and the
  short commit SHA form the build name.
