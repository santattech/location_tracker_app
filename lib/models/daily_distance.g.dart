// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_distance.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyDistanceAdapter extends TypeAdapter<DailyDistance> {
  @override
  final int typeId = 0;

  @override
  DailyDistance read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyDistance(
      date: fields[0] as String,
      distance: fields[1] as double,
      lastUpdated: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DailyDistance obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.distance)
      ..writeByte(2)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyDistanceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
