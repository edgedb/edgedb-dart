import '../primitives/buffer.dart';
import 'codecs.dart';

class ObjectCodec extends Codec {
  List<Codec> codecs;
  late List<String> names;
  List<int> cardinalities;

  ObjectCodec(
    super.tid,
    this.codecs,
    List<String> names,
    List<int> flags,
    this.cardinalities,
  ) {
    this.names = List.generate(names.length, (i) {
      final isLinkprop = (flags[i] & (1 << 1)) != 0;
      return isLinkprop ? '@${names[i]}' : names[i];
    });
  }

  @override
  void encode(WriteBuffer buf, dynamic object) {
    throw ArgumentError("Objects cannot be passed as arguments");
  }

  // encodeArgs(args: any): Buffer {
  //   if (this.fields[0].name === "0") {
  //     return this._encodePositionalArgs(args);
  //   }
  //   return this._encodeNamedArgs(args);
  // }

  // _encodePositionalArgs(args: any): Buffer {
  //   if (!Array.isArray(args)) {
  //     throw new Error("an array of arguments was expected");
  //   }

  //   const codecs = this.codecs;
  //   const codecsLen = codecs.length;

  //   if (args.length !== codecsLen) {
  //     throw new Error(
  //       `expected ${codecsLen} argument${codecsLen === 1 ? "" : "s"}, got ${
  //         args.length
  //       }`
  //     );
  //   }

  //   const elemData = new WriteBuffer();
  //   for (let i = 0; i < codecsLen; i++) {
  //     elemData.writeInt32(0); // reserved
  //     const arg = args[i];
  //     if (arg == null) {
  //       const card = this.cardinalities[i];
  //       if (card === ONE || card === AT_LEAST_ONE) {
  //         throw new Error(
  //           `argument ${this.fields[i].name} is required, but received ${arg}`
  //         );
  //       }
  //       elemData.writeInt32(-1);
  //     } else {
  //       const codec = codecs[i];
  //       codec.encode(elemData, arg);
  //     }
  //   }

  //   const elemBuf = elemData.unwrap();
  //   const buf = new WriteBuffer();
  //   buf.writeInt32(4 + elemBuf.length);
  //   buf.writeInt32(codecsLen);
  //   buf.writeBuffer(elemBuf);
  //   return buf.unwrap();
  // }

  // _encodeNamedArgs(args: any): Buffer {
  //   if (args == null) {
  //     throw new Error("One or more named arguments expected, received null");
  //   }

  //   const keys = Object.keys(args);
  //   const fields = this.fields;
  //   const namesSet = this.namesSet;
  //   const codecs = this.codecs;
  //   const codecsLen = codecs.length;

  //   if (keys.length > codecsLen) {
  //     const extraKeys = keys.filter(key => !namesSet.has(key));
  //     throw new Error(
  //       `Unused named argument${
  //         extraKeys.length === 1 ? "" : "s"
  //       }: "${extraKeys.join('", "')}"`
  //     );
  //   }

  //   const elemData = new WriteBuffer();
  //   for (let i = 0; i < codecsLen; i++) {
  //     const key = fields[i].name;
  //     const val = args[key];

  //     elemData.writeInt32(0); // reserved bytes
  //     if (val == null) {
  //       const card = this.cardinalities[i];
  //       if (card === ONE || card === AT_LEAST_ONE) {
  //         throw new Error(
  //           `argument ${this.fields[i].name} is required, but received ${val}`
  //         );
  //       }
  //       elemData.writeInt32(-1);
  //     } else {
  //       const codec = codecs[i];
  //       codec.encode(elemData, val);
  //     }
  //   }

  //   const elemBuf = elemData.unwrap();
  //   const buf = new WriteBuffer();
  //   buf.writeInt32(4 + elemBuf.length);
  //   buf.writeInt32(codecsLen);
  //   buf.writeBuffer(elemBuf);
  //   return buf.unwrap();
  // }

  @override
  dynamic decode(ReadBuffer buf) {
    // const codecs = this.codecs;
    // const fields = this.fields;

    // const els = buf.readUInt32();
    // if (els !== codecs.length) {
    //   throw new Error(
    //     `cannot decode Object: expected ${codecs.length} elements, got ${els}`
    //   );
    // }

    // const elemBuf = ReadBuffer.alloc();
    // const result: any = {};
    // for (let i = 0; i < els; i++) {
    //   buf.discard(4); // reserved
    //   const elemLen = buf.readInt32();
    //   const name = fields[i].name;
    //   let val = null;
    //   if (elemLen !== -1) {
    //     buf.sliceInto(elemBuf, elemLen);
    //     val = codecs[i].decode(elemBuf);
    //     elemBuf.finish();
    //   }
    //   result[name] = val;
    // }

    // return result;
  }
}
