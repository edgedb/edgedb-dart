/*!
 * This source file is part of the EdgeDB open source project.
 *
 * Copyright 2019-present MagicStack Inc. and the EdgeDB authors.
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

class Node<K, V> {
  final K key;
  V value;
  Node<K, V>? next;
  Node<K, V>? prev;

  Node(this.key, this.value);
}

class Deque<K, V> {
  Node<K, V>? head;
  Node<K, V>? tail;
  int len = 0;

  /*
    Stack structure:

    ---~* top *~---

          +------+
   null --< prev |
          | next >--+
          +-^----+  |
            |       |
        +---+  +----+
        |      |
        | +----v-+
        +-< prev |
          | next >--+
          +-^----+  |
            |       |
        +---+  +----+
        |      |
        | +----v-+
        +-< prev |
          | next >-- null
          +------+

    ---~* bottom *~---
  */

  int get length {
    return len;
  }

  Node<K, V> push(K key, V value) {
    final node = Node(key, value);
    if (head == null) {
      head = node;
      tail = node;
    } else {
      head!.prev = node;
      node.next = head;
      head = node;
    }
    len++;
    return node;
  }

  void moveToTop(Node<K, V> node) {
    if (node.prev == null) {
      // Already on top of the stack, do nothing.
      return;
    }

    final prev = node.prev!;
    final next = node.next;

    // First, remove the node from the deque.
    prev.next = next;
    if (next != null) {
      next.prev = prev;
    }

    if (tail == node) {
      tail = prev;
    }

    // Second, push on top of the deque.
    node.prev = null;
    node.next = head;

    head!.prev = node;
    head = node;
  }

  Node<K, V>? deleteBottom() {
    if (len == 0 || tail == null || head == null) {
      // Empty deque.
      return null;
    }

    if (tail == head) {
      len = 0;
      final node = tail;
      tail = null;
      head = null;
      return node;
    }

    final tempTail = tail;
    final beforeLast = tail!.prev!;
    beforeLast.next = null;
    tail!.prev = null;
    tail!.next = null;
    tail = beforeLast;
    len--;
    return tempTail;
  }
}

class LRU<K, V> {
  late int _capacity;
  Map<K, Node<K, V>> _map = {};
  Deque<K, V> _deque = Deque();

  LRU({required int capacity}) {
    if (capacity <= 0) {
      throw ArgumentError("capacity is expected to be greater than 0");
    }
    // ignore: prefer_initializing_formals
    _capacity = capacity;
  }

  int get length {
    final len = _map.length;
    // This check will be handy in tests
    // to ensure that our deque is in sync
    // with the map.
    assert(len == _deque.length, "deque & map disagree on elements count");
    return len;
  }

  bool has(K key) {
    return _map.containsKey(key);
  }

  V? get(K key) {
    final node = _map[key];
    if (node != null) {
      _deque.moveToTop(node);
      return node.value;
    }
    return null;
  }

  void set(K key, V value) {
    final existingNode = _map[key];

    if (existingNode != null) {
      existingNode.value = value;
      _deque.moveToTop(existingNode);
    } else {
      final newNode = _deque.push(key, value);
      _map[key] = newNode;

      while (_deque.length > _capacity) {
        final bottomNode = _deque.deleteBottom()!;
        _map.remove(bottomNode.key);
      }
    }
  }

  Iterable<K> get keys sync* {
    var node = _deque.head;
    while (node != null) {
      yield node.key;
      node = node.next;
    }
  }

  Iterable<V> get values sync* {
    var node = _deque.head;
    while (node != null) {
      yield node.value;
      node = node.next;
    }
  }

  Iterable<MapEntry<K, V>> get entries sync* {
    var node = _deque.head;
    while (node != null) {
      yield MapEntry(node.key, node.value);
      node = node.next;
    }
  }
}
