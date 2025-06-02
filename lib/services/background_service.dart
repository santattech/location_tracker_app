import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

void onStart(ServiceInstance service) {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'Location tracking',
      content: 'Service is running in the background',
    );
  }

  Timer.periodic(Duration(seconds: 10), (timer) async {
    Position position = await Geolocator.getCurrentPosition();
    print("Location: ${position.latitude}, ${position.longitude}");
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
  
}
