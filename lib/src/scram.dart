import 'dart:convert';
import 'dart:core';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
// ignore: implementation_imports
import 'package:crypto/src/digest_sink.dart';

import 'errors/errors.dart';

const rawNonceLength = 18;

String saslprep(String str) {
  // An actual implementation of SASLPrep requires a Unicode database.
  // One of the most important tasks is to do the NFKC normalization though.
  // usernames/password validation happens on the server side (where
  // SASLPrep is implemented fully) when a role is created, so worst case
  // scenario would be that invalid usernames/passwords can be sent to the
  // server, in which case they will be rejected.
  // TODO
  // return str.normalize("NFKC");
  return str;
}

Uint8List generateNonce([int length = rawNonceLength]) {
  final random = Random.secure();
  final bytes = Uint8List(length);

  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }

  return bytes;
}

List<String> buildClientFirstMessage(Uint8List clientNonce, String username) {
  final bare = 'n=${saslprep(username)},r=${base64.encode(clientNonce)}';
  return ['n,,$bare', bare];
}

class ServerFirstMessage {
  Uint8List nonce;
  Uint8List salt;
  int iterCount;

  ServerFirstMessage(this.nonce, this.salt, this.iterCount);
}

ServerFirstMessage parseServerFirstMessage(String msg) {
  final attrs = msg.split(',');

  if (attrs.length < 3) {
    throw ProtocolError('malformed SCRAM message');
  }

  final nonceAttr = attrs[0];
  if (!nonceAttr.startsWith('r=')) {
    throw ProtocolError('malformed SCRAM message');
  }
  final nonceB64 = nonceAttr.substring(2);
  if (nonceB64.isEmpty) {
    throw ProtocolError('malformed SCRAM message');
  }
  final nonce = base64.decode(nonceB64);

  final saltAttr = attrs[1];
  if (!saltAttr.startsWith('s=')) {
    throw ProtocolError('malformed SCRAM message');
  }
  final saltB64 = saltAttr.substring(2);
  if (saltB64.isEmpty) {
    throw ProtocolError('malformed SCRAM message');
  }
  final salt = base64.decode(saltB64);

  final iterAttr = attrs[2];
  if (!iterAttr.startsWith('i=')) {
    throw ProtocolError('malformed SCRAM message');
  }
  final iterCount = int.tryParse(iterAttr.substring(2), radix: 10);
  if (iterCount == null || iterCount <= 0) {
    throw ProtocolError('malformed SCRAM message');
  }

  return ServerFirstMessage(nonce, salt, iterCount);
}

Uint8List parseServerFinalMessage(String msg) {
  final attrs = msg.split(",");

  if (attrs.isEmpty) {
    throw ProtocolError("malformed SCRAM message");
  }

  final nonceAttr = attrs[0];
  if (!nonceAttr.startsWith('v=')) {
    throw ProtocolError("malformed SCRAM message");
  }
  final signatureB64 = nonceAttr.substring(2);
  if (signatureB64.isEmpty) {
    throw ProtocolError("malformed SCRAM message");
  }

  return base64.decode(signatureB64);
}

class ClientFinalMessage {
  String msg;
  Uint8List serverProof;

  ClientFinalMessage(this.msg, this.serverProof);
}

ClientFinalMessage buildClientFinalMessage(
  String password,
  Uint8List salt,
  int iterations,
  String clientFirstBare,
  String serverFirst,
  Uint8List serverNonce,
) {
  final clientFinal = 'c=biws,r=${base64.encode(serverNonce)}';
  final authMessage = utf8.encode('$clientFirstBare,$serverFirst,$clientFinal');
  final saltedPassword =
      getSaltedPassword(utf8.encode(saslprep(password)), salt, iterations);
  final clientKey = getClientKey(saltedPassword);
  final storedKey = h(clientKey);
  final clientSignature = hmac(storedKey, [authMessage]);
  final clientProof = xor(clientKey, clientSignature);

  final serverKey = getServerKey(saltedPassword);
  final serverProof = hmac(serverKey, [authMessage]);

  return ClientFinalMessage('$clientFinal,p=${base64.encode(clientProof)}',
      Uint8List.fromList(serverProof));
}

List<int> getSaltedPassword(
    List<int> password, List<int> salt, int iterations) {
  // U1 := HMAC(str, salt + INT(1))

  var hi = hmac(password, [
    salt,
    [00, 00, 00, 0x01]
  ]);
  var ui = hi;

  for (var i = 0; i < iterations - 1; i++) {
    ui = hmac(password, [ui]);
    hi = xor(hi, ui);
  }

  return hi;
}

List<int> hmac(List<int> key, List<List<int>> data) {
  final output = DigestSink();
  final input = Hmac(sha256, key).startChunkedConversion(output);
  for (var d in data) {
    input.add(d);
  }
  input.close();
  return output.value.bytes;
}

List<int> h(List<int> data) {
  return sha256.convert(data).bytes;
}

List<int> getClientKey(List<int> saltedPassword) {
  return hmac(saltedPassword, [utf8.encode("Client Key")]);
}

List<int> getServerKey(List<int> saltedPassword) {
  return hmac(saltedPassword, [utf8.encode("Server Key")]);
}

Uint8List xor(List<int> a, List<int> b) {
  final len = a.length;
  if (len != b.length) {
    throw ProtocolError("scram.XOR: buffers are of different lengths");
  }
  final res = Uint8List(len);
  for (var i = 0; i < len; i++) {
    res[i] = a[i] ^ b[i];
  }
  return res;
}
