// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 0;

  @override
  ChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessage(
      id: fields[0] as String?,
      role: fields[1] as String,
      content: fields[2] as String,
      timestamp: fields[3] as DateTime?,
      modelId: fields[4] as String?,
      providerId: fields[5] as String?,
      totalTokens: fields[6] as int?,
      tokenUsageJson: fields[16] as String?,
      conversationId: fields[7] as String,
      isStreaming: fields[8] as bool,
      reasoningText: fields[9] as String?,
      reasoningStartAt: fields[10] as DateTime?,
      reasoningFinishedAt: fields[11] as DateTime?,
      translation: fields[12] as String?,
      reasoningSegmentsJson: fields[13] as String?,
      groupId: fields[14] as String?,
      version: (fields[15] as int?) ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.modelId)
      ..writeByte(5)
      ..write(obj.providerId)
      ..writeByte(6)
      ..write(obj.totalTokens)
      ..writeByte(16)
      ..write(obj.tokenUsageJson)
      ..writeByte(7)
      ..write(obj.conversationId)
      ..writeByte(8)
      ..write(obj.isStreaming)
      ..writeByte(9)
      ..write(obj.reasoningText)
      ..writeByte(10)
      ..write(obj.reasoningStartAt)
      ..writeByte(11)
      ..write(obj.reasoningFinishedAt)
      ..writeByte(12)
      ..write(obj.translation)
      ..writeByte(13)
      ..write(obj.reasoningSegmentsJson)
      ..writeByte(14)
      ..write(obj.groupId)
      ..writeByte(15)
      ..write(obj.version);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
