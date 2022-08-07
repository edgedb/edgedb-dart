// ignore_for_file: constant_identifier_names

enum MessageType {
  CommandComplete(0x43),
  Data(0x44),
  ErrorResponse(0x45),
  ServerKeyData(0x4b),
  LogMessage(0x4c),
  Authentication(0x52),
  ParameterStatus(0x53),
  CommandDataDescription(0x54),
  ReadyForCommand(0x5a),
  StateDataDescription(0x73),
  ServerHandshake(0x76);

  final int value;
  const MessageType(this.value);
}

enum ClientMessageType {
  Execute(0x4f),
  Parse(0x50),
  Sync(0x53),
  ClientHandshake(0x56),
  Terminate(0x58),
  AuthenticationSASLInitialReponse(0x70),
  AuthenticationSASLResponse(0x72);

  final int value;
  const ClientMessageType(this.value);
}

final serverMessageTypes = {
  for (var mType in MessageType.values) mType.value: mType
};

final clientMessageTypes = {
  for (var mType in ClientMessageType.values) mType.value: mType
};
