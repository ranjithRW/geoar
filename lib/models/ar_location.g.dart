// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ar_location.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ArLocationAdapter extends TypeAdapter<ArLocation> {
  @override
  final int typeId = 0;

  @override
  ArLocation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArLocation(
      id: fields[0] as String,
      title: fields[1] as String,
      subtitle: fields[2] as String,
      description: fields[3] as String,
      latitude: fields[4] as double,
      longitude: fields[5] as double,
      textMessage: fields[6] as String?,
      imagePath: fields[7] as String?,
      videoPath: fields[8] as String?,
      modelPath: fields[9] as String?,
      category: fields[10] as String,
      createdDate: fields[11] as DateTime,
      updatedDate: fields[12] as DateTime,
      modelType: fields[13] as String? ?? 'default',
    );
  }

  @override
  void write(BinaryWriter writer, ArLocation obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.subtitle)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.latitude)
      ..writeByte(5)
      ..write(obj.longitude)
      ..writeByte(6)
      ..write(obj.textMessage)
      ..writeByte(7)
      ..write(obj.imagePath)
      ..writeByte(8)
      ..write(obj.videoPath)
      ..writeByte(9)
      ..write(obj.modelPath)
      ..writeByte(10)
      ..write(obj.category)
      ..writeByte(11)
      ..write(obj.createdDate)
      ..writeByte(12)
      ..write(obj.updatedDate)
      ..writeByte(13)
      ..write(obj.modelType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArLocationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
