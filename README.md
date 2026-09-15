# gifsicle_flutter

用于 Flutter 的 GIF 处理插件，内置 Gifsicle 1.96，通过 Dart FFI 在应用进程内完成 GIF 优化、压缩、缩放、裁剪和动画编辑，无需单独安装 Gifsicle 命令行程序。

提供两种使用方式：常见操作使用类型化 Dart API；复杂动画处理使用保留参数顺序的 Gifsicle CLI 接口。耗时处理在后台 isolate 中执行。

## 功能

- **GIF 优化**：无损优化、可选有损压缩、减色、Gamma 和抖动处理。
- **尺寸调整**：指定宽高、等比适配、按宽度或高度缩放、倍率缩放及区域裁剪。
- **动画处理**：多输入合并、帧选择、拆帧、批处理以及 GIF 信息读取。
- **多种输入输出**：内存字节、文件、stdin/stdout、按 ID 获取输出及收集生成文件。
- **文件处理**：支持 Unicode 路径、禁止覆盖和同路径原子替换。
- **运行时能力查询**：获取版本、平台特性及各 CLI 选项的支持状态。

## 平台与环境

| 平台 | 当前状态 |
| --- | --- |
| Android | 支持；已在 4 KB / 16 KB 模拟器验证，原生库按 16 KB 对齐构建 |
| iOS | 支持；已在模拟器验证，真机运行尚未验证 |
| macOS | 支持；已在 Apple Silicon 验证 |
| Windows | 已提供构建配置，编译和运行尚未验证 |
| Linux / Web | 暂不支持 |

- Flutter **3.38.0+**，Dart **3.10.0+**，最低版本组合尚未单独验证。
- 需要目标平台的 Flutter 原生构建工具链；Build Hooks 会随应用构建编译内置源码，无需向消费项目复制 CMake、Gradle 或 Pod 配置。
- 当前版本为 **0.1.0 开发版**，API 和平台支持仍可能调整。

## 安装

当前开发版可通过 Git 仓库接入：

```yaml
dependencies:
  gifsicle_flutter:
    git:
      url: https://github.com/equationl/gifsicle_flutter.git
      ref: main
```

需要固定版本时，将 `ref` 替换为具体提交。也可以克隆仓库后通过本地路径接入：

```yaml
dependencies:
  gifsicle_flutter:
    path: /path/to/gifsicle_flutter
```

执行：

```sh
flutter pub get
```

然后导入：

```dart
import 'package:gifsicle_flutter/gifsicle_flutter.dart';
```

## 快速开始

### 优化内存中的 GIF

```dart
import 'dart:typed_data';
import 'package:gifsicle_flutter/gifsicle_flutter.dart';

Future<Uint8List> optimizeGif(Uint8List input) async {
  final result = await Gifsicle.transformBytes(input);

  print('${result.inputSize} → ${result.outputSize} 字节');
  print('输出 / 输入比例：${result.compressionRatio}');
  print('处理耗时：${result.elapsed}');
  print('警告：${result.warnings}');

  return result.bytes;
}
```

默认使用优化等级 `3` 和 sRGB Gamma，不主动启用有损压缩或减色。优化不保证每个文件都变小；`compressionRatio` 为输出大小除以输入大小，小于 `1` 表示体积减小。

### 缩放并保存文件

```dart
final result = await Gifsicle.transformFile(
  inputPath: '/path/to/input.gif',
  outputPath: '/path/to/output.gif',
  options: const GifsicleOptions(
    resize: GifsicleResize.fit(width: 640, height: 480),
  ),
);

print('保存位置：${result.outputPath}');
print('${result.inputSize} → ${result.outputSize} 字节');
```

文件路径必须在应用可访问的范围内。`overwrite` 默认为 `false`，目标已存在时抛出异常；需要替换已有文件或输入输出路径相同时，显式设置 `overwrite: true`。

### 有损压缩与减色

```dart
final result = await Gifsicle.transformBytes(
  inputBytes,
  options: const GifsicleOptions(
    lossy: 20,
    colors: 128,
    dither: GifsicleDither.floydSteinberg,
  ),
);
```

有损压缩和减色可能改变图像细节及颜色，请结合输出预览选择参数。

## 转换参数

`GifsicleOptions` 可用于 `transformBytes` 和 `transformFile`。

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `optimizationLevel` | `3` | 优化等级，范围 `0..3` |
| `lossy` | `null` | 不指定有损参数；显式设置范围为 `0..200` |
| `colors` | `null` | 不主动减色；指定调色板颜色数，范围 `2..256` |
| `gamma` | `GifsicleGamma.srgb` | 支持 `srgb`、`linear` 或 `GifsicleGamma.value(2.2)` |
| `dither` | `null` | 不指定抖动参数；可选 `none`、`floydSteinberg`、`ordered` 或自定义方法 |
| `resize` | `null` | 调整尺寸，见下表 |
| `scale` | `null` | `GifsicleScale(x: 0.5, y: 0.5)`；倍率须为有限正数，与 `resize` 互斥 |
| `crop` | `null` | `GifsicleCrop(x: 0, y: 0, width: 100, height: 100)` |
| `interlace` | `null` | 不指定交错状态；`true` 开启，`false` 关闭 |
| `careful` | `false` | 开启 Gifsicle 的 careful 模式，提高输出兼容性 |
| `removeComments` | `false` | 是否移除 GIF 注释 |

| 尺寸 API | 行为 |
| --- | --- |
| `GifsicleResize.exact(width: 320, height: 240)` | 指定输出宽高，可能改变宽高比 |
| `GifsicleResize.fit(width: 320, height: 240)` | 等比适配边界，默认不放大 |
| `GifsicleResize.fit(width: 320, height: 240, allowUpscale: true)` | 等比适配，允许放大 |
| `GifsicleResize.width(320)` | 指定宽度，高度按比例调整 |
| `GifsicleResize.height(240)` | 指定高度，宽度按比例调整 |

显式宽高取值范围为 `1..65535`。可以通过 `options.toArguments()` 查看对应的 CLI 参数。

## 高级 CLI 接口

### 隔离输入与声明输出

`execute` 接受 `GifsicleCommand`，按列表顺序处理参数，并自动暂存输入、收集输出。不同输入和输出的 ID 必须唯一。

```dart
final result = await Gifsicle.execute(
  GifsicleCommand(
    arguments: [
      const GifsicleArgument.option('--resize-width'),
      const GifsicleArgument.literal('320'),
      GifsicleArgument.inputBytes(id: 'source', bytes: inputBytes),
      const GifsicleArgument.frameSelector('#0-2'),
      const GifsicleArgument.option('--output'),
      const GifsicleArgument.outputMemory(id: 'preview'),
    ],
  ),
);

if (result.isSuccess) {
  final output = result.outputs['preview'] as GifsicleMemoryOutputArtifact;
  final Uint8List gif = output.bytes;
  print('输出 ${gif.length} 字节');
} else {
  print('CLI 退出码：${result.exitCode}\n${result.stderr}');
}
```

本例选择输入动画的前三帧，因此输入须有对应帧。输入文件可改用 `inputFile(id: ..., path: ...)`；输出文件可改用 `outputFile(id: ..., path: ..., overwrite: ...)`，结果类型为 `GifsicleFileOutputArtifact`，包含 `path` 和 `size`。

声明输出前需要保留 `--output` 参数。`suggestedName` 仅是提示，不决定实际暂存文件名。多文件输出不提供跨文件事务原子性。

### 拆分动画帧

```dart
final result = await Gifsicle.execute(
  GifsicleCommand(
    arguments: [
      const GifsicleArgument.option('--explode'),
      GifsicleArgument.inputFile(id: 'animation', path: inputPath),
    ],
  ),
);

if (result.isSuccess) {
  for (final file in result.generatedFiles) {
    print('${file.relativePath}: ${file.bytes.length} 字节');
    // file.bytes 可用于预览或保存，不依赖已经清理的暂存目录。
  }
}
```

`collectGeneratedFiles` 默认为 `true`；batch 修改的暂存输入也会被收集。不需要收集时可设为 `false`。

### 直接传入参数数组

```dart
import 'dart:convert';

final help = await Gifsicle.executeArguments(['--help']);
print(utf8.decode(help.stdout, allowMalformed: true));

final result = await Gifsicle.executeArguments(
  ['--optimize=3'],
  stdin: inputBytes,
);
```

每个数组元素对应一个参数，不进行 Shell 分词。`stdout` 始终为 `Uint8List`：处理 GIF 时可能是二进制，只有 help/info 等文本结果才应按 UTF-8 解码。

`executeArguments` 直接访问参数中的文件路径，支持通过 `workingDirectory` 指定相对路径的解析目录，不自动收集生成文件。请只传入可信参数；需要隔离文件处理时使用 `execute`。

完整参数说明可通过 `--help` 获取，或查阅随包提供的 [Gifsicle 手册](src/third_party/gifsicle/gifsicle.1)。

## 错误处理与资源限制

快捷转换接口失败时抛出异常；CLI 接口通过 `exitCode` / `isSuccess` 表达正常 CLI 执行失败，桥接或文件处理错误仍会抛出异常。

```dart
try {
  final result = await Gifsicle.transformBytes(inputBytes);
  print(result.outputSize);
} on GifsicleException catch (error) {
  print('${error.code}: ${error.message}');
  print('原生错误码：${error.nativeCode}');
} on ArgumentError catch (error) {
  print('参数不合法：$error');
}
```

可以在 `GifsicleCommand` 中设置资源限制：

```dart
const limits = GifsicleLimits(
  maxInputBytes: 64 * 1024 * 1024,
  maxOutputBytes: 64 * 1024 * 1024,
  maxFrameCount: 1000,
  maxCanvasPixels: 4096 * 4096,
);
```

通过 `GifsicleCommand(arguments: [...], limits: limits)` 使用。各项默认 `null`，表示不指定上限；上述数值仅为配置示例，请按设备和业务选择。输入结构在原生解码前检查，输出大小在收集时检查，因此输出限制不是原生峰值内存硬上限。

## 版本与能力查询

```dart
print(Gifsicle.gifsicleVersion);
print(Gifsicle.bridgeVersion);

final capabilities = await Gifsicle.capabilities();
final resize = capabilities.option('--resize');
print('${capabilities.platform}: ${resize.level}');
print(resize.reason);
```

| 支持状态 | 含义 |
| --- | --- |
| `supported` | 声明完全支持 |
| `partiallySupported` | 可用，但有平台、功能或验证范围限制；查看 `reason` |
| `unsupported` | 不可用或未知选项 |

当前多数可执行选项保守标记为 `partiallySupported`。`supportsOption` 仅对 `supported` 返回 `true`，不能用它直接判断部分支持的选项是否可执行。

外部命令功能不可用，包括 `--transform-colormap`；设置 `allowExternalCommands: true` 会抛出 `GifsicleUnsupportedFeatureException`。

## 线程与生命周期

转换请求在后台 Worker 中排队执行，跨 isolate 的原生调用也会串行处理。无需自行创建 isolate；同时提交多个 Future 不会让原生转换并行。

忽略 Future 不会取消已提交的任务。测试结束时可调用 `await Gifsicle.disposeForTesting()`，等待队列排空并关闭 Worker；下一次请求会自动重建。普通业务调用无需手动关闭 Worker。

## 示例应用

[示例应用](example/README.md) 提供 25 个可运行场景、CLI 参数实验室、能力搜索和 GIF 对比预览，手机和桌面使用同一套响应式界面。

```sh
cd example
flutter pub get
flutter run -d macos
```

其他平台使用 `flutter devices` 查看设备 ID，再执行 `flutter run -d <设备ID>`。Windows 示例需要在 Windows 上运行，iOS 真机需要配置签名。

## 参与开发

```sh
flutter pub get
dart analyze
dart test
```

原生源码来源与摘要见 [UPSTREAM_VERSION](src/third_party/gifsicle/UPSTREAM_VERSION)，补丁位于 [tool/patches](tool/patches)。性能数据见 [基准记录](BENCHMARK_BASELINE.md)，更详细的平台验证信息见 [开发状态](IMPLEMENTATION_STATUS.md)。

## 许可证

本插件的分发许可证尚未确定。内置 Gifsicle 的许可证声明见 [COPYING](src/third_party/gifsicle/COPYING)。
