library edgedb;

export 'src/client.dart' show createClient, Client, Executor, Transaction;
export 'src/options.dart' hide serialiseState;
export 'src/connect_config.dart' show ConnectConfig, TLSSecurity;
export 'src/errors/errors.dart';
export 'src/datatypes/memory.dart' show ConfigMemory;
