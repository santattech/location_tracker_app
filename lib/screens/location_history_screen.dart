import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/tracked_location.dart';
import 'map_screen.dart';

class LocationHistoryScreen extends StatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  late Box<TrackedLocation> _locationsBox;
  Map<String, List<TrackedLocation>> _groupedLocations = {};
  String? _selectedDate;

  @override
  void initState() {
    super.initState();
    _locationsBox = Hive.box<TrackedLocation>('locations');
    _loadLocations();
  }

  void _loadLocations() {
    // Group locations by date
    final locations = _locationsBox.values.toList();
    final grouped = <String, List<TrackedLocation>>{};
    
    for (var location in locations) {
      if (!grouped.containsKey(location.date)) {
        grouped[location.date] = [];
      }
      grouped[location.date]!.add(location);
    }

    // Sort locations within each date
    for (var locations in grouped.values) {
      locations.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    // Sort dates in descending order
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedGrouped = <String, List<TrackedLocation>>{};
    for (var date in sortedDates) {
      sortedGrouped[date] = grouped[date]!;
    }

    setState(() {
      _groupedLocations = sortedGrouped;
      if (sortedDates.isNotEmpty && _selectedDate == null) {
        _selectedDate = sortedDates.first;
      }
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('HH:mm:ss').format(timestamp);
  }

  String _formatDate(String date) {
    final DateTime dateTime = DateFormat('yyyy-MM-dd').parse(date);
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Date selector
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _groupedLocations.keys.map((date) {
                  final isSelected = date == _selectedDate;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(_formatDate(date)),
                      onSelected: (selected) {
                        setState(() {
                          _selectedDate = selected ? date : null;
                        });
                      },
                      backgroundColor: isSelected 
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceVariant,
                      labelStyle: TextStyle(
                        color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          // Location list
          Expanded(
            child: _selectedDate == null
                ? const Center(
                    child: Text('Select a date to view locations'),
                  )
                : ListView.builder(
                    itemCount: _groupedLocations[_selectedDate]?.length ?? 0,
                    itemBuilder: (context, index) {
                      final location = _groupedLocations[_selectedDate]![index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            _formatTimestamp(location.timestamp),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            'Lat: ${location.latitude.toStringAsFixed(6)}\nLong: ${location.longitude.toStringAsFixed(6)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.map),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const MapScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 