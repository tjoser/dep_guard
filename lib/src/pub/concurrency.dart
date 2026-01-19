import 'dart:async';
import 'dart:collection';

class ConcurrencyLimiter {
  ConcurrencyLimiter(this.maxConcurrent);

  final int maxConcurrent;
  int _active = 0;
  final Queue<Completer<void>> _queue = Queue();

  Future<T> run<T>(Future<T> Function() action) async {
    if (_active >= maxConcurrent) {
      final waiter = Completer<void>();
      _queue.add(waiter);
      await waiter.future;
    }
    _active++;
    try {
      return await action();
    } finally {
      _active--;
      if (_queue.isNotEmpty) {
        _queue.removeFirst().complete();
      }
    }
  }
}
