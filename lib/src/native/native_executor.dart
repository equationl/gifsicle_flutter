import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import '../bindings/gifsicle_bindings_generated.dart' as native;
import '../models/models.dart';

GifsicleException nativeError(int code, String message) {
  if (code == 10) return GifsicleUnsupportedFeatureException(message);
  return GifsicleException(
    code: switch (code) {
      1 => GifsicleErrorCode.invalidArgument,
      2 => GifsicleErrorCode.invalidGif,
      3 => GifsicleErrorCode.unsupportedGif,
      4 => GifsicleErrorCode.outOfMemory,
      5 => GifsicleErrorCode.readFailed,
      6 => GifsicleErrorCode.writeFailed,
      9 => GifsicleErrorCode.abiMismatch,
      11 => GifsicleErrorCode.workspaceFailure,
      _ => GifsicleErrorCode.nativeFailure,
    },
    message: message.isEmpty ? 'Native execution failed.' : message,
    nativeCode: code,
  );
}

void checkAbi() {
  if (native.gs_bridge_abi_version() != 1) {
    throw nativeError(9, 'Bridge ABI mismatch.');
  }
}

Map<String, dynamic> nativeCapabilities() {
  checkAbi();
  return jsonDecode(native.gs_capabilities_json().cast<Utf8>().toDartString())
      as Map<String, dynamic>;
}

Map<String, Object?> invokeNative(
  List<String> arguments,
  Uint8List? input,
  String? directory, {
  required bool isolated,
}) {
  checkAbi();
  return using((arena) {
    final argv = arena<Pointer<Char>>(arguments.length + 1);
    for (var i = 0; i < arguments.length; i++) {
      argv[i] = arguments[i].toNativeUtf8(allocator: arena).cast();
    }
    final data = input == null
        ? nullptr.cast<Uint8>()
        : arena<Uint8>(input.length + 1);
    if (input != null) data.asTypedList(input.length).setAll(0, input);
    final cwd = directory == null
        ? nullptr.cast<Char>()
        : directory.toNativeUtf8(allocator: arena).cast<Char>();
    final result = (isolated ? native.gs_execute_isolated : native.gs_execute)(
      arguments.length,
      argv,
      data,
      input?.length ?? 0,
      cwd,
    );
    if (result == nullptr) {
      throw nativeError(4, 'Cannot allocate native result.');
    }
    try {
      final r = result.ref;
      final err = r.stderr_data == nullptr
          ? ''
          : utf8.decode(
              r.stderr_data.cast<Uint8>().asTypedList(r.stderr_length),
              allowMalformed: true,
            );
      if (r.bridge_status != 0) throw nativeError(r.bridge_status, err);
      return {
        'exitCode': r.exit_code,
        'stdout': r.stdout_data == nullptr
            ? Uint8List(0)
            : Uint8List.fromList(r.stdout_data.asTypedList(r.stdout_length)),
        'stderr': err,
      };
    } finally {
      native.gs_execution_result_free(result);
    }
  });
}

void publishFile(String temporary, String target, bool overwrite) {
  using((arena) {
    final code = native.gs_publish_file(
      temporary.toNativeUtf8(allocator: arena).cast(),
      target.toNativeUtf8(allocator: arena).cast(),
      overwrite ? 1 : 0,
    );
    if (code != 0) {
      throw GifsicleException(
        code: GifsicleErrorCode.writeFailed,
        message:
            'Cannot publish output file (destination exists, is inaccessible, or replacement failed).',
        nativeCode: code,
      );
    }
  });
}
