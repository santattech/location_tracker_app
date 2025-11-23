# Location Tracker App

A simplified Flutter location tracking application with OpenStreetMap integration.

## Features

The app has been simplified to 3 main screens:

### 1. Home Screen
- Displays OpenStreetMap using flutter_map
- Shows current location with a blue marker
- Start/Stop trip functionality
- Real-time trip tracking with red polyline
- Distance counter during active trips

### 2. Trip List Screen
- Shows all recorded trips in chronological order
- Displays trip date, start/end times, distance, and duration
- Indicates active trips with a green "Active" chip
- Tap any trip to view details

### 3. Trip Detail Screen
- Shows detailed trip information (date, times, distance, duration)
- Interactive map with the complete trip route
- Trip playback functionality - watch the trip replay on the map
- Start (green) and end (red) markers
- Fit to screen button to view the entire route

## Technical Details

- **Database**: Hive for local storage
- **Maps**: OpenStreetMap via flutter_map
- **Location**: Geolocator for GPS tracking
- **Models**: Trip and TripLocation with Hive adapters

## Getting Started

1. Ensure Flutter is installed
2. Run `flutter pub get` to install dependencies
3. Generate Hive adapters: `flutter pub run build_runner build`
4. Run the app: `flutter run`

## Building APK

1. `flutter clean`
2. `flutter pub get`
3. `flutter build apk --release`

The APK will be available at `build/app/outputs/flutter-apk/app-release.apk`

## Dependencies

- flutter_map: OpenStreetMap integration
- geolocator: GPS location services
- hive: Local database storage
- intl: Date/time formatting
- latlong2: Latitude/longitude calculations