import 'dart:typed_data';

enum GifsicleErrorCode {
  invalidArgument,
  invalidGif,
  unsupportedGif,
  outOfMemory,
  readFailed,
  writeFailed,
  nativeFailure,
  cancelled,
  abiMismatch,
  unsupportedFeature,
  workspaceFailure,
}

class GifsicleException implements Exception {
  const GifsicleException({
    required this.code,
    required this.message,
    this.nativeCode,
    this.warnings = const [],
  });
  final GifsicleErrorCode code;
  final String message;
  final int? nativeCode;
  final List<String> warnings;
  @override
  String toString() => 'GifsicleException(${code.name}): $message';
}

final class GifsicleUnsupportedFeatureException extends GifsicleException {
  const GifsicleUnsupportedFeatureException(String message)
    : super(code: GifsicleErrorCode.unsupportedFeature, message: message);
}

enum GifsicleSupportLevel { supported, partiallySupported, unsupported }

enum GifsicleFeature {
  stdin,
  stdout,
  isolatedWorkspace,
  directFileSystemAccess,
  multipleInputs,
  generatedFiles,
}

final class GifsicleOptionCapability {
  const GifsicleOptionCapability({required this.level, this.reason});
  final GifsicleSupportLevel level;
  final String? reason;
}

final class GifsicleCapabilities {
  GifsicleCapabilities.fromJson(Map<String, dynamic> json)
    : platform = json['platform'] as String,
      gifsicleVersion = json['gifsicleVersion'] as String,
      bridgeAbiVersion = json['bridgeAbiVersion'] as int,
      options = Map.unmodifiable(
        Map<String, dynamic>.from(json['options'] as Map).map(
          (key, value) => MapEntry(
            key,
            GifsicleOptionCapability(
              level: GifsicleSupportLevel.values.byName(
                value['level'] as String,
              ),
              reason: value['reason'] as String?,
            ),
          ),
        ),
      ),
      features = Set.unmodifiable(
        (json['features'] as List).map(
          (e) => GifsicleFeature.values.byName(e as String),
        ),
      );
  final String platform;
  final String gifsicleVersion;
  final int bridgeAbiVersion;
  final Map<String, GifsicleOptionCapability> options;
  final Set<GifsicleFeature> features;
  bool supportsOption(String name) =>
      option(name).level == GifsicleSupportLevel.supported;
  GifsicleOptionCapability option(String name) =>
      options[name] ??
      const GifsicleOptionCapability(
        level: GifsicleSupportLevel.unsupported,
        reason: 'Unknown option; consult the CLI manifest.',
      );
}

final class GifsicleLimits {
  const GifsicleLimits({
    this.maxInputBytes,
    this.maxOutputBytes,
    this.maxFrameCount,
    this.maxCanvasPixels,
  });
  final int? maxInputBytes, maxOutputBytes, maxFrameCount, maxCanvasPixels;
  Map<String, Object?> toMessage() {
    final values = {
      'maxInputBytes': maxInputBytes,
      'maxOutputBytes': maxOutputBytes,
      'maxFrameCount': maxFrameCount,
      'maxCanvasPixels': maxCanvasPixels,
    };
    for (final v in values.values) {
      if (v != null && v <= 0) throw ArgumentError('Limits must be positive.');
    }
    return values;
  }
}

sealed class GifsicleArgument {
  const GifsicleArgument();
  const factory GifsicleArgument.option(String value) = GifsicleOptionArgument;
  const factory GifsicleArgument.literal(String value) =
      GifsicleLiteralArgument;
  const factory GifsicleArgument.frameSelector(String value) =
      GifsicleFrameSelectorArgument;
  factory GifsicleArgument.inputFile({
    required String id,
    required String path,
  }) = GifsicleInputFileArgument;
  factory GifsicleArgument.inputBytes({
    required String id,
    required Uint8List bytes,
    String suggestedName,
  }) = GifsicleInputBytesArgument;
  factory GifsicleArgument.outputFile({
    required String id,
    required String path,
    bool overwrite,
  }) = GifsicleOutputFileArgument;
  const factory GifsicleArgument.outputMemory({
    required String id,
    String suggestedName,
  }) = GifsicleOutputMemoryArgument;
  Map<String, Object?> toMessage();
}

final class GifsicleOptionArgument extends GifsicleArgument {
  const GifsicleOptionArgument(this.value);
  final String value;
  @override
  Map<String, Object?> toMessage() => {'type': 'option', 'value': value};
}

final class GifsicleLiteralArgument extends GifsicleArgument {
  const GifsicleLiteralArgument(this.value);
  final String value;
  @override
  Map<String, Object?> toMessage() => {'type': 'literal', 'value': value};
}

final class GifsicleFrameSelectorArgument extends GifsicleArgument {
  const GifsicleFrameSelectorArgument(this.value);
  final String value;
  @override
  Map<String, Object?> toMessage() => {'type': 'frame', 'value': value};
}

final class GifsicleInputFileArgument extends GifsicleArgument {
  GifsicleInputFileArgument({required this.id, required this.path});
  final String id, path;
  @override
  Map<String, Object?> toMessage() => {
    'type': 'inputFile',
    'id': id,
    'path': path,
  };
}

final class GifsicleInputBytesArgument extends GifsicleArgument {
  GifsicleInputBytesArgument({
    required this.id,
    required this.bytes,
    this.suggestedName = 'input.gif',
  });
  final String id, suggestedName;
  final Uint8List bytes;
  @override
  Map<String, Object?> toMessage() => {
    'type': 'inputBytes',
    'id': id,
    'bytes': bytes,
  };
}

final class GifsicleOutputFileArgument extends GifsicleArgument {
  GifsicleOutputFileArgument({
    required this.id,
    required this.path,
    this.overwrite = false,
  });
  final String id, path;
  final bool overwrite;
  @override
  Map<String, Object?> toMessage() => {
    'type': 'outputFile',
    'id': id,
    'path': path,
    'overwrite': overwrite,
  };
}

final class GifsicleOutputMemoryArgument extends GifsicleArgument {
  const GifsicleOutputMemoryArgument({
    required this.id,
    this.suggestedName = 'output.gif',
  });
  final String id, suggestedName;
  @override
  Map<String, Object?> toMessage() => {'type': 'outputMemory', 'id': id};
}

final class GifsicleCommand {
  const GifsicleCommand({
    required this.arguments,
    this.stdin,
    this.collectGeneratedFiles = true,
    this.allowExternalCommands = false,
    this.limits = const GifsicleLimits(),
  });
  final List<GifsicleArgument> arguments;
  final Uint8List? stdin;
  final bool collectGeneratedFiles, allowExternalCommands;
  final GifsicleLimits limits;
}

final class GifsicleGamma {
  const GifsicleGamma.value(this.value);
  const GifsicleGamma._(this.value);
  static const srgb = GifsicleGamma._(null), linear = GifsicleGamma._(1);
  final double? value;
  String get argument {
    if (value != null && (!value!.isFinite || value! <= 0)) {
      throw ArgumentError('Gamma must be finite and positive.');
    }
    return value?.toString() ?? 'srgb';
  }
}

final class GifsicleDither {
  const GifsicleDither(this.value);
  static const none = GifsicleDither('none'),
      floydSteinberg = GifsicleDither('floyd-steinberg'),
      ordered = GifsicleDither('ordered');
  final String value;
  void validate() {
    final parts = value.split(',');
    const names = {
      'none',
      'posterize',
      'default',
      'floyd-steinberg',
      'fs',
      'atkinson',
      'at',
      'o3',
      'o3x3',
      'o4',
      'o4x4',
      'o8',
      'o8x8',
      'ro64',
      'ro64x64',
      'o',
      'ordered',
      'diag45',
      'diagonal',
      'halftone',
      'half',
      'trihalftone',
      'trihalf',
      'sqhalftone',
      'sqhalf',
      'squarehalftone',
    };
    if (!names.contains(parts.first) || parts.length > 5) {
      throw ArgumentError('Invalid dither configuration.');
    }
    for (final p in parts.skip(1)) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) {
        throw ArgumentError('Dither matrix parameters must be 0..255.');
      }
    }
  }
}

final class GifsicleScale {
  const GifsicleScale({required this.x, required this.y});
  final double x, y;
}

sealed class GifsicleResize {
  const GifsicleResize();
  const factory GifsicleResize.exact({
    required int width,
    required int height,
  }) = GifsicleResizeExact;
  const factory GifsicleResize.fit({
    required int width,
    required int height,
    bool allowUpscale,
  }) = GifsicleResizeFit;
  const factory GifsicleResize.width(int width) = GifsicleResizeWidth;
  const factory GifsicleResize.height(int height) = GifsicleResizeHeight;
  String get argument;
  static void positive(int v) {
    if (v <= 0 || v > 65535) {
      throw ArgumentError('GIF dimensions must be 1..65535.');
    }
  }
}

final class GifsicleResizeExact extends GifsicleResize {
  const GifsicleResizeExact({required this.width, required this.height});
  final int width, height;
  @override
  String get argument {
    GifsicleResize.positive(width);
    GifsicleResize.positive(height);
    return '--resize=${width}x$height';
  }
}

final class GifsicleResizeFit extends GifsicleResize {
  const GifsicleResizeFit({
    required this.width,
    required this.height,
    this.allowUpscale = false,
  });
  final int width, height;
  final bool allowUpscale;
  @override
  String get argument {
    GifsicleResize.positive(width);
    GifsicleResize.positive(height);
    return '--resize-${allowUpscale ? 'touch' : 'fit'}=${width}x$height';
  }
}

final class GifsicleResizeWidth extends GifsicleResize {
  const GifsicleResizeWidth(this.width);
  final int width;
  @override
  String get argument {
    GifsicleResize.positive(width);
    return '--resize-width=$width';
  }
}

final class GifsicleResizeHeight extends GifsicleResize {
  const GifsicleResizeHeight(this.height);
  final int height;
  @override
  String get argument {
    GifsicleResize.positive(height);
    return '--resize-height=$height';
  }
}

final class GifsicleCrop {
  const GifsicleCrop({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
  final int x, y, width, height;
  String get argument {
    if (x < 0 || y < 0 || x > 65535 || y > 65535) {
      throw ArgumentError('Crop position out of range.');
    }
    GifsicleResize.positive(width);
    GifsicleResize.positive(height);
    return '--crop=$x,$y+${width}x$height';
  }
}

final class GifsicleOptions {
  const GifsicleOptions({
    this.optimizationLevel = 3,
    this.lossy,
    this.colors,
    this.gamma = GifsicleGamma.srgb,
    this.dither,
    this.resize,
    this.scale,
    this.crop,
    this.interlace,
    this.careful = false,
    this.removeComments = false,
  });
  final int optimizationLevel;
  final int? lossy, colors;
  final GifsicleGamma gamma;
  final GifsicleDither? dither;
  final GifsicleResize? resize;
  final GifsicleScale? scale;
  final GifsicleCrop? crop;
  final bool? interlace;
  final bool careful, removeComments;
  List<String> toArguments() {
    if (optimizationLevel < 0 || optimizationLevel > 3) {
      throw ArgumentError('optimizationLevel must be 0..3.');
    }
    if (lossy != null && (lossy! < 0 || lossy! > 200)) {
      throw ArgumentError('lossy must be 0..200.');
    }
    if (colors != null && (colors! < 2 || colors! > 256)) {
      throw ArgumentError('colors must be 2..256.');
    }
    if (resize != null && scale != null) {
      throw ArgumentError('resize and scale are mutually exclusive.');
    }
    if (scale != null &&
        (!scale!.x.isFinite ||
            !scale!.y.isFinite ||
            scale!.x <= 0 ||
            scale!.y <= 0)) {
      throw ArgumentError('Scale must be finite and positive.');
    }
    if (dither != null &&
        (dither!.value.isEmpty || dither!.value.contains('\u0000'))) {
      throw ArgumentError('Invalid dither configuration.');
    }
    dither?.validate();
    return [
      '--optimize=$optimizationLevel',
      if (lossy != null) '--lossy=$lossy',
      if (colors != null) '--colors=$colors',
      '--gamma=${gamma.argument}',
      if (dither != null) '--dither=${dither!.value}',
      if (crop != null) crop!.argument,
      if (resize != null) resize!.argument,
      if (scale != null) '--scale=${scale!.x}x${scale!.y}',
      if (interlace != null) '--${interlace! ? '' : 'no-'}interlace',
      if (careful) '--careful',
      if (removeComments) '--no-comments',
    ];
  }
}

sealed class GifsicleOutputArtifact {
  const GifsicleOutputArtifact(this.id);
  final String id;
}

final class GifsicleMemoryOutputArtifact extends GifsicleOutputArtifact {
  const GifsicleMemoryOutputArtifact(super.id, this.bytes);
  final Uint8List bytes;
}

final class GifsicleFileOutputArtifact extends GifsicleOutputArtifact {
  const GifsicleFileOutputArtifact(super.id, this.path, this.size);
  final String path;
  final int size;
}

final class GifsicleGeneratedFile {
  const GifsicleGeneratedFile({
    required this.relativePath,
    required this.bytes,
  });
  final String relativePath;
  final Uint8List bytes;
}

final class GifsicleExecutionResult {
  const GifsicleExecutionResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.outputs,
    required this.generatedFiles,
    required this.elapsed,
  });
  final int exitCode;
  final Uint8List stdout;
  final String stderr;
  final Map<String, GifsicleOutputArtifact> outputs;
  final List<GifsicleGeneratedFile> generatedFiles;
  final Duration elapsed;
  bool get isSuccess => exitCode == 0;
}

final class GifsicleBytesResult {
  const GifsicleBytesResult({
    required this.bytes,
    required this.inputSize,
    required this.outputSize,
    required this.elapsed,
    required this.warnings,
  });
  final Uint8List bytes;
  final int inputSize, outputSize;
  final Duration elapsed;
  final List<String> warnings;
  double get compressionRatio => outputSize / inputSize;
}

final class GifsicleFileResult {
  const GifsicleFileResult({
    required this.outputPath,
    required this.inputSize,
    required this.outputSize,
    required this.elapsed,
    required this.warnings,
  });
  final String outputPath;
  final int inputSize, outputSize;
  final Duration elapsed;
  final List<String> warnings;
}
