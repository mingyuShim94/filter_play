# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KDH Ranking Filter is a Flutter-based face detection ranking game where users place character images on their forehead via AR overlay and organize them in a 10-slot ranking system. The app features multiple filter categories, remote asset downloading, and screen recording capabilities with Google ML Kit integration.

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
- `RankingFilterListScreen` - Main landing page with filter category selection and game entry
- `RankingFilterScreen` - Primary game screen with face detection, character overlay, and ranking slots
- `ResultScreen` - Post-game video playback and sharing
- `SettingsScreen` - Game settings and configuration

### Service Layer
- `FaceDetectionService` - Google ML Kit face detection wrapper with performance optimization
- `ForeheadRectangleService` - Forehead region tracking and character image overlay positioning
- `FilterDataService` - Remote filter/character data management with Cloudflare R2 backend
- `RankingDataService` - Character data loading and game content management
- `AssetDownloadService` - Remote asset downloading and caching system
- `VideoProcessingService` - Screen recording crop and processing with FFmpeg
- `PerformanceService` - FPS and performance monitoring

### Provider Architecture
- `RankingGameProvider` - Core game state management (current character, ranking slots, game status)
- `FilterProvider` - Filter category and selection state
- `AssetProvider` - Remote asset downloading and local caching
- `ImagePathProvider` - Dynamic image path resolution for downloaded assets
- `CameraProvider` - Camera state management and initialization
- `PermissionProvider` - Permission status tracking

### Key Dependencies
- **google_mlkit_face_detection**: Core face detection functionality
- **camera**: Camera access and image processing
- **flutter_riverpod**: State management
- **flutter_screen_recording**: Screen recording functionality
- **ffmpeg_kit_flutter_new**: Video processing and cropping
- **dio**: HTTP client for remote asset downloading
- **permission_handler**: Runtime permissions
- **google_mobile_ads**: AdMob integration for interstitial ads
- **firebase_core/analytics/crashlytics**: Analytics and crash reporting

### Core Game Architecture

**Ranking Game Flow**
- `RankingGameState` manages 10-slot ranking system with character placement
- `ForeheadRectangleService` calculates precise forehead positioning for AR overlay
- `FilterDataService` handles remote filter categories and character data from Cloudflare R2
- Asset system supports both local fallback images and dynamically downloaded content

**Face Detection Pipeline**
- Optimized ML Kit settings: landmarks enabled, classification/tracking disabled for performance
- Real-time forehead region calculation using facial landmarks (eyes, nose positions)
- Character image overlay with 3D perspective and rotation matching face orientation

**Remote Asset System**
- Master manifest from Cloudflare R2 defines available filter categories
- Individual filter manifests contain character data and asset URLs
- Local caching with fallback to bundled assets
- Dynamic image path resolution through `ImagePathProvider`

### Development Notes
- Primary target platform is Android (iOS secondary)
- Extensive Korean language UI text throughout the app
- Performance monitoring built-in for ML Kit optimization
- Screen recording with automatic camera preview cropping post-processing
- AdMob interstitial ads displayed after recording completion
- 빌드해서 정상작동확인하려고 flutter build apk --debug 하는건 나한테 시키고 너가 하지마라. 내가 하는게 빠르다.
- 한글로 설명해

### Asset Management
- **Remote First**: Assets downloaded from Cloudflare R2 with local caching
- **Fallback System**: Bundled assets used when downloads fail
- **Manifest Structure**: Master manifest → Filter manifests → Character data
- **Cache Services**: `ManifestCacheService` and `AssetCacheService` for performance