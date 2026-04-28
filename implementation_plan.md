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

### Phase 5 — Project Bootstrap Commands

Run these commands in order from project root (`/Users/ademic/Downloads/campusnav`):

```bash
# 1) Confirm Flutter is available
flutter --version
flutter doctor

# 2) Create project only if not already initialized
flutter create --org com.oaunavigator --project-name oau_navigator .

# 3) Resolve packages
flutter pub get

# 4) Verify baseline app starts
flutter run
```

Milestone gate:
- `flutter doctor` has no blocking issues.
- `flutter pub get` completes with no dependency conflicts.

---

### Phase 6 — Config & Secrets

#### Token strategy (default)
Use runtime injection with `--dart-define` so no token is committed:

```bash
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token_here
```

Implementation notes:
- Read token in `lib/main.dart` (or `lib/app.dart`) from `const String.fromEnvironment('MAPBOX_ACCESS_TOKEN')`.
- Pass token into map initialization used by `lib/features/map/map_screen.dart`.
- Never hardcode token in source or commit it into `android/local.properties`.

Expected behavior when token is missing:
- Show a blocking in-app error state: "Mapbox token missing. Run with --dart-define=MAPBOX_ACCESS_TOKEN=...".
- Disable map/routing actions until token is provided.

Profile/debug run examples:

```bash
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token_here
flutter run --profile --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token_here
```

---

### Phase 7 — Incremental Delivery Order

Build in strict dependency order:

1. **Core models + services**
   - `lib/core/models/landmark.dart`
   - `lib/core/models/saved_location.dart`
   - `lib/core/services/landmark_service.dart`
   - `lib/core/services/location_service.dart`
   - `lib/core/services/routing_service.dart`
   - `lib/core/services/storage_service.dart`
   - `assets/data/landmarks.json`
2. **Map shell**
   - `lib/features/map/map_provider.dart`
   - `lib/features/map/map_screen.dart`
3. **Search feature**
   - `lib/features/search/search_provider.dart`
   - `lib/features/search/search_screen.dart`
4. **Navigation/routing feature**
   - `lib/features/navigation/navigation_provider.dart`
   - `lib/features/navigation/navigation_screen.dart`
5. **Nearby feature**
   - `lib/features/nearby/nearby_provider.dart`
   - `lib/features/nearby/nearby_screen.dart`
6. **Saved/bookmarks feature**
   - `lib/features/saved/saved_provider.dart`
   - `lib/features/saved/saved_screen.dart`
7. **Shared UI and app shell integration**
   - `lib/widgets/landmark_card.dart`
   - `lib/widgets/category_chip.dart`
   - `lib/widgets/route_info_panel.dart`
   - `lib/app.dart`

---

### Phase 8 — Test Strategy

#### Service and model tests
- `test/core/landmark_service_test.dart`
  - loads and parses `assets/data/landmarks.json`
  - validates category filtering and query matching
- `test/core/storage_service_test.dart`
  - add/remove/getAll/contains for saved locations
- `test/core/routing_service_test.dart`
  - handles success and API error responses cleanly

#### Widget/feature smoke tests
- `test/features/search/search_screen_test.dart` for render + filter behavior
- `test/features/saved/saved_screen_test.dart` for empty and populated states
- `test/features/map/map_screen_smoke_test.dart` for safe token-missing fallback state

#### Manual acceptance checks
- map renders centered on OAU after token injection
- search returns relevant landmarks with category filters
- route polyline displays with distance and ETA
- saved locations persist after restart
- off-campus simulation disables campus-specific affordances

---

### Phase 9 — Packaging & Release Readiness (Android)

#### Android identity and permissions
- Confirm package/application id in `android/app/build.gradle`.
- Add runtime permissions:
  - `ACCESS_FINE_LOCATION`
  - `ACCESS_COARSE_LOCATION`
  - internet/network permissions required by map and directions APIs.

#### Branding and startup polish
- app icon + splash setup for Android resources.
- production app name and launcher metadata.

#### Build outputs

```bash
flutter analyze
flutter test
flutter build apk --debug --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token_here
flutter build apk --release --dart-define=MAPBOX_ACCESS_TOKEN=pk.your_token_here
```

#### Install validation
- install debug APK on physical Android device.
- launch app and validate map, search, routing, nearby, and saved flows.

---

## Assumptions and Defaults (Execution)

- Token handling defaults to `--dart-define=MAPBOX_ACCESS_TOKEN=...`.
- Delivery target is Android-first for MVP; iOS is deferred until Android gates pass.

---

## Open Questions (Optional)

> [!IMPORTANT]
> **Do you have a Mapbox Access Token?**
> Without it, the map cannot render and routes cannot be fetched. If you don't have one, register for free at [mapbox.com](https://account.mapbox.com) — the free tier is generous and sufficient for MVP.

> [!NOTE]
> Android-first is assumed for MVP. iOS enablement can be scheduled as a follow-up phase after Android release readiness.

---

## Verification Plan

### Automated
- `flutter analyze` — zero lint errors
- `flutter test` — all tests pass
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
| Tests | `flutter test` | All tests pass |
| Debug build | `flutter build apk --debug` | Exit code 0 |

---

## Risk Controls

- **Token misconfiguration fallback:** fail fast with in-app instruction when `MAPBOX_ACCESS_TOKEN` is empty or invalid.
- **Network resilience:** show retry state and user-friendly error messaging when Mapbox Directions requests fail on poor/offline networks.
- **JSON schema integrity:** validate required fields (`id`, `name`, `category`, `latitude`, `longitude`) during asset load and skip/report malformed entries.

---

## Definition of Done

- Flutter environment healthy (`flutter doctor` has no critical blockers).
- Dependencies resolved (`flutter pub get` with zero conflicts).
- Static analysis clean (`flutter analyze` with zero issues).
- Test suite green (`flutter test` passes).
- Android debug build succeeds (`flutter build apk --debug` exits 0).
- Core user journeys verified manually: map render, search, route, nearby, saved persistence.
