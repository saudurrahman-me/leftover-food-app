<div align="center">
  <h1>🍲 Leftover Food App</h1>
  <p><strong>Reducing Food Waste & Empowering Communities Through AI</strong></p>

  <p>
    <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
    <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
    <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase" />
    <img src="https://img.shields.io/badge/TensorFlow-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white" alt="TensorFlow Lite" />
  </p>
</div>

---

A Flutter application designed to help reduce food waste by connecting food donors with those in need. The app incorporates a custom on-device AI model for food classification, ensuring data privacy and offline capabilities.

## ✨ Features

* **🥘 Food Donation & Discovery:** Users can post leftover food with images and location data, making it discoverable for NGOs and individuals.
* **🧠 On-Device AI Classification:** Utilizes a custom MobileNetV2 TensorFlow Lite model for local, offline food image classification without relying on external cloud APIs.
* **📍 Geolocation & Mapping:** Integrated maps for easy location tracking of available food using `flutter_map` and `geolocator`.
* **☁️ Firebase Backend:** Secure authentication, Firestore database for posts and user data, and Firebase Storage for media.
* **🛡️ Admin Dashboard:** Built-in dashboard for system moderation, content curation, and user management capabilities.

## 🛠 Tech Stack

### Frontend
* **Framework:** [Flutter](https://flutter.dev/) (v3.8.1+)
* **Language:** Dart
* **Maps:** `flutter_map`, `latlong2`, `geolocator`
* **Image Processing:** `image_picker`, `cloudinary_url_gen`

### Backend & AI
* **Database & Auth:** Firebase (Authentication, Firestore, Storage)
* **Machine Learning:** TensorFlow Lite (`tflite_flutter`)
* **Model Architecture:** Custom trained MobileNetV2 (10-epoch cycle with early stopping)

---

## 🚀 Getting Started

### Prerequisites

* [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and configured on your path.
* Firebase project set up with Authentication, Firestore, and Storage enabled.
* Android Studio or VS Code with the Flutter extension.

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/saudurrahman-me/leftover-food-app.git
   cd leftover_food_app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**
   Ensure you have configured Firebase for your target platforms. You will need to place your `google-services.json` in the `android/app` directory and `GoogleService-Info.plist` in the `ios/Runner` directory.

4. **Run the application:**
   ```bash
   flutter run
   ```

### 🧪 Testing with Firebase Emulators

To run the application using Firebase local emulators without affecting production data:

```bash
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

Optional host override for emulator (useful for physical devices connecting to your dev machine):
```bash
flutter run --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=192.168.x.x
```

## 📂 Project Structure

```text
lib/
├── admin/              # Admin dashboard panels & management screens
├── core/               # Global configs, themes, and shared utilities
├── services/           # Backend services (Firebase, AI Dataset, Expired Posts)
└── main.dart           # Application entry point
```

## 🤝 Contributing

Contributions are welcome! Please fork the repository and open a pull request with your changes. 

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request
