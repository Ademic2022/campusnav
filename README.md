# OAU Campus Navigator 🗺️

A comprehensive Flutter application designed to help students, staff, and visitors navigate the Obafemi Awolowo University (OAU) campus seamlessly.

## ✨ Features

* **Interactive Campus Map**: High-quality Mapbox map complete with custom pins and overlays uniquely tailored for OAU campus locations.
* **Smart Routing**: Get accurate point-to-point directions around campus with support for both walking and driving-traffic profiles.
* **Categorized Discovery**: Easily find what you're looking for by filtering through carefully curated categories: Hostels, Faculties, Lecture Halls, Banks, Food spots, and more.
* **Fast Offline Search**: Instant search functionality relying on bundled local data to quickly find specific campus buildings and departments without high data usage.
* **Save Favorites**: Bookmark frequently visited locations (like your department or hostel) for quick access.
* **Nearby Places**: Discover important landmarks dynamically based on your current physical location on campus.

## 🛠️ Technologies Used

* **Framework**: [Flutter](https://flutter.dev)
* **Mapping & Routing**: Mapbox Maps SDK & Mapbox Directions API
* **State Management**: Provider
* **Navigation**: GoRouter
* **Location Handling**: Geolocator

## 🚀 Getting Started

### Prerequisites

* [Flutter SDK](https://docs.flutter.dev/get-started/install)
* A valid [Mapbox Access Token](https://account.mapbox.com/) 

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Ademic2022/campusnav.git
   cd campusnav
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Mapbox Token**
   Configure your Mapbox public/secret tokens according to the standard Mapbox Maps SDK setup guidelines for iOS (`.netrc`) and Android (`gradle.properties`). You must supply your token inside the app to fetch routes properly.

4. **Run the App**
   ```bash
   flutter run
   ```

## 📱 Screenshots

*(Feel free to add your app's screenshots here!)*

## 📄 License & Notes

Developed as an aid for OAU campus navigation. Landmark coordinate data is pre-bundled for offline support.
