// App-wide constants for Location Tracker App

class Constants {
  // Shared Preferences Keys
  static const String keyIsFirstLaunch = 'is_first_launch';
  static const String keyIsLocationPermissionGranted = 'is_location_permission_granted';
  static const String keyIsBackgroundLocationEnabled = 'is_background_location_enabled';
  static const String keyLastKnownLatitude = 'last_known_latitude';
  static const String keyLastKnownLongitude = 'last_known_longitude';
  static const String keyLastUpdateTimestamp = 'last_update_timestamp';
  static const String keyTrackingEnabled = 'tracking_enabled';
  
  // Location Settings
  static const int locationUpdateIntervalInSeconds = 30;  // How often to update location
  static const double defaultLatitude = 0.0;
  static const double defaultLongitude = 0.0;
  static const double minimumDistanceFilter = 10.0;  // Minimum distance (in meters) before a location update
  
  // Home Location (you should update these values with your actual home coordinates)
  static const double HOME_LATITUDE = 0.0;  // Replace with your home latitude
  static const double HOME_LONGITUDE = 0.0; // Replace with your home longitude
  static const double HOME_RADIUS = 100.0;  // Radius in meters to consider as "home area"
  
  // Background Service
  static const String backgroundServiceName = 'LocationTrackerService';
  static const String backgroundChannelId = 'location_tracker_channel';
  static const String backgroundChannelName = 'Location Tracking';
  static const String backgroundChannelDescription = 'Used for showing location tracking notifications';
  
  // Notification
  static const int notificationId = 888;
  static const String notificationTitle = 'Location Tracker';
  static const String notificationDescription = 'Tracking your location in background';
  
  // CSV Export
  static const String csvDateFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String csvFileName = 'location_history.csv';
  static const List<String> csvHeaders = ['Timestamp', 'Latitude', 'Longitude', 'Accuracy'];
  
  // Error Messages
  static const String locationPermissionDenied = 'Location permission denied';
  static const String locationServiceDisabled = 'Location services are disabled';
  static const String backgroundLocationDenied = 'Background location permission denied';
  
  // Success Messages
  static const String trackingStarted = 'Location tracking started';
  static const String trackingStopped = 'Location tracking stopped';
  static const String locationUpdated = 'Location updated successfully';
  
  // UI Related
  static const double mapDefaultZoom = 15.0;
  static const int mapAnimationDuration = 500;  // in milliseconds
} 