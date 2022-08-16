library edgedb;

export 'src/client.dart' show createClient, Client, Executor, Transaction;
export 'src/options.dart' hide serialiseState;
export 'src/errors/errors.dart';
