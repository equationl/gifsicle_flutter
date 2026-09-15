import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';
import 'native_executor.dart';

void validateText(String s) {
  if (s.contains('\u0000')) {
    throw ArgumentError('NUL is not allowed in argv or paths.');
  }
}

void enforce(int actual, Object? limit, String label) {
  if (limit is int && actual > limit) {
    throw GifsicleException(
      code: GifsicleErrorCode.invalidArgument,
      message: '$label exceeds configured limit.',
    );
  }
}

/// Checks GIF block boundaries before native decoding when image limits are set.
void checkImageLimits(Uint8List bytes, Map limits) {
  if (limits['maxCanvasPixels'] == null && limits['maxFrameCount'] == null) {
    return;
  }
  if (bytes.length < 13 || bytes[0] != 71 || bytes[1] != 73 || bytes[2] != 70) {
    return;
  }
  int word(int i) => bytes[i] | bytes[i + 1] << 8;
  final screenWidth = word(6), screenHeight = word(8);
  enforce(
    screenWidth * screenHeight,
    limits['maxCanvasPixels'],
    'Canvas pixels',
  );
  var pos =
          13 + ((bytes[10] & 128) != 0 ? 3 * (1 << ((bytes[10] & 7) + 1)) : 0),
      frames = 0;
  void blocks() {
    while (pos < bytes.length) {
      final n = bytes[pos++];
      if (n == 0) return;
      pos += n;
    }
  }

  while (pos < bytes.length) {
    final block = bytes[pos++];
    if (block == 0x3b) break;
    if (block == 0x21) {
      pos++;
      blocks();
    } else if (block == 0x2c) {
      if (pos + 9 > bytes.length) break;
      enforce(++frames, limits['maxFrameCount'], 'Frame count');
      enforce(
        (word(pos) + (word(pos + 4) == 0 ? screenWidth : word(pos + 4))) *
            (word(pos + 2) +
                (word(pos + 6) == 0 ? screenHeight : word(pos + 6))),
        limits['maxCanvasPixels'],
        'Frame pixels',
      );
      final packed = bytes[pos + 8];
      pos += 9;
      if (packed & 128 != 0) pos += 3 * (1 << ((packed & 7) + 1));
      pos++;
      blocks();
    } else {
      break;
    }
  }
}

Future<void> atomicWrite(String path, Uint8List bytes, bool overwrite) async {
  final target = p.normalize(p.absolute(path));
  validateText(target);
  final parent = Directory(p.dirname(target));
  Directory? temp;
  try {
    // Same filesystem as destination. Native helper supplies no-clobber/replace atomicity.
    temp = await parent.createTemp('.gifsicle-');
    final file = File(p.join(temp.path, 'output'));
    await file.writeAsBytes(bytes, flush: true);
    publishFile(file.path, target, overwrite);
  } on FileSystemException {
    throw const GifsicleException(
      code: GifsicleErrorCode.writeFailed,
      message: 'Cannot write output in destination directory.',
    );
  } finally {
    if (temp != null) await temp.delete(recursive: true);
  }
}

Future<Uint8List> readInput(String path, Object? limit) async {
  try {
    final f = File(path);
    enforce(await f.length(), limit, 'Input bytes');
    final bytes = await f.readAsBytes();
    enforce(bytes.length, limit, 'Input bytes');
    return bytes;
  } on FileSystemException {
    throw const GifsicleException(
      code: GifsicleErrorCode.readFailed,
      message: 'Cannot read input file.',
    );
  }
}

Future<Map<String, Object?>> executeStaged(Map request) async {
  final watch = Stopwatch()..start();
  final limits = request['limits'] as Map;
  final tokens = (request['tokens'] as List).cast<Map>();
  late Directory workspace;
  try {
    workspace = await Directory.systemTemp.createTemp('gifsicle-');
  } on FileSystemException {
    throw const GifsicleException(
      code: GifsicleErrorCode.workspaceFailure,
      message: 'Cannot create isolated workspace.',
    );
  }
  try {
    final args = <String>[],
        initial = <String, String>{},
        outputs = <String, Map>{};
    final ids = <String>{};
    var inputSize = 0;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i], type = t['type'];
      if (t['id'] != null && !ids.add(t['id'] as String)) {
        throw ArgumentError('Input and output IDs must be unique.');
      }
      if (type == 'option' || type == 'literal' || type == 'frame') {
        args.add(t['value'] as String);
        continue;
      }
      final name =
          '${type == 'inputFile' || type == 'inputBytes' ? 'input' : 'output'}_$i.gif';
      args.add(name);
      if (type == 'inputFile' || type == 'inputBytes') {
        final bytes = type == 'inputFile'
            ? await readInput(t['path'] as String, limits['maxInputBytes'])
            : t['bytes'] as Uint8List;
        inputSize += bytes.length;
        enforce(inputSize, limits['maxInputBytes'], 'Total input bytes');
        checkImageLimits(bytes, limits);
        await File(p.join(workspace.path, name)).writeAsBytes(bytes);
        initial[name] = sha256.convert(bytes).toString();
      } else {
        outputs[name] = t;
      }
    }
    final stdin = request['stdin'] as Uint8List?;
    if (stdin != null) {
      enforce(
        inputSize + stdin.length,
        limits['maxInputBytes'],
        'Total input bytes',
      );
      checkImageLimits(stdin, limits);
    }
    final result = invokeNative(args, stdin, workspace.path, isolated: true);
    final artifacts = <String, Map<String, Object?>>{},
        generated = <Map<String, Object?>>[];
    var outputSize = (result['stdout'] as Uint8List).length;
    enforce(outputSize, limits['maxOutputBytes'], 'Output bytes');
    // Collect and validate every artifact before publishing any caller files.
    final collected = <String, Uint8List>{};
    await for (final entity in workspace.list(followLinks: false)) {
      if (await FileSystemEntity.type(entity.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw const GifsicleException(
          code: GifsicleErrorCode.workspaceFailure,
          message: 'Workspace contains a non-regular output.',
        );
      }
      final name = p.basename(entity.path);
      final bytes = await File(entity.path).readAsBytes();
      if (initial[name] == sha256.convert(bytes).toString() &&
          !outputs.containsKey(name)) {
        continue;
      }
      outputSize += bytes.length;
      enforce(outputSize, limits['maxOutputBytes'], 'Total output bytes');
      collected[name] = bytes;
    }
    if (result['exitCode'] == 0) {
      for (final item in collected.entries) {
        final token = outputs[item.key];
        if (token != null) {
          final id = token['id'] as String;
          if (token['type'] == 'outputFile') {
            final path = p.absolute(token['path'] as String);
            await atomicWrite(path, item.value, token['overwrite'] as bool);
            artifacts[id] = {'path': path, 'size': item.value.length};
          } else {
            artifacts[id] = {'bytes': item.value};
          }
        } else if (request['collectGeneratedFiles'] == true) {
          generated.add({'relativePath': item.key, 'bytes': item.value});
        }
      }
    }
    return {
      ...result,
      'outputs': artifacts,
      'generatedFiles': generated,
      'elapsed': watch.elapsedMicroseconds,
    };
  } on FileSystemException {
    throw const GifsicleException(
      code: GifsicleErrorCode.workspaceFailure,
      message: 'Cannot prepare or collect isolated workspace.',
    );
  } finally {
    await workspace.delete(recursive: true);
  }
}
