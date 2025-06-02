import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/tracked_location.dart';
import '../models/daily_distance.dart';
import '../models/app_settings.dart';

class BackgroundLocationService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Configure notifications
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'location_tracker_channel',
      'Location Tracking Service',
      description: 'This channel is used for location tracking notifications.',
      importance: Importance.high,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'location_tracker_channel',
        initialNotificationTitle: 'Location Tracker',
        initialNotificationContent: 'Tracking your location...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Initialize Hive
    await Hive.initFlutter();
    Hive.registerAdapter(TrackedLocationAdapter());
    Hive.registerAdapter(DailyDistanceAdapter());
    Hive.registerAdapter(AppSettingsAdapter());

    await Hive.openBox<TrackedLocation>('locations');
    await Hive.openBox<DailyDistance>('distances');
    await Hive.openBox<AppSettings>('settings');

    Position? lastPosition;
    double totalDistance = 0.0;

    // Load today's distance
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final distancesBox = Hive.box<DailyDistance>('distances');
    final dailyDistance = distancesBox.get(today);
    if (dailyDistance != null) {
      totalDistance = dailyDistance.distance;
    }

    Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        Position newPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Update settings
        final settingsBox = Hive.box<AppSettings>('settings');
        final settings = settingsBox.get('current') ?? AppSettings();
        settings.lastTrackingUpdate = DateTime.now();
        await settingsBox.put('current', settings);

        // Save location
        final location = TrackedLocation.fromPosition(newPosition);
        final locationsBox = Hive.box<TrackedLocation>('locations');
        final todayLocations = locationsBox.values
            .where((loc) => loc.date == location.date)
            .length;

        if (todayLocations < 8640) { // Max locations per day
          await locationsBox.add(location);
        }

        // Calculate distance
        if (lastPosition != null) {
          double distance = Geolocator.distanceBetween(
            lastPosition!.latitude,
            lastPosition!.longitude,
            newPosition.latitude,
            newPosition.longitude,
          );
          totalDistance += distance;

          // Save daily distance
          final dailyDistance = DailyDistance(
            date: today,
            distance: totalDistance,
            lastUpdated: DateTime.now(),
          );
          await distancesBox.put(today, dailyDistance);
        }

        lastPosition = newPosition;

        // Update notification
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Location Tracker',
            content: 'Distance today: ${(totalDistance / 1000).toStringAsFixed(2)} km',
          );
        }
      } catch (e) {
        print('Error in background service: $e');
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Location Tracker',
            content: 'Error tracking location',
          );
        }
      }
    });
  }
} 