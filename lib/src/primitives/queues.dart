/*!
 * This source file is part of the EdgeDB open source project.
 *
 * Copyright 2020-present MagicStack Inc. and the EdgeDB authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';

class LIFOQueue<T> {
  final List<Completer<T>> _completed = [];
  final List<Completer<T>> _waiters = [];

  /// Add an item to the queue.
  /// If any consumer is awaiting for an item from the queue, the item is
  /// passed to the first consumer in the queue.
  void push(T item) {
    if (_waiters.isEmpty) {
      _completed.add(Completer()..complete(item));
    } else {
      _waiters.removeAt(0).complete(item);
    }
  }

  /// Return a promise that resolves with the last element in the queue.
  /// If the queue is empty, the promise is resolved as soon as an item is
  /// added to the queue.
  Future<T> get() {
    if (_completed.isEmpty) {
      _waiters.add(Completer());
      return _waiters.last.future;
    } else {
      return _completed.removeLast().future;
    }
  }

  void cancelAllPending(Error err) {
    for (var waiter in _waiters) {
      waiter.completeError(err);
    }
    _waiters.clear();
  }

  /// Get the count of available elements in the queue.
  /// This value can be negative, if the number of consumers awaiting for items
  /// to become available is greater than the items in the queue.
  int get length {
    return _completed.length - _waiters.length;
  }

  /// Get the count of consumers awaiting for items to become available in
  /// the queue.
  int get pending {
    return _waiters.length;
  }
}
