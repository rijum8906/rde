# RDE Settings

The Settings application for the Riju Desktop Environment (RDE), built using Flutter.

## Overview

RDE Settings provides a graphical user interface for managing system configurations in the Riju Desktop Environment. It is structured using Clean Architecture principles to keep features decoupled and maintainable.

## Architecture

The project follows a feature-first Clean Architecture approach:
* **`lib/core/`**: Shared utilities, design system tokens, themes, and base classes.
* **`lib/features/`**: Independent functional modules of the application (e.g., Wi-Fi, volume, brightness, theme).
  * Each feature is divided into layers:
    * `presentation/`: UI components, pages, widgets, and state management controllers.
    * `domain/`: Business logic, entities, use cases, and repository interfaces.
    * `data/`: Data models, API/D-Bus client implementations, data sources, and repository concrete implementations.

## Current Features

- **Wi-Fi Configuration**: View and manage wireless connections (scaffold initialized).
- *(Planned)*: Display, Sound, Power, Theme, and Keyboard settings.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (matching the environment SDK version in `pubspec.yaml`)
- Linux build dependencies (e.g., `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`)

### Installation & Setup

1. Fetch dependencies:
   ```bash
   flutter pub get
   ```

2. Run the application in development mode:
   ```bash
   flutter run -d linux
   ```

3. Build a release bundle for Linux:
   ```bash
   flutter build linux
   ```
