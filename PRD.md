# Product Requirements Document (PRD)

## Product Name

**OAU Navigator**

## Version

1.0 — MVP

## Last Updated

April 2026

---

## Overview

OAU Navigator is a mobile application that helps students, staff, visitors, and freshers navigate around **Obafemi Awolowo University (OAU)** campus in Ile-Ife, Nigeria.

The app solves the common problem of people getting lost while trying to locate lecture halls, hostels, departments, administrative buildings, restaurants, banks, and other important places within OAU.

Users can search for a location and receive the shortest walking or driving route within the campus — all without needing an internet connection for core features.

---

## Problem Statement

OAU is one of Nigeria's largest university campuses (~11,861 acres) with many internal roads, hostels, faculties, and landmarks. Common problems include:

- Freshers getting lost during registration week
- Students struggling to find unfamiliar lecture venues
- Visitors unable to locate administrative offices
- Difficulty finding nearby services like ATMs, cafeterias, and health centers
- Existing map apps (Google Maps, Apple Maps) do not accurately map internal campus roads and walkways

---

## Goals

Build a simple, fast, and reliable navigation app that helps users:

- Search for locations within OAU campus
- View a detailed campus map
- Get directions to any destination on campus
- Discover nearby places and services
- Reduce time wasted finding locations

---

## Target Users

### Primary Users

- Fresh students (freshers)
- Returning students
- Visitors and guests
- Staff members
- Event attendees

### Secondary Users

- Delivery riders entering campus
- Parents visiting students
- Campus vendors

---

## MVP Features

### 1. Search Locations

Users can search for any campus location by name or category.

**Searchable categories:**
- Hostels (e.g. Angola Hall, Moremi Hall, Fajuyi Hall)
- Faculties (e.g. Faculty of Technology, Faculty of Science)
- Departments
- Lecture halls
- Administrative offices (e.g. Senate Building, Bursary)
- Restaurants and cafeterias
- Banks and ATMs
- Health center

### 2. Campus Map

Display OAU campus map showing:
- Internal roads and walkways
- Buildings and landmarks
- Key points of interest
- User's current location (GPS dot geofenced to campus boundary)

### 3. Route Navigation

Users can select a destination and receive the optimal route.

**Navigation modes:**
- Walking
- Driving

### 4. Nearby Places

Show places near the user's current location, filtered by category:
- Cafeterias
- ATMs
- Hostels
- Health center
- Lecture halls

### 5. Saved Locations

Users can bookmark frequently visited places for quick access.

**Examples:**
- My hostel
- My faculty
- My department

---

## Architecture Decision: No Backend for MVP

After technical evaluation, the MVP will be built **entirely client-side** with no custom backend server. This decision is based on the following:

| Feature | Implementation |
|---|---|
| Campus map rendering | Mapbox Flutter SDK |
| Location search | Local JSON landmark database bundled in app |
| Route generation | Mapbox Directions API |
| Nearby places | On-device calculation using Turf.dart |
| Saved locations | Local device storage (Hive) |
| Geofencing | On-device using campus bounding box |

**OAU Campus Boundary (Bounding Box):**
```
Center:     7.5174° N, 4.5228° E
SW Corner:  ~7.490° N, 4.490° E
NE Corner:  ~7.540° N, 4.560° E
Radius:     ~3–4 km from center
```

**Landmark Data Format:**
```json
[
  {
    "id": 1,
    "name": "Angola Hall",
    "category": "hostel",
    "lat": 7.5183,
    "lng": 4.5261,
    "description": "Male student hostel"
  },
  {
    "id": 2,
    "name": "Faculty of Technology",
    "category": "faculty",
    "lat": 7.5201,
    "lng": 4.5189,
    "description": "Engineering and Technology faculty"
  }
]
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile Framework | Flutter |
| Map Rendering | Mapbox SDK (Flutter) |
| Routing | Mapbox Directions API |
| Local Data | JSON file bundled in app |
| Local Storage | Hive |
| Backend | None (MVP) |

---

## Functional Requirements

- Detect user's GPS location and lock it to campus boundaries
- Full-text search across landmark database
- Route generation between two campus points
- Distance and ETA display for routes
- Category-based filtering for nearby places
- Save and retrieve favourite locations locally
- Geofence: restrict map and search to OAU campus only

---

## Non-Functional Requirements

- Search response under 300ms
- Accurate routing on internal campus roads
- Mobile-friendly UI (Android and iOS)
- Low battery consumption
- Core features work offline (map tiles cached, landmark data bundled)
- Supports poor internet conditions

---

## Data Collection Strategy

To map OAU accurately, landmark coordinates will be collected through:

- OpenStreetMap (OSM) — OAU campus is partially mapped
- Manual GPS surveys of major buildings
- Google Maps cross-referencing
- Student contributor submissions (post-MVP)

**Priority landmarks to map first:**
1. All student hostels
2. All faculty buildings
3. Senate Building and Admin Block
4. Health Center
5. Banks and ATMs
6. Major cafeterias
7. Main gate and secondary gates
8. Sports complex

---

## User Stories

**As a fresher,**
I want to find my lecture hall quickly
so that I don't miss my first classes.

**As a visitor,**
I want directions to the administrative offices
so I can arrive at my meeting on time.

**As a student,**
I want to save my hostel and faculty
so navigation becomes faster every time.

**As a delivery rider,**
I want to find a specific hostel on campus
so I can complete deliveries without asking around.

---

## Future Features (Post-MVP)

### Real-time Shuttle Tracking
Track campus shuttle buses live. *(Requires backend)*

### Voice Navigation
Turn-by-turn voice guidance for walking routes.

### Event Navigation
Navigate users to event venues with temporary pins.

### Business Listings
Allow campus businesses to list and manage their own locations. *(Requires backend)*

### Student Contributions
Crowdsource map corrections and new location additions. *(Requires backend)*

### Multi-University Expansion
Expand the platform to:
- University of Lagos (UNILAG)
- University of Ibadan (UI)
- Covenant University
- FUTA
- Others

---

## When a Backend Becomes Necessary

The backend (Django + PostgreSQL + PostGIS) will be introduced when any of the following features are prioritised:

- Real-time shuttle tracking
- Business listings management
- Cross-device sync for saved locations
- Crowdsourced map contributions
- Analytics dashboard (DAU, search completion, navigation completion)
- Multi-university data management

---

## MVP Development Timeline

| Phase | Task | Output |
|---|---|---|
| Phase 1 | Collect and map all OAU landmark coordinates | landmarks.json |
| Phase 2 | Build search and map display in Flutter | Working map screen |
| Phase 3 | Integrate routing (Mapbox Directions API) | Navigation flow |
| Phase 4 | Add saved locations and nearby places | Full MVP feature set |
| Phase 5 | Beta test with OAU students | User feedback and bug fixes |

---

## Success Metrics

- Number of app downloads
- Daily active users (DAU)
- Search completion rate
- Navigation completion rate
- Average session duration
- User retention at Day 7 and Day 30

---

## Risks

| Risk | Mitigation |
|---|---|
| Inaccurate or missing map data | Manual GPS surveys + OSM data |
| GPS inaccuracies within campus | Geofencing + map matching |
| App not kept up to date | Modular landmark JSON easy to update |
| Low adoption among students | Beta test with freshers during resumption week |

---

## Monetization Opportunities (Future)

- Sponsored business listings (campus shops, restaurants)
- Campus event promotions
- White-label licensing to other Nigerian universities

---

## Long-Term Vision

Become the default navigation platform for university campuses across Nigeria and eventually Africa — starting with OAU.
