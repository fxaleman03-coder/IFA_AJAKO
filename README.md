# libreta_de_ifa

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## macOS build notes

- Open `macos/Runner.xcworkspace` (not `macos/Runner.xcodeproj`) to ensure CocoaPods are loaded.
- After `flutter clean`, run `flutter pub get` to regenerate `.dart_tool` and `macos/Flutter/ephemeral`.
- If plugins fail to link on macOS, run `cd macos` then `pod install` from the project root.
