import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:io';
import '../models/models.dart';
import 'native_executor.dart';
import 'staging_workspace.dart';

Object? pack(Object? v) => switch (v) {
  Uint8List b => TransferableTypedData.fromList([b]),
  Map m => m.map((k, v) => MapEntry(k, pack(v))),
  List l => l.map(pack).toList(),
  _ => v,
};
Object? unpack(Object? v) => switch (v) {
  TransferableTypedData b => b.materialize().asUint8List(),
  Map m => m.map((k, v) => MapEntry(k, unpack(v))),
  List l => l.map(unpack).toList(),
  _ => v,
};

final class NativeWorker {
  static final instance = NativeWorker();
  SendPort? _send;
  ReceivePort? _receive, _errors, _exit;
  Future<void>? _starting;
  Future<void>? _disposing;
  int _next = 0;
  final _pending = <int, Completer<Map>>{};
  void _failed(Object error) {
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(error);
    }
    _pending.clear();
    _send = null;
    _starting = null;
    _receive?.close();
    _errors?.close();
    _exit?.close();
  }

  Future<void> _start() async {
    final ready = Completer<void>();
    _receive = ReceivePort();
    _errors = ReceivePort();
    _exit = ReceivePort();
    void failed(Object error) {
      if (!ready.isCompleted) ready.completeError(error);
      _failed(error);
    }

    _errors!.listen(
      (e) => failed(
        const GifsicleException(
          code: GifsicleErrorCode.nativeFailure,
          message: 'Native worker crashed.',
        ),
      ),
    );
    _exit!.listen(
      (e) => failed(
        const GifsicleException(
          code: GifsicleErrorCode.nativeFailure,
          message: 'Native worker exited.',
        ),
      ),
    );
    _receive!.listen((message) {
      if (message is SendPort) {
        _send = message;
        ready.complete();
        return;
      }
      final m = unpack(message) as Map;
      final c = _pending.remove(m['id']);
      if (c == null) return;
      if (m['error'] != null) {
        final err = m['error'] as Map;
        if (err['argument'] == true) {
          c.completeError(ArgumentError(err['message']));
        } else if (err['code'] == 'unsupportedFeature') {
          c.completeError(
            GifsicleUnsupportedFeatureException(err['message'] as String),
          );
        } else {
          c.completeError(
            GifsicleException(
              code: GifsicleErrorCode.values.byName(err['code'] as String),
              message: err['message'] as String,
              nativeCode: err['nativeCode'] as int?,
            ),
          );
        }
      } else {
        c.complete(m['result'] as Map);
      }
    });
    try {
      await Isolate.spawn(
        _workerMain,
        _receive!.sendPort,
        onError: _errors!.sendPort,
        onExit: _exit!.sendPort,
        errorsAreFatal: true,
      );
      await ready.future;
    } catch (e) {
      failed(e);
      rethrow;
    }
  }

  Future<Map> request(Map<String, Object?> request) async {
    // Copy/transfer before awaiting startup so callers cannot mutate a pending request.
    final message = pack(request);
    if (request['operation'] != 'dispose' && _disposing != null) {
      await _disposing;
    }
    await (_starting ??= _start());
    final id = _next++;
    final c = Completer<Map>();
    _pending[id] = c;
    _send!.send({'id': id, 'request': message});
    return c.future;
  }

  Future<void> dispose() =>
      _disposing ??= _dispose().whenComplete(() => _disposing = null);

  Future<void> _dispose() async {
    if (_starting == null) return;
    await _starting;
    await request({'operation': 'dispose'});
    _receive?.close();
    _errors?.close();
    _exit?.close();
    _send = null;
    _starting = null;
  }
}

void _workerMain(SendPort parent) {
  final port = ReceivePort();
  parent.send(port.sendPort);
  Future<void> queue = Future.value();
  port.listen((message) {
    queue = queue.then((_) async {
      final m = unpack(message) as Map, request = m['request'] as Map;
      try {
        final result = await _handle(request);
        parent.send(pack({'id': m['id'], 'result': result}));
        if (request['operation'] == 'dispose') port.close();
      } catch (e) {
        parent.send({
          'id': m['id'],
          'error': {
            'argument': e is ArgumentError,
            'code': e is GifsicleException
                ? e.code.name
                : GifsicleErrorCode.nativeFailure.name,
            'message': e is GifsicleException
                ? e.message
                : e is ArgumentError
                ? e.message.toString()
                : 'Worker operation failed.',
            'nativeCode': e is GifsicleException ? e.nativeCode : null,
          },
        });
      }
    });
  });
}

Future<Map> _handle(Map r) async {
  final watch = Stopwatch()..start();
  switch (r['operation']) {
    case 'capabilities':
      return nativeCapabilities();
    case 'dispose':
      return {};
    case 'staged':
      return executeStaged(r);
    case 'transformBytes':
      final result = invokeNative(
        [...(r['arguments'] as List).cast<String>(), '-'],
        r['stdin'] as Uint8List,
        null,
        isolated: true,
      );
      return {
        ...result,
        'outputs': <String, Map>{},
        'generatedFiles': <Map>[],
        'elapsed': watch.elapsedMicroseconds,
      };
    case 'direct':
      final dir = r['directory'] as String?;
      if (dir != null && !await Directory(dir).exists()) {
        throw const GifsicleException(
          code: GifsicleErrorCode.workspaceFailure,
          message: 'Working directory does not exist.',
        );
      }
      final result = invokeNative(
        (r['arguments'] as List).cast<String>(),
        r['stdin'] as Uint8List?,
        dir,
        isolated: false,
      );
      return {
        ...result,
        'outputs': <String, Map>{},
        'generatedFiles': <Map>[],
        'elapsed': watch.elapsedMicroseconds,
      };
    case 'transformFile':
      final bytes = await readInput(r['inputPath'] as String, null);
      final result = invokeNative(
        [...(r['arguments'] as List).cast<String>(), '-'],
        bytes,
        null,
        isolated: true,
      );
      if (result['exitCode'] != 0) {
        throw nativeError(2, result['stderr'] as String);
      }
      final output = result['stdout'] as Uint8List;
      if (output.length < 6 ||
          String.fromCharCodes(output.take(6)) != 'GIF87a' &&
              String.fromCharCodes(output.take(6)) != 'GIF89a') {
        throw nativeError(2, 'Output is not a GIF.');
      }
      await atomicWrite(
        r['outputPath'] as String,
        output,
        r['overwrite'] as bool,
      );
      return {
        'inputSize': bytes.length,
        'outputSize': output.length,
        'elapsed': watch.elapsedMicroseconds,
        'stderr': result['stderr'],
      };
    default:
      throw StateError('Unknown operation');
  }
}
