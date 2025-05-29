// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completed_place.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompletedPlaceAdapter extends TypeAdapter<CompletedPlace> {
  @override
  final int typeId = 2;

  @override
  CompletedPlace read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CompletedPlace(
      name: fields[0] as String,
      completedAt: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CompletedPlace obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.completedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompletedPlaceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
