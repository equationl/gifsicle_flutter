import 'dart:io';
import 'dart:typed_data';
import '../src/bindings/gifsicle_bindings_generated.dart' as native;
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'models/models.dart';
import 'native/worker.dart';
import 'native/staging_workspace.dart' show validateText;

/// In-process Gifsicle. All CPU-intensive work runs on a serialized worker.
abstract final class Gifsicle {
  static String get bridgeVersion => '${native.gs_bridge_abi_version()}';
  static String get gifsicleVersion =>
      native.gs_gifsicle_version().cast<Utf8>().toDartString();
  static Future<GifsicleCapabilities> capabilities() async =>
      GifsicleCapabilities.fromJson(
        Map<String, dynamic>.from(
          await NativeWorker.instance.request({'operation': 'capabilities'}),
        ),
      );
  static List<String> _argv(List<String> arguments) {
    if (arguments.length > 65535) throw ArgumentError('Too many arguments.');
    for (final s in arguments) {
      validateText(s);
    }
    return List.of(arguments);
  }

  static void _external(bool enabled) {
    if (enabled) {
      throw const GifsicleUnsupportedFeatureException(
        'External commands are disabled in this build.',
      );
    }
  }

  static Future<GifsicleExecutionResult> execute(
    GifsicleCommand command,
  ) async {
    _external(command.allowExternalCommands);
    final tokens = command.arguments.map((t) => t.toMessage()).toList();
    for (final t in tokens) {
      for (final value in t.values) {
        if (value is String) validateText(value);
      }
      if (t['type'] == 'frame' && !(t['value'] as String).startsWith('#')) {
        throw ArgumentError('Frame selectors must start with #.');
      }
      if (t['type'] == 'option' &&
          !(t['value'] as String).startsWith('-') &&
          !(t['value'] as String).startsWith('+')) {
        throw ArgumentError('Option token must begin with - or +.');
      }
      if (t['id'] is String && (t['id'] as String).isEmpty) {
        throw ArgumentError('Artifact ID cannot be empty.');
      }
      if (t['path'] is String) t['path'] = p.absolute(t['path'] as String);
    }
    return _result(
      await NativeWorker.instance.request({
        'operation': 'staged',
        'tokens': tokens,
        'stdin': command.stdin,
        'collectGeneratedFiles': command.collectGeneratedFiles,
        'limits': command.limits.toMessage(),
      }),
    );
  }

  static Future<GifsicleExecutionResult> executeArguments(
    List<String> arguments, {
    Uint8List? stdin,
    String? workingDirectory,
    bool allowExternalCommands = false,
  }) async {
    _external(allowExternalCommands);
    if (workingDirectory != null) validateText(workingDirectory);
    return _result(
      await NativeWorker.instance.request({
        'operation': 'direct',
        'arguments': _argv(arguments),
        'stdin': stdin,
        'directory': p.absolute(workingDirectory ?? Directory.current.path),
      }),
    );
  }

  static Future<GifsicleBytesResult> transformBytes(
    Uint8List input, {
    GifsicleOptions options = const GifsicleOptions(),
  }) async {
    final arguments = options.toArguments();
    if (input.isEmpty) throw ArgumentError('Input GIF is empty.');
    final result = _result(
      await NativeWorker.instance.request({
        'operation': 'transformBytes',
        'arguments': arguments,
        'stdin': input,
      }),
    );
    if (!result.isSuccess) {
      throw GifsicleException(
        code: GifsicleErrorCode.invalidGif,
        message: result.stderr,
        nativeCode: result.exitCode,
      );
    }
    final bytes = result.stdout;
    if (bytes.length < 6 ||
        !['GIF87a', 'GIF89a'].contains(String.fromCharCodes(bytes.take(6)))) {
      throw const GifsicleException(
        code: GifsicleErrorCode.invalidGif,
        message: 'Output is not a GIF.',
      );
    }
    return GifsicleBytesResult(
      bytes: bytes,
      inputSize: input.length,
      outputSize: bytes.length,
      elapsed: result.elapsed,
      warnings: _warnings(result.stderr),
    );
  }

  static Future<GifsicleFileResult> transformFile({
    required String inputPath,
    required String outputPath,
    GifsicleOptions options = const GifsicleOptions(),
    bool overwrite = false,
  }) async {
    validateText(inputPath);
    validateText(outputPath);
    final result = await NativeWorker.instance.request({
      'operation': 'transformFile',
      'inputPath': p.absolute(inputPath),
      'outputPath': p.absolute(outputPath),
      'arguments': options.toArguments(),
      'overwrite': overwrite,
    });
    return GifsicleFileResult(
      outputPath: p.absolute(outputPath),
      inputSize: result['inputSize'] as int,
      outputSize: result['outputSize'] as int,
      elapsed: Duration(microseconds: result['elapsed'] as int),
      warnings: _warnings(result['stderr'] as String),
    );
  }

  static GifsicleExecutionResult _result(Map r) => GifsicleExecutionResult(
    exitCode: r['exitCode'] as int,
    stdout: r['stdout'] as Uint8List,
    stderr: r['stderr'] as String,
    outputs: Map.unmodifiable(
      (r['outputs'] as Map).map(
        (id, value) => MapEntry(
          id as String,
          value['bytes'] != null
              ? GifsicleMemoryOutputArtifact(id, value['bytes'] as Uint8List)
              : GifsicleFileOutputArtifact(
                  id,
                  value['path'] as String,
                  value['size'] as int,
                ),
        ),
      ),
    ),
    generatedFiles: List.unmodifiable(
      (r['generatedFiles'] as List).map(
        (e) => GifsicleGeneratedFile(
          relativePath: e['relativePath'] as String,
          bytes: e['bytes'] as Uint8List,
        ),
      ),
    ),
    elapsed: Duration(microseconds: r['elapsed'] as int),
  );
  static List<String> _warnings(String s) =>
      List.unmodifiable(s.split('\n').where((s) => s.isNotEmpty));

  /// Drain the queue and shut down the worker. Never interrupts native execution.
  static Future<void> disposeForTesting() => NativeWorker.instance.dispose();
}
