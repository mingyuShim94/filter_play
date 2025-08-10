# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FilterPlay is a Flutter-based face detection mini-game app where users use mouth movements to pop balloons. The app uses Google ML Kit for face detection and camera functionality to create an interactive AR-style game experience.

## Common Development Commands

### Running and Building
- `flutter run` - Run the app in debug mode on connected device/simulator  
- `flutter run -d android` - Run on Android device (primary target platform)
- `flutter run -d ios` - Run on iOS device/simulator
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app

### Testing and Quality
- `flutter test` - Run all widget tests (includes home screen, navigation, and camera screen tests)
- `flutter analyze` - Run static analysis (configured with flutter_lints)
- `flutter pub get` - Install dependencies from pubspec.yaml
- `flutter clean` - Clean build artifacts (recommended when ML Kit issues occur)

### Development Tools
- `flutter doctor` - Check Flutter installation and dependencies
- `flutter pub deps` - Show dependency tree
- `adb logcat` - View Android logs for debugging camera/ML Kit issues

## Project Architecture

### Core App Structure
- **State Management**: Flutter Riverpod for reactive state management
- **Navigation**: Basic MaterialApp routing between screens
- **Theme**: Material 3 design with purple color scheme

### Screen Architecture
- `HomeScreen` - Main landing page with game start button and permission status
- `CameraScreen` - Primary game screen with face detection and overlay
- `SettingsScreen` - Game settings and sensitivity configuration  
- `ResultScreen` - Post-game results display

### Service Layer
- `FaceDetectionService` - Google ML Kit face detection wrapper with performance optimization
- `CameraService` - Camera initialization and management
- `PermissionService` - Camera permission handling with user-friendly dialogs
- `LipTrackingService` - Mouth state detection using facial landmarks
- `ForeheadRectangleService` - Forehead region tracking for game mechanics
- `PerformanceService` - FPS and performance monitoring

### Provider Architecture
- `CameraProvider` - Camera state management and initialization
- `PermissionProvider` - Permission status tracking

### Key Dependencies
- **google_mlkit_face_detection**: Core face detection functionality
- **camera**: Camera access and image processing
- **flutter_riverpod**: State management
- **flame**: Game engine components
- **permission_handler**: Runtime permissions
- **firebase_core/analytics/crashlytics**: Analytics and crash reporting

### Face Detection Implementation
The app uses a phased approach for ML Kit configuration:
- **Phase 2B**: Basic face detection with bounding boxes (landmarks disabled for performance)
- **Phase 2C**: Enhanced detection with lip landmarks enabled for mouth tracking
- Performance-optimized settings: Fast mode, classification disabled, tracking disabled

### Game Mechanics
- 15-second timer-based gameplay
- Mouth open/close detection triggers balloon popping
- Forehead region tracking for balloon placement
- Real-time performance monitoring and debug overlays

### Development Notes
- Primary target platform is Android (iOS secondary)
- Debug features controlled by `_showDebugInfo` flag in CameraScreen
- Extensive Korean language UI text
- Performance monitoring built-in for ML Kit optimization