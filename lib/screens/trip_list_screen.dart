import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import 'trip_detail_screen.dart';

class TripListScreen extends StatelessWidget {
  const TripListScreen({super.key});

  Future<void> _deleteTrip(BuildContext context, Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text('Are you sure you want to delete this trip? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await trip.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip History'),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Trip>('trips').listenable(),
        builder: (context, Box<Trip> box, _) {
          if (box.values.isEmpty) {
            return const Center(
              child: Text('No trips recorded yet'),
            );
          }

          final trips = box.values.toList().reversed.toList();

          return ListView.builder(
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              final duration = trip.endTime != null
                  ? trip.endTime!.difference(trip.startTime)
                  : Duration.zero;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(
                    'Trip ${DateFormat('MMM dd, yyyy').format(trip.startTime)}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start: ${DateFormat('HH:mm').format(trip.startTime)}',
                      ),
                      if (trip.endTime != null)
                        Text(
                          'End: ${DateFormat('HH:mm').format(trip.endTime!)}',
                        ),
                      Text(
                        'Distance: ${(trip.totalDistance / 1000).toStringAsFixed(2)} km',
                      ),
                      if (trip.endTime != null)
                        Text(
                          'Duration: ${duration.inHours}h ${duration.inMinutes % 60}m',
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (trip.endTime == null)
                        const Chip(
                          label: Text('Active'),
                          backgroundColor: Colors.green,
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteTrip(context, trip),
                        ),
                      const Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TripDetailScreen(trip: trip),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
