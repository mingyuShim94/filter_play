# GEMINI.md

## Project Overview

This is a Flutter project named `filterplay`. It appears to be a mobile application that allows users to apply filters to a camera feed. The application features face detection using Google's ML Kit, screen recording capabilities, and dynamic downloading of filter assets. State management is handled by Riverpod, and it integrates Firebase for analytics and crash reporting.

The core functionality revolves around selecting a filter from a list, downloading the necessary assets for that filter, and then applying it to the camera view.

## Building and Running

To build and run this project, you will need to have the Flutter SDK installed.

**1. Install Dependencies:**

```bash
flutter pub get
```

**2. Run the Application:**

```bash
flutter run
```

**3. Run Tests:**

```bash
flutter test
```

*(Note: These are the standard commands for a Flutter project. If there are any specific configurations or scripts, they should be added here.)*

## Development Conventions

Based on the file structure and code, the project follows standard Flutter development conventions.

*   **State Management:** The project uses `flutter_riverpod` for state management. Providers are located in the `lib/providers` directory.
*   **Project Structure:** The code is organized into directories based on features, such as `screens`, `services`, `models`, and `widgets`.
*   **UI:** The UI is built with Material Design components. The main theme colors are defined in `lib/constants/theme_colors.dart`.
*   **Asynchronous Operations:** The app heavily relies on asynchronous operations for tasks like downloading assets and interacting with the camera. `Future`s and `async/await` are used extensively.
*   **Error Handling:** The code includes error handling for network requests and other asynchronous operations, with user-facing error dialogs.
