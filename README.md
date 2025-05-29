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
Hive is indeed a more efficient solution for Flutter apps as it's a lightweight and fast NoSQL database.
First, let me explain the changes we'll need to make:
Add Hive dependencies to the project
Create a data model for storing location data
Initialize Hive and modify the storage/retrieval logic

Now we need to generate the Hive adapter code. Run the following command in your terminal:

`flutter pub run build_runner build`

This will help you to create part file. Let me explain the purpose of part 'daily_distance.g.dart'; in our code.
This line is related to code generation in Dart/Flutter, specifically for the Hive database library that you're using. Here's what it means:
The .g.dart suffix indicates that this is a generated file. The 'g' stands for "generated".
In our code, we're using Hive annotations (@HiveType and @HiveField) to define a data model class DailyDistance. However, these annotations alone don't create the necessary boilerplate code for Hive to work with your class.

The part directive tells Dart that daily_distance.g.dart is a partial implementation of this library. The generated file will contain additional code needed by Hive to:
1. Register your class with Hive
2. Handle serialization (converting your object to/from binary format for storage)
3. Create type adapters that Hive uses to read and write your custom objects
4. The daily_distance.g.dart file is automatically generated when you run the Hive code generator using the command:


### How to release apk

1. `flutter clean`
2. `flutter pub get`
3. `flutter build apk --release`
the build should be availaable at 
`Built build\app\outputs\flutter-apk\app-release.apk (40.2MB). `