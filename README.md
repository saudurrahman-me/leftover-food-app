# Leftover Food App

A Flutter application designed to help reduce food waste by connecting food donors with those in need. The app incorporates a custom on-device AI model for food classification, ensuring data privacy and offline capabilities.

## Features

- **Food Donation & Discovery:** Users can post leftover food with images and location data, making it discoverable for NGOs and individuals.
- **On-Device AI Classification:** Utilizes a custom MobileNetV2 TensorFlow Lite model for local, offline food image classification.
- **Geolocation & Mapping:** Integrated maps for easy location tracking of available food using `flutter_map` and `geolocator`.
- **Firebase Backend:** Secure authentication, Firestore database for posts and user data, and Firebase Storage for media.
- **Admin Dashboard:** Moderation and user management capabilities.

## Tech Stack

- **Frontend:** Flutter & Dart
- **Backend:** Firebase (Authentication, Firestore, Storage)
- **AI/ML:** TensorFlow Lite (MobileNetV2) for on-device image classification
- **Location:** `flutter_map`, `latlong2`, `geolocator`
- **Image Processing:** `image_picker`, `cloudinary_url_gen`

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.8.1 or higher)
- Firebase project configured with Auth, Firestore, and Storage.
- Android Studio or VS Code with Flutter extensions.

### Installation

1. **Clone the repository:**
   ```bash
   git clone <your-repository-url>
   cd leftover_food_app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**
   Ensure you have configured Firebase for your target platforms (Android/iOS/Web) and placed the necessary `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) files in the respective directories.

4. **Run the app:**
   ```bash
   flutter run
   ```

### Running with Firebase Local Emulator

To run the application using Firebase local emulators for testing:

```bash
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

Optional host override for emulator:
```bash
flutter run --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=192.168.x.x
```
