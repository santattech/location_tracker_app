import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../models/trip.dart';

class TripDetailScreen extends StatefulWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final MapController _mapController = MapController();
  int _currentLocationIndex = 0;
  bool _isPlaying = false;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    if (widget.trip.locations.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitMapToBounds();
      });
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _fitMapToBounds() {
    if (widget.trip.locations.isEmpty) return;

    final points = widget.trip.locations
        .map((loc) => LatLng(loc.latitude, loc.longitude))
        .toList();

    if (points.length == 1) {
      _mapController.move(points.first, 15.0);
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitBounds(bounds, options: const FitBoundsOptions(padding: EdgeInsets.all(20)));
  }

  void _startPlayback() {
    if (widget.trip.locations.isEmpty) return;

    setState(() {
      _isPlaying = true;
      _currentLocationIndex = 0;
    });

    _playbackTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_currentLocationIndex < widget.trip.locations.length - 1) {
        setState(() {
          _currentLocationIndex++;
        });
        
        final currentLocation = widget.trip.locations[_currentLocationIndex];
        _mapController.move(
          LatLng(currentLocation.latitude, currentLocation.longitude),
          _mapController.zoom,
        );
      } else {
        _stopPlayback();
      }
    });
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  Future<void> _exportToKML() async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      final fileName = 'trip_${DateFormat('yyyyMMdd_HHmmss').format(widget.trip.startTime)}.kml';
      final file = File('${directory!.path}/$fileName');

      final kmlContent = _generateKML();
      await file.writeAsString(kmlContent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('KML exported to Downloads: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  String _generateKML() {
    final coordinates = widget.trip.locations
        .map((loc) => '${loc.longitude},${loc.latitude},0')
        .join(' ');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Trip ${DateFormat('MMM dd, yyyy HH:mm').format(widget.trip.startTime)}</name>
    <description>Distance: ${(widget.trip.totalDistance / 1000).toStringAsFixed(2)} km</description>
    <Placemark>
      <name>Trip Route</name>
      <LineString>
        <coordinates>$coordinates</coordinates>
      </LineString>
    </Placemark>
  </Document>
</kml>''';
  }

  Future<void> _uploadToGoogleDrive() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
      final account = await googleSignIn.signIn();
      
      if (account == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Sign-In cancelled')),
          );
        }
        return;
      }

      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      final fileName = 'trip_${DateFormat('yyyyMMdd_HHmmss').format(widget.trip.startTime)}.kml';
      final kmlContent = _generateKML();

      final driveFile = drive.File();
      driveFile.name = fileName;
      driveFile.parents = ['appDataFolder'];

      final media = drive.Media(
        Stream.fromIterable([kmlContent.codeUnits]),
        kmlContent.length,
      );

      await driveApi.files.create(driveFile, uploadMedia: media);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trip uploaded to Google Drive: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Drive upload failed: $e')),
        );
      }
    }
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.trip.endTime != null
        ? widget.trip.endTime!.difference(widget.trip.startTime)
        : Duration.zero;

    return Scaffold(
      appBar: AppBar(
        title: Text('Trip ${DateFormat('MMM dd, yyyy').format(widget.trip.startTime)}'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Start: ${DateFormat('HH:mm').format(widget.trip.startTime)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (widget.trip.endTime != null)
                        Text(
                          'End: ${DateFormat('HH:mm').format(widget.trip.endTime!)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Distance: ${(widget.trip.totalDistance / 1000).toStringAsFixed(2)} km',
                      ),
                      if (widget.trip.endTime != null)
                        Text(
                          'Duration: ${duration.inHours}h ${duration.inMinutes % 60}m',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Locations: ${widget.trip.locations.length}'),
                ],
              ),
            ),
          ),
          Expanded(
            child: widget.trip.locations.isEmpty
                ? const Center(child: Text('No location data available'))
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: LatLng(
                        widget.trip.locations.first.latitude,
                        widget.trip.locations.first.longitude,
                      ),
                      zoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.location_tracker_app',
                      ),
                      if (widget.trip.locations.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: widget.trip.locations
                                  .take(_currentLocationIndex + 1)
                                  .map((loc) => LatLng(loc.latitude, loc.longitude))
                                  .toList(),
                              color: Colors.blue,
                              strokeWidth: 3.0,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          // Start marker
                          Marker(
                            point: LatLng(
                              widget.trip.locations.first.latitude,
                              widget.trip.locations.first.longitude,
                            ),
                            builder: (context) => const Icon(
                              Icons.play_arrow,
                              color: Colors.green,
                              size: 30,
                            ),
                          ),
                          // End marker
                          if (widget.trip.locations.length > 1)
                            Marker(
                              point: LatLng(
                                widget.trip.locations.last.latitude,
                                widget.trip.locations.last.longitude,
                              ),
                              builder: (context) => const Icon(
                                Icons.stop,
                                color: Colors.red,
                                size: 30,
                              ),
                            ),
                          // Current position during playback
                          if (_isPlaying && _currentLocationIndex < widget.trip.locations.length)
                            Marker(
                              point: LatLng(
                                widget.trip.locations[_currentLocationIndex].latitude,
                                widget.trip.locations[_currentLocationIndex].longitude,
                              ),
                              builder: (context) => const Icon(
                                Icons.my_location,
                                color: Colors.orange,
                                size: 25,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
          if (widget.trip.locations.length > 1)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isPlaying ? _stopPlayback : _startPlayback,
                        icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                        label: Text(_isPlaying ? 'Stop' : 'Play Trip'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _fitMapToBounds,
                        icon: const Icon(Icons.fit_screen),
                        label: const Text('Fit to Screen'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _exportToKML,
                        icon: const Icon(Icons.download),
                        label: const Text('Export KML'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _uploadToGoogleDrive,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Upload to Drive'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
