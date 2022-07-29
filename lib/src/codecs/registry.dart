import 'dart:typed_data';

import 'package:edgedb/src/codecs/consts.dart';

import '../primitives/buffer.dart';
import '../primitives/lru.dart';
import '../primitives/proto_version.dart';
import 'array.dart';
import 'codecs.dart';
import 'object.dart';
import 'set.dart';
import 'tuple.dart';

class CodecError extends Error {
  final String message;
  CodecError(this.message);

  @override
  String toString() {
    return 'CodecError: $message';
  }
}

const codecsCacheSize = 1000;
const codecsBuildCacheSize = 200;

const ctypeSet = 0;
const ctypeShape = 1;
const ctypeBaseScalar = 2;
const ctypeScalar = 3;
const ctypeTuple = 4;
const ctypeNamedtuple = 5;
const ctypeArray = 6;
const ctypeEnum = 7;

class CodecsRegistry {
  final codecsBuildCache = LRU<String, Codec>(capacity: codecsBuildCacheSize);
  final codecs = LRU<String, Codec>(capacity: codecsCacheSize);

  bool hasCodec(String typeId) {
    if (codecs.has(typeId)) {
      return true;
    }

    return typeId == nullCodecID || typeId == emptyTupleCodecID;
  }

  Codec? getCodec(String typeId) {
    final codec = codecs.get(typeId);
    if (codec != null) {
      return codec;
    }

    if (typeId == emptyTupleCodecID) {
      return emptyTupleCodec;
    }

    if (typeId == nullCodecID) {
      return nullCodec;
    }

    return null;
  }

  Codec buildCodec(Uint8List spec, ProtocolVersion protocolVersion) {
    final frb = ReadBuffer(spec);
    final codecsList = <Codec>[];
    Codec? codec;

    while (frb.length > 0) {
      codec = _buildCodec(frb, codecsList, protocolVersion);
      if (codec == null) {
        // An annotation; ignore.
        continue;
      }
      codecsList.add(codec);
      codecs.set(codec.tid, codec);
    }

    if (codecsList.isEmpty) {
      throw CodecError('could not build a codec');
    }

    return codecsList.last;
  }

  Codec? _buildCodec(
    ReadBuffer frb,
    List<Codec> cl,
    ProtocolVersion protocolVersion,
  ) {
    final t = frb.readUint8();
    final tid = frb.readUUID();

    var res = codecs.get(tid) ?? codecsBuildCache.get(tid);

    if (res != null) {
      // We have a codec for this "tid"; advance the buffer
      // so that we can process the next codec.

      switch (t) {
        case ctypeSet:
          {
            frb.discard(2);
            break;
          }

        case ctypeShape:
          {
            final els = frb.readUint16();
            for (var i = 0; i < els; i++) {
              frb.discard(5); // 4 (flags) + 1 (cardinality)

              final elmLength = frb.readUint32();
              frb.discard(elmLength + 2);
            }
            break;
          }

        case ctypeBaseScalar:
          {
            break;
          }

        case ctypeScalar:
          {
            frb.discard(2);
            break;
          }

        case ctypeTuple:
          {
            final els = frb.readUint16();
            frb.discard(2 * els);
            break;
          }

        case ctypeNamedtuple:
          {
            final els = frb.readUint16();
            for (var i = 0; i < els; i++) {
              final elmLength = frb.readUint32();
              frb.discard(elmLength + 2);
            }
            break;
          }

        case ctypeArray:
          {
            frb.discard(2);
            final els = frb.readUint16();
            if (els != 1) {
              throw CodecError(
                  'cannot handle arrays with more than one dimension');
            }
            frb.discard(4);
            break;
          }

        case ctypeEnum:
          {
            final els = frb.readUint16();
            for (var i = 0; i < els; i++) {
              final elmLength = frb.readUint32();
              frb.discard(elmLength);
            }
            break;
          }

        default:
          {
            if (t >= 0x7f && t <= 0xff) {
              final annLength = frb.readUint32();
              // if (t == 0xff) {
              //   const typeName = frb.readBuffer(ann_length).toString("utf8");
              //   const codec =
              //     this.codecs.get(tid) ?? this.codecsBuildCache.get(tid);
              //   if (codec instanceof ScalarCodec) {
              //     codec.setTypeName(typeName);
              //   }
              // } else {
              frb.discard(annLength);
              // }
              return null;
            } else {
              throw CodecError(
                  'no codec implementation for EdgeDB data class $t');
            }
          }
      }

      return res;
    }

    switch (t) {
      case ctypeBaseScalar:
        {
          res = scalarCodecs[tid];
          if (res == null) {
            if (knownTypes.containsKey(tid)) {
              throw CodecError('no Dart codec for ${knownTypes[tid]}');
            }

            throw CodecError('node Dart codec for the type with ID $tid');
          }
          if (res is! ScalarCodec) {
            throw CodecError(
                'could not build scalar codec: base scalar has a non-scalar codec');
          }
          break;
        }

      case ctypeShape:
        {
          final els = frb.readUint16();
          final codecs = <Codec>[];
          final names = <String>[];
          final flags = <int>[];
          final cards = <int>[];

          for (var i = 0; i < els; i++) {
            final flag = frb.readUint32();
            final card = frb.readUint8();

            final strLen = frb.readUint32();
            final name = frb.readBytes(strLen).toString();

            final pos = frb.readUint16();
            Codec subCodec;
            try {
              subCodec = cl[pos];
            } catch (e) {
              throw CodecError(
                  'could not build object codec: missing subcodec');
            }

            codecs[i] = subCodec;
            names[i] = name;
            flags[i] = flag;
            cards[i] = card;
          }

          res = ObjectCodec(tid, codecs, names, flags, cards);
          break;
        }

      case ctypeSet:
        {
          final pos = frb.readUint16();
          Codec subCodec;
          try {
            subCodec = cl[pos];
          } catch (e) {
            throw CodecError('could not build set codec: missing subcodec');
          }

          res = SetCodec(tid, subCodec);
          break;
        }

      case ctypeScalar:
        {
          final pos = frb.readUint16();

          try {
            res = cl[pos];
          } catch (e) {
            throw CodecError(
                'could not build scalar codec: missing a codec for base scalar');
          }

          if (res is! ScalarCodec) {
            throw CodecError(
                'could not build scalar codec: base scalar has a non-scalar codec');
          }
          // res = <ICodec>res.derive(tid);
          break;
        }

      case ctypeArray:
        {
          final pos = frb.readUint16();
          final els = frb.readUint16();
          if (els != 1) {
            throw CodecError(
                'cannot handle arrays with more than one dimension');
          }
          final dimLen = frb.readInt32();
          Codec subCodec;
          try {
            subCodec = cl[pos];
          } catch (e) {
            throw CodecError('could not build array codec: missing subcodec');
          }
          res = ArrayCodec(tid, subCodec, dimLen);
          break;
        }

      case ctypeTuple:
        {
          final els = frb.readUint16();
          if (els == 0) {
            res = emptyTupleCodec;
          } else {
            final codecs = <Codec>[];
            for (var i = 0; i < els; i++) {
              final pos = frb.readUint16();
              Codec subCodec;
              try {
                subCodec = cl[pos];
              } catch (e) {
                throw CodecError(
                    'could not build tuple codec: missing subcodec');
              }
              codecs[i] = subCodec;
            }
            res = TupleCodec(tid, codecs);
          }
          break;
        }

      case ctypeNamedtuple:
        {
          final els = frb.readUint16();
          final codecs = <Codec>[];
          final names = <String>[];
          for (var i = 0; i < els; i++) {
            final strLen = frb.readUint32();
            names[i] = frb.readBytes(strLen).toString();

            final pos = frb.readUint16();
            Codec subCodec;
            try {
              subCodec = cl[pos];
            } catch (e) {
              throw CodecError(
                  'could not build namedtuple codec: missing subcodec');
            }
            codecs[i] = subCodec;
          }
          // res = NamedTupleCodec(tid, codecs, names);
          break;
        }

      case ctypeEnum:
        {
          /* There's no way to customize ordering in JS, so we
           simply ignore that information and unpack enums into
           simple strings.
        */
          final els = frb.readUint16();
          for (var i = 0; i < els; i++) {
            frb.discard(frb.readUint32());
          }
          // res = EnumCodec(tid);
          break;
        }
    }

    if (res == null) {
      if (knownTypes.containsKey(tid)) {
        throw CodecError('could not build a codec for ${knownTypes[tid]} type');
      } else {
        throw CodecError('could not build a codec for $tid type');
      }
    }

    codecsBuildCache.set(tid, res);
    return res;
  }
}
