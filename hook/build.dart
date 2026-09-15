import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final os = input.config.code.targetOS;
    if (![OS.android, OS.iOS, OS.macOS, OS.windows].contains(os)) {
      throw UnsupportedError(
        'gifsicle_flutter supports Android, iOS, macOS and Windows.',
      );
    }
    final windows = os == OS.windows;
    await CBuilder.library(
      name: 'gifsicle_flutter',
      assetName: 'src/bindings/gifsicle_bindings_generated.dart',
      sources: [
        'src/bridge/gifsicle_bridge.c',
        'src/bridge/gifsicle_context.c',
        'src/bridge/gifsicle_files.c',
        'src/bridge/gifsicle_io.c',
        for (final name in [
          'clp',
          'fmalloc',
          'giffunc',
          'gifread',
          'gifunopt',
          'gifwrite',
          'kcolor',
          'merge',
          'optimize',
          'quantize',
          'support',
          'xform',
          'gifsicle',
        ])
          'src/third_party/gifsicle/src/$name.c',
      ],
      includes: [
        'src/bridge',
        'src/third_party/gifsicle/include',
        'src/third_party/gifsicle/src',
      ],
      defines: {
        'HAVE_CONFIG_H': '1',
        if (windows) '_CRT_SECURE_NO_WARNINGS': '1',
      },
      flags: windows
          ? ['/std:c11', '/utf-8', '/O2']
          : [
              '-std=c11',
              '-O3',
              '-fvisibility=hidden',
              '-Wall',
              '-Wextra',
              '-Wno-unused-parameter',
              if (os == OS.android) ...[
                '-Wl,-z,max-page-size=16384',
                '-Wl,-z,common-page-size=16384',
                '-lm',
              ],
            ],
    ).run(input: input, output: output, logger: Logger('gifsicle_flutter'));
  });
}
