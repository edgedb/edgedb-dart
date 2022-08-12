library edgedb;

export 'src/client.dart' show createClient, Client, Executor;
export 'src/transaction.dart' show Transaction;
export 'src/options.dart' hide serialiseState;
export 'src/errors/errors.dart';
