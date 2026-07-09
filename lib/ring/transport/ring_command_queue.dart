// Source: colmi_r02_client/colmi_r02_client/client.py queues (MIT)
// Dual-channel: main 16B (notify V1) + big-data 0xBC (notify V2) — QRing btsnoop R08

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../codec/big_data_codec.dart';
import '../codec/packet_codec.dart';
import '../ring_protocol_constants.dart';
import 'ring_transport.dart';

enum RingCommandPriority { connection, manual, uiFresh, backgroundSync }

class RingCommandException implements Exception {
  RingCommandException(this.code, [this.message]);
  final String code;
  final String? message;

  @override
  String toString() => 'RingCommandException($code, $message)';
}

/// Serializes BLE writes; all main notify frames fan out on one broadcast stream.
class RingCommandQueue {
  RingCommandQueue(this._transport);

  final RingTransport _transport;
  StreamController<List<int>>? _mainFrames;
  final Map<int, List<int>> _latestByOpcode = {};
  final Map<int, StreamController<List<int>>> _bigDataTagStreams = {};
  final BigDataAssembler _bigDataAssembler = BigDataAssembler();

  StreamSubscription<List<int>>? _mainSub;
  StreamSubscription<List<int>>? _bigDataSub;

  final Queue<_QueuedWrite> _pending = Queue();
  bool _draining = false;
  _QueuedWrite? _inFlight;

  int? _lastPacketSizeIndicator;

  /// Last 0x2f packet-size byte from ring (btsnoop: `2f f4 …` → 244).
  int? get lastPacketSizeIndicator => _lastPacketSizeIndicator;

  /// All validated 16B main notify frames (broadcast).
  Stream<List<int>> get mainFrames {
    startListening();
    return _ensureMainFrames().stream;
  }

  StreamController<List<int>> _ensureMainFrames() {
    return _mainFrames ??= StreamController<List<int>>.broadcast();
  }

  void startListening() {
    _mainSub ??= _transport.notifyMain.listen(_onMainPacket);
    _bigDataSub ??= _transport.notifyBigData.listen(_onBigDataChunk);
  }

  Future<void> stopListening() async {
    await _mainSub?.cancel();
    await _bigDataSub?.cancel();
    _mainSub = null;
    _bigDataSub = null;
    _bigDataAssembler.reset();
    _latestByOpcode.clear();
    await _mainFrames?.close();
    _mainFrames = null;
    for (final c in _bigDataTagStreams.values) {
      await c.close();
    }
    _bigDataTagStreams.clear();
    _pending.clear();
    _inFlight = null;
    _draining = false;
  }

  /// Filtered view of [mainFrames] for push opcodes (0x69, 0x43, …).
  Stream<List<int>> pushStream(int opcode) {
    return mainFrames.where((p) => (p[0] & 0xff) == opcode);
  }

  void _onMainPacket(List<int> packet) {
    if (packet.length != RingProtocolConstants.packetLength) {
      debugPrint('[RING][main] unexpected length ${packet.length}');
      return;
    }
    if (!PacketCodec.validate(packet)) {
      debugPrint('[RING][main] checksum mismatch');
      return;
    }
    final opcode = packet[0] & 0xff;
    if (packet[0] >= 127) {
      debugPrint('[RING][main] error bit opcode=0x${opcode.toRadixString(16)}');
      return;
    }

    switch (opcode) {
      case RingProtocolConstants.cmdHeartbeat:
        return;
      case RingProtocolConstants.cmdPacketSize:
        _lastPacketSizeIndicator = packet.length > 1 ? packet[1] & 0xff : null;
        return;
    }

    final copy = List<int>.from(packet);
    _latestByOpcode[opcode] = copy;
    final hub = _mainFrames;
    if (hub != null && !hub.isClosed) hub.add(copy);
  }

  void clearLatestOpcode(int opcode) => _latestByOpcode.remove(opcode);

  /// Subscribe first, optionally consume connect burst from cache, then write.
  Future<List<int>> transact(
    int opcode,
    List<int> packet, {
    Duration timeout = const Duration(seconds: 5),
    bool Function(List<int> packet)? predicate,
    RingCommandPriority priority = RingCommandPriority.connection,
    bool allowCached = true,
  }) async {
    startListening();
    StreamSubscription<List<int>>? sub;
    final completer = Completer<List<int>>();

    void deliver(List<int> frame) {
      if ((frame[0] & 0xff) != opcode) return;
      if (predicate != null && !predicate(frame)) return;
      if (!completer.isCompleted) {
        completer.complete(List<int>.from(frame));
        unawaited(sub?.cancel());
      }
    }

    sub = mainFrames.listen(deliver);

    if (allowCached) {
      final cached = _latestByOpcode[opcode];
      if (cached != null) deliver(cached);
    }

    if (!completer.isCompleted) {
      await writePacket(packet, priority: priority, timeout: timeout);
    }

    try {
      return await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  void _onBigDataChunk(List<int> chunk) {
    final frames = _bigDataAssembler.feed(chunk);
    for (final frame in frames) {
      if (frame.isEmpty ||
          (frame[0] & 0xff) != RingProtocolConstants.cmdBigDataV2) {
        continue;
      }
      final tag = frame[1] & 0xff;
      final tagStream = _bigDataTagStreams[tag];
      if (tagStream != null && !tagStream.isClosed) {
        tagStream.add(frame);
      } else if (kDebugMode) {
        debugPrint(
          '[RING][big] tag 0x${tag.toRadixString(16)} len=${frame.length} (no listener)',
        );
      }
    }
  }

  Stream<List<int>> bigDataTagStream(int tag) {
    return _bigDataTagStreams
        .putIfAbsent(tag, () => StreamController<List<int>>.broadcast())
        .stream;
  }

  /// Subscribe before write; caller must not write until this future is awaited with write in between — use [transact].
  Future<List<int>> waitForOpcode(
    int opcode, {
    Duration timeout = const Duration(seconds: 5),
    bool Function(List<int> packet)? predicate,
  }) {
    startListening();
    late StreamSubscription<List<int>> sub;
    final completer = Completer<List<int>>();

    sub = mainFrames.listen((frame) {
      if ((frame[0] & 0xff) != opcode) return;
      if (predicate != null && !predicate(frame)) return;
      if (!completer.isCompleted) {
        completer.complete(List<int>.from(frame));
        sub.cancel();
      }
    });

    return completer.future.timeout(timeout).whenComplete(() => sub.cancel());
  }

  /// Register big-data listener, then write big-data command.
  Future<List<int>> transactBigData(
    List<int> command,
    int tag, {
    Duration timeout = const Duration(seconds: 30),
    bool Function(List<int> frame)? predicate,
    RingCommandPriority priority = RingCommandPriority.connection,
  }) async {
    startListening();
    final completer = Completer<List<int>>();
    late StreamSubscription<List<int>> sub;
    sub = bigDataTagStream(tag).listen((frame) {
      if (predicate != null && !predicate(frame)) return;
      if (!completer.isCompleted) {
        completer.complete(frame);
        sub.cancel();
      }
    });
    try {
      await writeBigDataCommand(command, priority: priority, timeout: timeout);
      return await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  /// Wait for complete 0xBC frame on big-data notify (V2 / handle 0x0018).
  Future<List<int>> waitForBigData(
    int tag, {
    Duration timeout = const Duration(seconds: 30),
    bool Function(List<int> frame)? predicate,
  }) async {
    startListening();
    final completer = Completer<List<int>>();
    late StreamSubscription<List<int>> sub;
    sub = bigDataTagStream(tag).listen((frame) {
      if (predicate != null && !predicate(frame)) return;
      if (!completer.isCompleted) {
        completer.complete(frame);
        sub.cancel();
      }
    });
    try {
      return await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  /// Subscribe **before** write; then `await writePacket` and `await` returned future.
  Future<List<List<int>>> collectPackets(
    int opcode, {
    required bool Function(List<int> packet, List<List<int>> collected) done,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    startListening();
    final collected = <List<int>>[];
    final completer = Completer<List<List<int>>>();
    late StreamSubscription<List<int>> sub;
    sub = pushStream(opcode).listen((packet) {
      collected.add(List<int>.from(packet));
      if (done(packet, collected) && !completer.isCompleted) {
        completer.complete(List<List<int>>.from(collected));
        sub.cancel();
      }
    });
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      return collected;
    } finally {
      await sub.cancel();
    }
  }

  Future<void> writePacket(
    List<int> packet, {
    RingCommandPriority priority = RingCommandPriority.connection,
    Duration timeout = const Duration(seconds: 5),
    int retries = 2,
  }) async {
    final completer = Completer<void>();
    _pending.add(_QueuedWrite(packet, priority, completer, timeout, retries));
    _pending.toList().sort((a, b) => a.priority.index.compareTo(b.priority.index));
    unawaited(_drain());
    return completer.future;
  }

  Future<void> writeBigDataCommand(
    List<int> data, {
    RingCommandPriority priority = RingCommandPriority.connection,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<void>();
    _pending.add(
      _QueuedWrite(data, priority, completer, timeout, 1, useBigDataWrite: true),
    );
    unawaited(_drain());
    return completer.future;
  }

  @Deprecated('Use writeBigDataCommand')
  Future<void> writeCommandV2(
    List<int> data, {
    RingCommandPriority priority = RingCommandPriority.connection,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      writeBigDataCommand(data, priority: priority, timeout: timeout);

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    while (_pending.isNotEmpty) {
      final call = _pending.removeFirst();
      _inFlight = call;
      var attempt = 0;
      while (true) {
        attempt++;
        try {
          if (call.useBigDataWrite) {
            await _transport.writeBigDataCommand(call.data).timeout(call.timeout);
          } else {
            await _transport.writeMainPacket(call.data).timeout(call.timeout);
          }
          if (!call.completer.isCompleted) call.completer.complete();
          break;
        } catch (e) {
          debugPrint('[RING] write attempt $attempt failed: $e');
          if (attempt >= call.retries) {
            if (!call.completer.isCompleted) {
              call.completer.completeError(
                RingCommandException('WRITE_FAILED', e.toString()),
              );
            }
            break;
          }
          await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
      _inFlight = null;
    }
    _draining = false;
  }

  bool get isIdle => _pending.isEmpty && _inFlight == null;
}

class _QueuedWrite {
  _QueuedWrite(
    this.data,
    this.priority,
    this.completer,
    this.timeout,
    this.retries, {
    this.useBigDataWrite = false,
  });

  final List<int> data;
  final RingCommandPriority priority;
  final Completer<void> completer;
  final Duration timeout;
  final int retries;
  final bool useBigDataWrite;
}
