# location_tracker_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

### Adding hive
I'll help you modify the app to use Hive instead of SharedPreferences for data storage. Hive is indeed a more efficient solution for Flutter apps as it's a lightweight and fast NoSQL database.
First, let me explain the changes we'll need to make:
Add Hive dependencies to the project
Create a data model for storing location data
Initialize Hive and modify the storage/retrieval logic

Now we need to generate the Hive adapter code. Run the following command in your terminal:
flutter pub run build_runner build