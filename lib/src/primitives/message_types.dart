// ignore_for_file: constant_identifier_names

enum MessageType {
  ParseComplete(0x31),
  CommandComplete(0x43),
  Data(0x44),
  ErrorResponse(0x45),
  ServerKeyData(0x4b),
  LogMessage(0x4c),
  Execute(0x4f),
  Parse(0x50),
  AuthenticationOK(0x52),
  Sync(0x53),
  ParameterStatus(0x53),
  CommandDataDescription(0x54),
  ClientHandshake(0x56),
  ReadyForCommand(0x5a),
  ServerHandshake(0x76);

  final int value;
  const MessageType(this.value);
}

final messageTypes = {for (var mType in MessageType.values) mType.value: mType};
