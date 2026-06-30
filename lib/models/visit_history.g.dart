// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visit_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VisitHistoryAdapter extends TypeAdapter<VisitHistory> {
  @override
  final int typeId = 1;

  @override
  VisitHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VisitHistory(
      id: fields[0] as String,
      locationId: fields[1] as String,
      locationTitle: fields[2] as String,
      visitTime: fields[3] as DateTime,
      viewCount: fields[4] as int? ?? 1,
      clickCount: fields[5] as int? ?? 0,
      durationSeconds: fields[6] as int? ?? 0,
      latitude: fields[7] as double?,
      longitude: fields[8] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, VisitHistory obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.locationId)
      ..writeByte(2)
      ..write(obj.locationTitle)
      ..writeByte(3)
      ..write(obj.visitTime)
      ..writeByte(4)
      ..write(obj.viewCount)
      ..writeByte(5)
      ..write(obj.clickCount)
      ..writeByte(6)
      ..write(obj.durationSeconds)
      ..writeByte(7)
      ..write(obj.latitude)
      ..writeByte(8)
      ..write(obj.longitude);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisitHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
