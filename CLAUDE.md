# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter project called "filterplay" - currently a basic Flutter counter app template. The project follows standard Flutter project structure with cross-platform support for Android, iOS, Web, Windows, Linux, and macOS.

## Common Development Commands

### Running and Building
- `flutter run` - Run the app in debug mode on connected device/simulator
- `flutter run -d chrome` - Run in Chrome browser
- `flutter run -d windows` - Run on Windows
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app
- `flutter build web` - Build for web deployment

### Testing and Quality
- `flutter test` - Run all widget tests (currently includes basic counter test)
- `flutter analyze` - Run static analysis (configured with flutter_lints)
- `flutter pub get` - Install dependencies from pubspec.yaml
- `flutter pub upgrade` - Upgrade dependencies to latest compatible versions

### Development Tools
- `flutter doctor` - Check Flutter installation and dependencies
- `flutter clean` - Clean build artifacts (useful for troubleshooting)
- `flutter pub deps` - Show dependency tree

## Project Architecture

### Core Structure
- `lib/main.dart` - Entry point with MaterialApp and counter demo
- `test/widget_test.dart` - Basic widget tests for counter functionality
- `pubspec.yaml` - Dependencies (currently minimal: cupertino_icons, flutter_lints)

### Platform Support
Full multi-platform Flutter app with native configurations for:
- Android (Kotlin-based, API targeting)
- iOS (Swift-based, CocoaPods)
- Web (Progressive Web App ready)
- Desktop (Windows, macOS, Linux with CMake)

### Current State
This is a fresh Flutter template project with the standard counter app. The main components are:
- `MyApp` - Root MaterialApp widget with Material 3 theming
- `MyHomePage` - StatefulWidget with counter logic
- Basic state management using setState()
- Material Design UI with FloatingActionButton

### Development Workflow
- Hot reload enabled for fast development iteration
- Linting configured via analysis_options.yaml with flutter_lints package
- Single test file demonstrating widget testing patterns
- Cross-platform builds supported out of the box