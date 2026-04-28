# OAU Navigator — Flutter MVP Implementation Plan

A mobile campus navigation app for Obafemi Awolowo University (OAU), Ile-Ife, Nigeria. Built fully client-side in Flutter with Mapbox for rendering and routing, Hive CE for local persistence, and a bundled JSON landmark database.

---

## User Review Required

> [!IMPORTANT]
> You will need a **Mapbox Access Token** to use the Mapbox Maps SDK and Directions API.
> Get a free token at [mapbox.com](https://account.mapbox.com/). You'll need it before the app can render maps or compute routes.

> [!WARNING]
> Flutter is **not currently installed** on your machine. The first phase of execution will install it via Homebrew. This requires an active internet connection and may take 5–10 minutes.

> [!NOTE]
> This plan uses `hive_ce_flutter` (the community-maintained fork) instead of the archived `hive_flutter` package, as `hive_flutter` has not been updated since 2021.

---

## Tech Stack

| Layer | Package | Version |
|---|---|---|
| Framework | Flutter | stable (via Homebrew) |
| Map Rendering | `mapbox_maps_flutter` | ^2.22.0 |
| GPS Location | `geolocator` | ^14.0.2 |
| Local Storage | `hive_ce_flutter` | ^2.3.4 |
| HTTP (Directions) | `dio` | ^5.7.0 |
| State Management | `provider` | ^6.1.2 |
| Routing (app nav) | `go_router` | ^14.2.0 |
| Utils | `latlong2` | ^0.9.1 |

---

## App Architecture

Feature-based clean architecture:

```
lib/
├── main.dart
├── app.dart                         # MaterialApp + GoRouter + Providers
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   └── oau_bounds.dart          # Campus bounding box constants
│   ├── models/
│   │   ├── landmark.dart            # Landmark data model + fromJson
│   │   └── saved_location.dart      # Hive entity for bookmarks
│   └── services/
│       ├── landmark_service.dart    # Loads + searches landmarks.json
│       ├── location_service.dart    # GPS + geofence logic
│       ├── routing_service.dart     # Mapbox Directions API calls
│       └── storage_service.dart     # Hive CE read/write for saved locations
├── features/
│   ├── map/
│   │   ├── map_screen.dart          # Main screen: map + FAB + bottom sheet
│   │   └── map_provider.dart        # MapboxMap controller state
│   ├── search/
│   │   ├── search_screen.dart       # Full-screen search with results list
│   │   └── search_provider.dart     # Query + filtered results state
│   ├── navigation/
│   │   ├── navigation_screen.dart   # Route overlay + distance/ETA panel
│   │   └── navigation_provider.dart # Route state + step tracking
│   ├── nearby/
│   │   ├── nearby_screen.dart       # Bottom sheet with category tabs
│   │   └── nearby_provider.dart     # Sorted nearby results
│   └── saved/
│       ├── saved_screen.dart        # Bookmarked locations list
│       └── saved_provider.dart      # Hive-backed saved list state
└── widgets/
    ├── landmark_card.dart
    ├── category_chip.dart
    └── route_info_panel.dart
assets/
└── data/
    └── landmarks.json               # Bundled OAU landmark database
```

---

## Screens

### 1. Map Screen (Home)
- Full-screen Mapbox map centered on OAU campus
- Dark-themed map style (`mapbox://styles/mapbox/dark-v11`)
- Blue GPS dot showing user's current position (geofenced to campus)
- Floating search bar at the top (taps → Search Screen)
- Bottom navigation bar: Map | Nearby | Saved
- FAB: "My Location" button to re-center map

### 2. Search Screen
- Slide-up modal / full-screen
- Real-time search across `landmarks.json` (fuzzy match on name + category)
- Category filter chips: All | Hostels | Faculties | Admin | Food | Banks | Health
- Result cards showing name, category badge, and distance from current position
- Tap result → drops pin on map + shows "Get Directions" sheet

### 3. Navigation Screen
- Mapbox route polyline drawn on map (walking = blue, driving = orange)
- Bottom panel: Distance, ETA, mode toggle (walk/drive)
- Step-by-step directions list (expandable)
- "End Navigation" button

### 4. Nearby Screen (Bottom Sheet)
- Opens as sliding bottom sheet from Map Screen
- Tabs: All | Food | ATMs | Hostels | Health | Halls
- Cards sorted by distance from current GPS, showing walk time estimate

### 5. Saved Locations Screen
- Grid/list of bookmarked landmarks persisted via Hive CE
- Swipe to delete, tap to navigate
- Empty state with friendly illustration

---

## Data: `landmarks.json`

Comprehensive seed file covering priority landmarks from the PRD:

**Categories:**
- `hostel` — Angola, Fajuyi, Awolowo, Moremi, ETF, etc.
- `faculty` — Technology, Science, Administration, Law, etc.
- `admin` — Senate Building, Bursary, Registry, Vice-Chancellor's Office
- `health` — OAU Teaching Hospital, Health Center
- `food` — Cafeterias/restaurants across campus
- `atm` — GTBank, First Bank, UBA ATMs on campus
- `gate` — Main gate, Back gate, Parakin gate
- `sports` — Sports complex, Stadium
- `lecture` — Major lecture halls (LT1, LT2, Awo Auditorium, etc.)

~60–80 seed landmarks with accurate approximate coordinates.

---

## Proposed Changes

### Phase 0 — Environment Setup

#### [SYSTEM] Install Flutter via Homebrew
```bash
brew install --cask flutter
flutter doctor
```

---

### Phase 1 — Project Scaffold

#### [NEW] Flutter project at `campusnav/`
```bash
flutter create --org com.oaunavigator --project-name oau_navigator .
```

#### [NEW] pubspec.yaml
Full dependency list with all packages above + asset declaration for `assets/data/landmarks.json`.

#### [NEW] assets/data/landmarks.json
~70 OAU campus landmarks with coordinates, categories, and descriptions.

---

### Phase 2 — Core Layer

#### [NEW] core/constants/app_colors.dart
Dark-mode first color system: deep navy background, amber accent, white text.

#### [NEW] core/constants/oau_bounds.dart
Campus center `(7.5174, 4.5228)`, SW/NE corners, geofence radius constants.

#### [NEW] core/models/landmark.dart
Serializable model with `fromJson`, `toJson`, distance calculation method.

#### [NEW] core/models/saved_location.dart
Hive CE `TypeAdapter` for persisting bookmarked landmarks locally.

#### [NEW] core/services/landmark_service.dart
- Loads `landmarks.json` from assets on first call (cached in memory)
- `search(String query)` — fuzzy match on name and category
- `getByCategory(String category)` — filtered list
- `sortByDistance(List<Landmark>, LatLng userPos)` — using `latlong2`

#### [NEW] core/services/location_service.dart
- Wraps `geolocator` package
- Permission request flow
- Stream of `Position` updates
- `isOnCampus(Position)` — geofence check vs. OAU bounding box

#### [NEW] core/services/routing_service.dart
- Calls `https://api.mapbox.com/directions/v5/mapbox/{profile}/{coords}`
- Returns decoded GeoJSON route geometry + distance + duration
- Supports `walking` and `driving` profiles

#### [NEW] core/services/storage_service.dart
- Hive CE box for `SavedLocation`
- CRUD: add, remove, getAll, contains

---

### Phase 3 — Features

#### [NEW] features/map/map_screen.dart + map_provider.dart
Main entry point. Hosts MapboxMap widget, handles camera, pin placement.

#### [NEW] features/search/search_screen.dart + search_provider.dart
Search UI with debounced text input (300ms), category chips, result cards.

#### [NEW] features/navigation/navigation_screen.dart + navigation_provider.dart
Fetches route, renders polyline on Mapbox map, shows step panel.

#### [NEW] features/nearby/nearby_screen.dart + nearby_provider.dart
DraggableScrollableSheet showing sorted nearby places by category.

#### [NEW] features/saved/saved_screen.dart + saved_provider.dart
Hive-backed bookmarks list screen.

---

### Phase 4 — Polish

#### [NEW] widgets/landmark_card.dart
Reusable card used in search results, nearby list, and saved list.

#### [NEW] widgets/category_chip.dart
Styled filter chip with icon + label per category.

#### App theming
Dark navy + amber accent design system. Custom `ThemeData` with Google Fonts (Inter).

---

## Open Questions

> [!IMPORTANT]
> **Do you have a Mapbox Access Token?**
> Without it, the map cannot render and routes cannot be fetched. If you don't have one, register for free at [mapbox.com](https://account.mapbox.com) — the free tier is generous and sufficient for MVP.

> [!NOTE]
> **Target platform priority**: Should I configure both Android and iOS, or focus on Android first? (iOS requires Xcode to be installed and configured.)

---

## Verification Plan

### Automated
- `flutter analyze` — zero lint errors
- `flutter build apk --debug` — successful APK build

### Manual (Browser Preview)
- Launch app on emulator/device via `flutter run`
- Verify map renders centered on OAU campus
- Verify search returns relevant landmarks
- Verify route polyline draws between two points
- Verify saved locations persist after app restart
- Verify geofence hides GPS dot when simulating coordinates outside campus

### Build Milestone Gates
| Gate | Command | Pass Condition |
|---|---|---|
| Flutter setup | `flutter doctor` | No critical errors |
| Dependencies resolve | `flutter pub get` | Zero conflicts |
| Code analysis | `flutter analyze` | Zero issues |
| Debug build | `flutter build apk --debug` | Exit code 0 |
