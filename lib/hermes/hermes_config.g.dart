// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hermes_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HermesBackendBoxAdapter extends TypeAdapter<HermesBackendBox> {
  @override
  final int typeId = 100;

  @override
  HermesBackendBox read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HermesBackendBox(
      id: fields[0] as String,
      name: fields[1] as String,
      url: fields[2] as String,
      authMode: fields[3] as String,
      token: fields[4] as String?,
      profile: fields[5] as String?,
      addedAt: fields[6] as DateTime,
      lastConnectedAt: fields[7] as DateTime?,
      lastError: fields[8] as String?,
      isActive: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HermesBackendBox obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.url)
      ..writeByte(3)
      ..write(obj.authMode)
      ..writeByte(4)
      ..write(obj.token)
      ..writeByte(5)
      ..write(obj.profile)
      ..writeByte(6)
      ..write(obj.addedAt)
      ..writeByte(7)
      ..write(obj.lastConnectedAt)
      ..writeByte(8)
      ..write(obj.lastError)
      ..writeByte(9)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HermesBackendBoxAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
