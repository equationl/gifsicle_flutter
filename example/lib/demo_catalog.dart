import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:gifsicle_flutter/gifsicle_flutter.dart';

class DemoResult {
  DemoResult(this.text, [this.images = const {}]);
  final String text;
  final Map<String, Uint8List> images;
}

class DemoCase {
  const DemoCase(
    this.id,
    this.title,
    this.description,
    this.api, {
    this.options,
  });
  final String id, title, description, api;
  final GifsicleOptions? options;
}

const demos = <DemoCase>[
  DemoCase(
    'default',
    '无损优化',
    '默认优化等级 3、sRGB，不主动减色或启用有损。显示体积、比例、耗时和警告。',
    'transformBytes · GifsicleBytesResult',
    options: GifsicleOptions(),
  ),
  DemoCase(
    'lossy',
    '有损与减色',
    'lossy=20、colors=16；体积可能下降，也可能损失颜色与细节。',
    'GifsicleOptions.lossy / colors',
    options: GifsicleOptions(lossy: 20, colors: 16),
  ),
  DemoCase(
    'exact',
    '精确尺寸',
    '输出 160×96；不保持原始宽高比。',
    'GifsicleResize.exact',
    options: GifsicleOptions(
      resize: GifsicleResize.exact(width: 160, height: 96),
    ),
  ),
  DemoCase(
    'fit',
    '边界内适配',
    '限制为 32×32，保持比例，默认不放大。',
    'GifsicleResize.fit',
    options: GifsicleOptions(resize: GifsicleResize.fit(width: 32, height: 32)),
  ),
  DemoCase(
    'upscale',
    '允许放大',
    '适配 160×160，allowUpscale=true。',
    'GifsicleResize.fit(allowUpscale: true)',
    options: GifsicleOptions(
      resize: GifsicleResize.fit(width: 160, height: 160, allowUpscale: true),
    ),
  ),
  DemoCase(
    'width',
    '指定宽度',
    '宽度 120，高度按比例计算。',
    'GifsicleResize.width',
    options: GifsicleOptions(resize: GifsicleResize.width(120)),
  ),
  DemoCase(
    'height',
    '指定高度',
    '高度 80，宽度按比例计算。',
    'GifsicleResize.height',
    options: GifsicleOptions(resize: GifsicleResize.height(80)),
  ),
  DemoCase(
    'scale',
    '缩放倍率',
    '水平、垂直均缩小一半；scale 与 resize 互斥。',
    'GifsicleScale',
    options: GifsicleOptions(scale: GifsicleScale(x: .5, y: .5)),
  ),
  DemoCase(
    'crop',
    '裁剪区域',
    '从左上角 (0,0) 裁出 16×16。',
    'GifsicleCrop',
    options: GifsicleOptions(
      crop: GifsicleCrop(x: 0, y: 0, width: 16, height: 16),
    ),
  ),
  DemoCase(
    'linear',
    '线性 Gamma / 无抖动',
    '减至 8 色，gamma=1，无抖动；便于观察色带。',
    'GifsicleGamma.linear · GifsicleDither.none',
    options: GifsicleOptions(
      colors: 8,
      gamma: GifsicleGamma.linear,
      dither: GifsicleDither.none,
    ),
  ),
  DemoCase(
    'gamma',
    '自定义 Gamma / 误差扩散',
    'gamma=2.2，16 色，Floyd–Steinberg 抖动。',
    'GifsicleGamma.value · GifsicleDither.floydSteinberg',
    options: GifsicleOptions(
      colors: 16,
      gamma: GifsicleGamma.value(2.2),
      dither: GifsicleDither.floydSteinberg,
    ),
  ),
  DemoCase(
    'ordered',
    '有序抖动',
    '16 色、有序矩阵抖动；有规则的空间纹理。',
    'GifsicleDither.ordered',
    options: GifsicleOptions(colors: 16, dither: GifsicleDither.ordered),
  ),
  DemoCase(
    'custom',
    '自定义抖动',
    '使用 atkinson；也可通过 CLI 输入其他受支持的矩阵参数。',
    'GifsicleDither(String)',
    options: GifsicleOptions(colors: 16, dither: GifsicleDither('atkinson')),
  ),
  DemoCase(
    'flags',
    '优化与兼容标志',
    '优化等级 1、交错输出、careful、移除注释。样本无注释时移除注释可能不改变内容。',
    'optimizationLevel / interlace / careful / removeComments',
    options: GifsicleOptions(
      optimizationLevel: 1,
      interlace: true,
      careful: true,
      removeComments: true,
    ),
  ),
  DemoCase(
    'nointerlace',
    '关闭优化 / 交错',
    '优化等级 0、显式关闭交错；null 表示不指定交错状态。',
    'optimizationLevel=0 · interlace=false',
    options: GifsicleOptions(optimizationLevel: 0, interlace: false),
  ),
  DemoCase(
    'file',
    '文件转换与同路径替换',
    '在应用临时目录创建中文文件，转换到新文件，再 overwrite=true 原子替换同一文件。结束后清理演示目录。',
    'transformFile · GifsicleFileResult',
  ),
  DemoCase(
    'memory',
    '声明内存输出',
    '使用 option、literal、inputBytes 和 outputMemory。outputs 以 ID 索引；stdout 不一定包含 GIF。',
    'execute · GifsicleMemoryOutputArtifact',
  ),
  DemoCase(
    'fileTokens',
    '声明文件输入输出',
    'inputFile → outputFile，读取文件结果和大小；仅操作演示临时目录。',
    'execute · GifsicleFileOutputArtifact',
  ),
  DemoCase(
    'frames',
    '多输入与帧选择',
    '两个内存输入各选择第 0 帧，合并为动画。Token 顺序具有意义。',
    'inputBytes · frameSelector',
  ),
  DemoCase(
    'explode',
    '拆帧并收集文件',
    'explode 将动画拆为独立 GIF，通过 generatedFiles 返回文件名及字节。',
    'collectGeneratedFiles · GifsicleGeneratedFile',
  ),
  DemoCase('batch', '批处理', '优化两个暂存输入，收集被修改的文件；不修改原始样本。', 'execute --batch'),
  DemoCase(
    'stdin',
    '标准输入 / 输出',
    'stdin 提供 GIF；禁用自动文件收集，读取二进制 stdout。四种资源限制一起启用。',
    'GifsicleCommand.stdin / limits / collectGeneratedFiles',
  ),
  DemoCase(
    'direct',
    '直接参数与工作目录',
    '将参数数组交给 CLI，读取演示工作目录内的相对路径。不会使用 shell 分词。',
    'executeArguments · workingDirectory',
  ),
  DemoCase(
    'errors',
    '错误分类与恢复',
    '演示参数错误、损坏 GIF、资源限制、CLI 非零退出、禁止覆盖、外部命令拒绝；随后执行正常转换验证恢复。',
    'GifsicleException · GifsicleErrorCode · isSuccess',
  ),
  DemoCase(
    'lifecycle',
    '队列与生命周期',
    '同时提交三个转换，等待队列完成，disposeForTesting 排空并关闭 Worker；下一次调用自动重建。此 API 用于测试清理。',
    'Future.wait · disposeForTesting',
  ),
];

bool isGif(Uint8List b) =>
    b.length >= 6 &&
    ['GIF87a', 'GIF89a'].contains(String.fromCharCodes(b.take(6)));

DemoResult describeExecution(GifsicleExecutionResult r) {
  final images = <String, Uint8List>{};
  if (isGif(r.stdout)) images['stdout.gif'] = r.stdout;
  final lines = <String>[
    'exitCode=${r.exitCode} · isSuccess=${r.isSuccess}',
    '耗时 ${r.elapsed.inMicroseconds} μs · stdout ${r.stdout.length} 字节',
    if (!isGif(r.stdout)) utf8.decode(r.stdout, allowMalformed: true),
    'stderr / 警告：${r.stderr.isEmpty ? '无' : r.stderr}',
  ];
  for (final e in r.outputs.values) {
    if (e is GifsicleMemoryOutputArtifact) {
      lines.add('内存输出 ${e.id}: ${e.bytes.length} 字节');
      if (isGif(e.bytes)) images[e.id] = e.bytes;
    } else if (e is GifsicleFileOutputArtifact) {
      lines.add('文件输出 ${e.id}: ${e.path} (${e.size} 字节)');
    }
  }
  for (final f in r.generatedFiles) {
    lines.add('生成文件 ${f.relativePath}: ${f.bytes.length} 字节');
    if (isGif(f.bytes)) images[f.relativePath] = f.bytes;
  }
  return DemoResult(lines.join('\n'), images);
}

Future<DemoResult> runDemo(DemoCase demo, Uint8List sample) async {
  final options = demo.options;
  if (options != null) {
    final r = await Gifsicle.transformBytes(sample, options: options);
    return DemoResult(
      '参数：${options.toArguments().join(' ')}\n'
      '${r.inputSize} → ${r.outputSize} 字节\n输出/输入比 ${(r.compressionRatio * 100).toStringAsFixed(1)}%（越小越省空间）\n'
      '耗时 ${r.elapsed.inMicroseconds} μs\n警告：${r.warnings.isEmpty ? '无' : r.warnings.join('\n')}',
      {'结果': r.bytes},
    );
  }
  // 每次操作使用独立目录，不接触用户文件；finally 覆盖成功和失败路径。
  final dir = await Directory.systemTemp.createTemp('gifsicle-demo-');
  try {
    final input = File('${dir.path}/中文输入.gif');
    final output = File('${dir.path}/输出.gif');
    await input.writeAsBytes(sample);
    GifsicleArgument bytes(String id) => GifsicleArgument.inputBytes(
      id: id,
      bytes: sample,
      suggestedName: '动画.gif',
    );
    GifsicleCommand command(List<GifsicleArgument> args) =>
        GifsicleCommand(arguments: args);
    switch (demo.id) {
      case 'file':
        final r = await Gifsicle.transformFile(
          inputPath: input.path,
          outputPath: output.path,
        );
        final same = await Gifsicle.transformFile(
          inputPath: output.path,
          outputPath: output.path,
          overwrite: true,
          options: const GifsicleOptions(resize: GifsicleResize.width(120)),
        );
        return DemoResult(
          'outputPath=${r.outputPath}\n${r.inputSize} → ${r.outputSize} 字节 · ${r.elapsed.inMicroseconds} μs\n警告=${r.warnings}\n同路径替换后 ${same.outputSize} 字节\n演示临时文件将在返回后删除。',
          {'文件内容': await output.readAsBytes()},
        );
      case 'memory':
        return describeExecution(
          await Gifsicle.execute(
            command([
              const GifsicleArgument.option('--resize-width'),
              const GifsicleArgument.literal('120'),
              bytes('source'),
              const GifsicleArgument.option('--output'),
              const GifsicleArgument.outputMemory(
                id: 'result',
                suggestedName: '优化.gif',
              ),
            ]),
          ),
        );
      case 'fileTokens':
        final r = await Gifsicle.execute(
          command([
            GifsicleArgument.inputFile(id: 'source', path: input.path),
            const GifsicleArgument.option('--output'),
            GifsicleArgument.outputFile(
              id: 'result',
              path: output.path,
              overwrite: false,
            ),
          ]),
        );
        final view = describeExecution(r);
        return DemoResult('${view.text}\n演示临时文件将在返回后删除。', {
          '文件内容': await output.readAsBytes(),
        });
      case 'frames':
        return describeExecution(
          await Gifsicle.execute(
            command([
              bytes('first'),
              const GifsicleArgument.frameSelector('#0'),
              bytes('second'),
              const GifsicleArgument.frameSelector('#0'),
            ]),
          ),
        );
      case 'explode':
      case 'batch':
        return describeExecution(
          await Gifsicle.execute(
            command([
              GifsicleArgument.option('--${demo.id}'),
              const GifsicleArgument.option('--optimize=3'),
              bytes('first'),
              if (demo.id == 'batch') bytes('second'),
            ]),
          ),
        );
      case 'stdin':
        return describeExecution(
          await Gifsicle.execute(
            GifsicleCommand(
              arguments: const [GifsicleArgument.option('--optimize=3')],
              stdin: sample,
              collectGeneratedFiles: false,
              limits: const GifsicleLimits(
                maxInputBytes: 1048576,
                maxOutputBytes: 1048576,
                maxFrameCount: 100,
                maxCanvasPixels: 1048576,
              ),
            ),
          ),
        );
      case 'direct':
        return describeExecution(
          await Gifsicle.executeArguments([
            '--info',
            '中文输入.gif',
          ], workingDirectory: dir.path),
        );
      case 'errors':
        final lines = <String>[];
        Future<void> expectError(
          String label,
          Future<Object?> Function() run,
        ) async {
          try {
            await run();
            throw StateError('$label 未触发预期错误');
          } on GifsicleException catch (e) {
            lines.add(
              '$label: ${e.code.name}, nativeCode=${e.nativeCode}, message=${e.message}, warnings=${e.warnings}',
            );
          } on ArgumentError catch (e) {
            lines.add('$label: $e');
          }
        }
        await expectError(
          '参数范围',
          () => Gifsicle.transformBytes(
            sample,
            options: const GifsicleOptions(colors: 1),
          ),
        );
        await expectError(
          '损坏 GIF',
          () => Gifsicle.transformBytes(Uint8List.fromList([1, 2, 3])),
        );
        await expectError(
          '输入大小限制',
          () => Gifsicle.execute(
            GifsicleCommand(
              arguments: [bytes('source')],
              limits: const GifsicleLimits(maxInputBytes: 1),
            ),
          ),
        );
        await expectError(
          '禁止覆盖',
          () => Gifsicle.transformFile(
            inputPath: input.path,
            outputPath: input.path,
          ),
        );
        await expectError(
          '外部命令开关',
          () => Gifsicle.execute(
            const GifsicleCommand(arguments: [], allowExternalCommands: true),
          ),
        );
        await expectError(
          '直接 API 外部命令开关',
          () => Gifsicle.executeArguments([
            '--help',
          ], allowExternalCommands: true),
        );
        final failed = await Gifsicle.executeArguments(['--not-a-real-option']);
        if (failed.isSuccess) throw StateError('预期 CLI 非零退出');
        lines.add(
          'CLI 退出码=${failed.exitCode}, isSuccess=${failed.isSuccess}\n${failed.stderr}',
        );
        final recovered = await Gifsicle.transformBytes(sample);
        return DemoResult('${lines.join('\n\n')}\n\n后续转换恢复成功', {
          '恢复后的 GIF': recovered.bytes,
        });
      case 'lifecycle':
        final results = await Future.wait(
          List.generate(
            3,
            (i) => Gifsicle.transformBytes(
              sample,
              options: GifsicleOptions(optimizationLevel: i),
            ),
          ),
        );
        await Gifsicle.disposeForTesting();
        final restarted = await Gifsicle.transformBytes(sample);
        return DemoResult('排队完成 ${results.length} 个请求；Worker 已关闭并重建。', {
          '重建后的 GIF': restarted.bytes,
        });
      default:
        throw StateError('未知演示 ${demo.id}');
    }
  } finally {
    await dir.delete(recursive: true);
  }
}
