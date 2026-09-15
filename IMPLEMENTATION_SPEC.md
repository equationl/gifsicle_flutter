# gifsicle_flutter 跨平台插件实施 Spec

> 状态：Draft  
> 创建日期：2026-09-14  
> 目标插件：gifsicle_flutter  
> 项目定位：独立通用 Flutter 插件，不依赖任何消费项目  
> 上游基线：Gifsicle 1.96  
> 目标平台：Android、iOS、macOS、Windows  
> 构建方案：Flutter package_ffi + Dart Build Hooks + 原生 C ABI

## 1. 背景

gifsicle_flutter 是一个全新、独立、面向通用 Flutter 生态的插件项目，不从属于任何现有应用，也不依赖任何业务项目的源码、构建脚本、Channel 或目录结构。

插件要解决的通用问题是：Gifsicle 官方定位仍然是命令行程序，没有稳定的嵌入式 Library API；Flutter 项目如果自行捆绑平台可执行文件，通常还会遇到子进程限制、二进制分发、Unicode 路径、错误捕获、移动端沙盒和 Android 16 KB 对齐等问题。

本插件需要将 Gifsicle 改造成可重复调用的原生 C API，通过 Dart FFI 向 Android、iOS、macOS、Windows 提供统一入口。同时，插件不仅提供常见的优化、压缩、缩放和裁剪快捷接口，还必须覆盖 Gifsicle 1.96 命令行程序的全部命令和参数。某项能力能否在某个平台实际运行，由该平台实现及运行环境决定，插件必须通过能力查询和明确错误如实报告，不能静默忽略。

前期验证已经确认：

- Gifsicle 1.96 可以使用 Android NDK 28.2 编译。
- Android arm64-v8a 产物可以达到 16 KB ELF LOAD 段对齐。
- Gifsicle 1.96 可以在 Apple Silicon macOS 上直接编译并运行。
- Gifsicle 官方源码包含 Windows Visual C++ 构建支持。
- 社区已有项目将 Gifsicle 改造成进程内调用，证明嵌入式改造路线可行，但现有实现不能直接作为通用 Flutter 插件使用。

本插件不得引用任何现有业务项目作为构建输入。任何应用接入示例都只能作为普通消费方示例存在。

## 2. 目标

### 2.1 核心目标

1. 提供一个可被其他 Flutter 项目直接通过 pubspec.yaml 引用的插件。
2. 同时支持 Android、iOS、macOS、Windows。
3. 使用同一套 Gifsicle C 核心和同一套 Dart 公共 API。
4. 消费项目不需要手工修改 Gradle、CMake、CocoaPods、Xcode 或 Visual Studio 配置。
5. Android 产物满足 16 KB 页面设备要求。
6. 原生调用在应用进程内完成，不创建 Gifsicle 子进程。
7. 支持 stdin、stdout、内存输入输出、文件输入输出、多输入和多输出。
8. 提供类型安全的快捷 API，以及覆盖 Gifsicle 1.96 完整 CLI 的 Token 化命令 API。
9. 支持路径中包含中文、空格、emoji 和其他 Unicode 字符。
10. 不阻塞 Flutter UI isolate。
11. 原生错误、警告和统计信息能够完整返回 Dart。
12. 固定上游版本、补丁和构建参数，保证构建可复现。
13. 提供运行时平台能力查询，明确报告支持、部分支持和不支持的命令。
14. 保持插件自身的版本、API、测试和发布流程与任何消费项目解耦。

### 2.2 首版功能范围

首个稳定版本必须在公共 API 层表达 Gifsicle 1.96 的全部命令行能力，包括但不限于：

- 合并、batch、explode、multifile、info 等运行模式。
- 多文件输入、stdin、stdout、显式 output 和原地覆盖。
- 帧选择、帧范围、nextfile 和逐输入参数。
- optimize、lossy、colors、colormap、dither、gamma。
- resize、resize-fit、scale、crop、rotate、flip、position。
- delay、disposal、loop、background、transparency、logical screen。
- interlace、careful、conserve-memory。
- comment、name、extension 和其他元数据操作。
- 警告控制、错误策略、版本和帮助信息。
- Gifsicle 1.96 手册与 help 中列出的其他参数。

功能完整性的唯一来源是真实的 Gifsicle 1.96 help/man 参数清单。仓库必须保存机器可读的命令清单，并通过自动测试保证没有遗漏。

首版同时提供常用操作的类型安全快捷接口：

- 无损优化和 lossy 压缩。
- colors、gamma 和 dithering。
- resize、fit、scale 和 crop。
- interlace、careful 和注释清理。
- 单输入单输出的内存与文件调用。

快捷接口是完整命令 API 的上层封装，不得形成另一套独立原生实现。

### 2.3 非目标

首版不包含：

- Web 平台。
- Linux 平台。
- gifview。
- gifdiff。
- 在运行时下载原生二进制。
- 执行外部 gifsicle 命令。
- 将单个未经解析的 Shell 字符串作为公共 API。
- 原生层直接访问系统相册或文件选择器。
- 后台系统任务、前台服务或跨应用处理。
- 同时并行执行多个 Gifsicle 原生任务。
- 保证所有依赖外部进程、Shell 或平台特性的选项在四个平台行为完全相同。

Linux 后续可以基于同一套 Build Hook 和 C ABI 增加，不应要求修改 Dart 公共 API。

## 3. 平台与工具链基线

### 3.1 Flutter 与 Dart

- Flutter：3.38.0 或更高。
- Dart：3.10.0 或更高。
- 插件模板：package_ffi。
- 原生构建：Dart Build Hooks。
- 原生编译辅助包：native_toolchain_c。
- FFI 绑定生成：ffigen。

本项目是全新插件，不为 Flutter 3.32 或更早版本提供兼容构建。

### 3.2 平台最低版本

| 平台 | 首版最低版本 | 首版架构 |
| --- | --- | --- |
| Android | API 24 | arm64-v8a、x86_64 |
| iOS | iOS 13.0 | arm64 device、arm64 simulator、x86_64 simulator |
| macOS | macOS 11.0 | arm64、x86_64 |
| Windows | Windows 10 | x64 |

补充说明：

- Android armeabi-v7a 不是 1.0 必选项；若业务确认仍需支持，在 1.x 中追加。
- Windows ARM64 不作为 1.0 阻断项，但 C ABI 和 Dart API 不得阻碍后续增加。
- macOS 发布产物必须同时覆盖 Apple Silicon 和 Intel，或由 Build Hook 按消费项目目标架构分别构建。

### 3.3 Android 16 KB 基线

- Android NDK：r28 或更高。
- Android Gradle Plugin：8.5.1 或更高。
- 所有 Android 目标显式添加以下链接参数：

~~~text
-Wl,-z,max-page-size=16384
-Wl,-z,common-page-size=16384
~~~

- 原生核心保持纯 C，不依赖 libc++_shared.so。
- CI 必须检查最终 ELF LOAD 段对齐和示例 APK/AAB 的 ZIP 对齐。

## 4. 总体技术决策

### 4.1 使用 package_ffi 和 Build Hooks

插件采用 Flutter 3.38 后稳定支持的 package_ffi 结构，通过 hook/build.dart 调用 native_toolchain_c，根据目标平台和架构编译 Gifsicle 原生代码。

消费项目的目标体验：

~~~yaml
dependencies:
  gifsicle_flutter: ^1.0.0
~~~

然后直接：

~~~dart
import 'package:gifsicle_flutter/gifsicle_flutter.dart';
~~~

不允许要求消费项目额外配置：

- Android jniLibs。
- Android useLegacyPackaging。
- Android externalNativeBuild。
- iOS Pod 依赖。
- macOS Pod 依赖。
- Windows CMake 子目录。
- 手工复制 DLL、dylib、so 或 Framework。

### 4.2 使用进程内 C API

四个平台统一编译原生库：

| 平台 | 典型产物 |
| --- | --- |
| Android | libgifsicle_flutter.so |
| iOS | 静态链接 Code Asset |
| macOS | libgifsicle_flutter.dylib 或静态链接产物 |
| Windows | gifsicle_flutter.dll |

不把可执行程序伪装成共享库，不使用 Runtime.exec、Process.start 或 posix_spawn 调用 Gifsicle。

### 4.3 内存 API 与隔离工作目录

常用单输入单输出接口以 GIF 字节作为原生边界。完整命令接口使用插件创建的隔离工作目录，将 Dart 文件或内存输入映射为安全的临时文件名，再把 Token 化 argv 交给嵌入式 Gifsicle 主循环。

这样可以统一解决：

- Windows fopen 对中文路径支持不完整。
- Android 和 Apple 平台沙盒路径差异。
- 路径空格、引号和命令注入。
- 同输入输出路径覆盖。
- stdin/stdout 捕获。
- batch、explode、多输入和多输出文件收集。

文件 API 在 Dart 层完成文件读取、工作目录暂存、输出收集和结果替换。高级 direct 模式可以传递调用方文件路径和 workingDirectory，但必须显式选择，且不获得 Unicode 路径兼容保证。

### 4.4 首版串行执行

Gifsicle 命令行实现包含静态全局状态，不具备已验证的可重入能力。首版必须在原生 Bridge 内使用进程级互斥锁串行执行。

即使多个 Dart isolate 同时发起调用，原生层也必须保证：

- 不发生全局状态串扰。
- 不发生输出缓冲区串扰。
- 不发生错误消息串扰。
- 不发生内存重复释放。

后续只有在完成上下文化重构和 ThreadSanitizer 验证后，才允许开放真正并行执行。

### 4.5 固定并内置上游源码

- 首版固定 Gifsicle 1.96。
- 上游源码随插件一起发布，消费项目构建时禁止联网下载源码。
- 记录上游 tarball URL、SHA-256 和 Git commit。
- 所有本地改动保存为可审计补丁。
- 保留上游版本、来源、checksum 和修改记录，便于后续升级与审计。

### 4.6 双层公共 API

插件同时提供：

1. 类型安全快捷 API，用于常见压缩、优化、缩放、裁剪场景。
2. 完整命令 API，用 Token 列表表达 Gifsicle argv，覆盖全部 CLI 选项。

完整命令 API 不能接收需要 Shell 再次拆分的单字符串。每个参数、文件引用和帧选择器都是独立 Token，插件不得调用 Shell。

### 4.7 平台能力声明

Gifsicle 的纯算法和内存处理能力原则上由四个平台共享，但部分选项可能依赖：

- 外部命令或 Shell。
- 平台文件系统语义。
- 临时文件。
- pthread 或平台线程能力。
- 终端 stdin/stdout 行为。

插件必须提供 Gifsicle.capabilities 查询，并为每个平台维护经过测试的能力表。无法执行的选项必须在运行前或原生返回后抛出 GifsicleUnsupportedFeatureException，不得假装成功或静默忽略。

## 5. 建议目录结构

~~~text
gifsicle_flutter/
├── analysis_options.yaml
├── CHANGELOG.md
├── IMPLEMENTATION_SPEC.md
├── README.md
├── ffigen.yaml
├── pubspec.yaml
├── hook/
│   └── build.dart
├── lib/
│   ├── gifsicle_flutter.dart
│   └── src/
│       ├── bindings/
│       │   └── gifsicle_bindings_generated.dart
│       ├── models/
│       │   ├── gifsicle_argument.dart
│       │   ├── gifsicle_capabilities.dart
│       │   ├── gifsicle_command.dart
│       │   ├── gifsicle_crop.dart
│       │   ├── gifsicle_exception.dart
│       │   ├── gifsicle_execution_result.dart
│       │   ├── gifsicle_input.dart
│       │   ├── gifsicle_options.dart
│       │   ├── gifsicle_output.dart
│       │   ├── gifsicle_result.dart
│       │   └── gifsicle_resize.dart
│       ├── native/
│       │   ├── native_executor.dart
│       │   ├── native_memory.dart
│       │   └── staging_workspace.dart
│       └── gifsicle.dart
├── src/
│   ├── bridge/
│   │   ├── gifsicle_bridge.c
│   │   ├── gifsicle_bridge.h
│   │   ├── gifsicle_context.c
│   │   ├── gifsicle_context.h
│   │   ├── gifsicle_export.h
│   │   └── gifsicle_platform_config.h
│   └── third_party/
│       └── gifsicle/
│           ├── COPYING
│           ├── UPSTREAM_VERSION
│           ├── include/
│           └── src/
├── test/
│   ├── api_validation_test.dart
│   ├── file_api_test.dart
│   ├── options_mapping_test.dart
│   └── fixtures/
├── native_test/
│   ├── bridge_test.c
│   ├── fuzz_gif_input.c
│   └── fixtures/
├── example/
│   ├── lib/
│   ├── integration_test/
│   └── pubspec.yaml
├── tool/
│   ├── check_android_alignment.sh
│   ├── generate_cli_manifest.dart
│   ├── check_exported_symbols.dart
│   ├── update_upstream.dart
│   ├── verify_upstream_checksum.dart
│   ├── cli/
│   │   └── gifsicle_1_96_options.json
│   └── patches/
└── .github/
    └── workflows/
        ├── ci.yaml
        └── publish.yaml
~~~

## 6. Dart 公共 API

### 6.1 入口类

~~~dart
abstract final class Gifsicle {
  static String get bridgeVersion;

  static String get gifsicleVersion;

  static Future<GifsicleCapabilities> capabilities();

  static Future<GifsicleExecutionResult> execute(
    GifsicleCommand command,
  );

  static Future<GifsicleExecutionResult> executeArguments(
    List<String> arguments, {
    Uint8List? stdin,
    String? workingDirectory,
    bool allowExternalCommands = false,
  });

  static Future<GifsicleBytesResult> transformBytes(
    Uint8List input, {
    GifsicleOptions options = const GifsicleOptions(),
  });

  static Future<GifsicleFileResult> transformFile({
    required String inputPath,
    required String outputPath,
    GifsicleOptions options = const GifsicleOptions(),
    bool overwrite = false,
  });
}
~~~

不得暴露要求调用方管理 Pointer、malloc 或 free 的公共 API。

### 6.2 完整命令 API

GifsicleCommand 用独立 Token 表示 argv，不经过 Shell：

~~~dart
final result = await Gifsicle.execute(
  GifsicleCommand(
    arguments: [
      const GifsicleArgument.option('--optimize=3'),
      const GifsicleArgument.option('--colors=128'),
      GifsicleArgument.inputFile(
        id: 'source',
        path: inputPath,
      ),
      const GifsicleArgument.option('--output'),
      GifsicleArgument.outputFile(
        id: 'result',
        path: outputPath,
        overwrite: true,
      ),
    ],
  ),
);
~~~

命令对象：

~~~dart
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
  final bool collectGeneratedFiles;
  final bool allowExternalCommands;
  final GifsicleLimits limits;
}
~~~

allowExternalCommands 默认必须为 false。即使 macOS 或 Windows capability 显示支持外部命令型选项，调用方仍需显式启用。

Token 类型至少包括：

~~~dart
sealed class GifsicleArgument {
  const GifsicleArgument();

  const factory GifsicleArgument.option(String value)
      = GifsicleOptionArgument;

  const factory GifsicleArgument.literal(String value)
      = GifsicleLiteralArgument;

  const factory GifsicleArgument.frameSelector(String value)
      = GifsicleFrameSelectorArgument;

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
}
~~~

Gifsicle.execute 负责：

1. 将 inputFile 和 inputBytes 暂存到独立工作目录并使用 ASCII 安全文件名。
2. 将 outputFile 和 outputMemory 映射为工作目录目标。
3. 保持 option、literal 和 frameSelector 的原始顺序。
4. 调用嵌入式 Gifsicle argv 入口。
5. 捕获 stdout、stderr、退出码和工作目录生成文件。
6. 将声明输出复制到目标路径或返回内存。
7. 收集 batch、explode 等模式动态生成的文件。
8. 清理插件创建的工作目录。

executeArguments 是高级 CLI 兼容接口：

~~~dart
final result = await Gifsicle.executeArguments(
  [
    '--info',
    '--color-info',
    'animation.gif',
  ],
  workingDirectory: sourceDirectory,
);
~~~

它接受已经拆分好的 argv，不执行 Shell 解析，也不接受单字符串命令。调用方直接提供的路径由调用方负责平台兼容性；需要 Unicode 路径和安全暂存保证时必须使用 GifsicleCommand。

### 6.3 平台能力

~~~dart
final capabilities = await Gifsicle.capabilities();

if (!capabilities.supportsOption('--transform-colormap')) {
  // 根据产品逻辑隐藏功能或改用其他实现。
}
~~~

能力对象至少包含：

~~~dart
final class GifsicleCapabilities {
  final String platform;
  final String gifsicleVersion;
  final int bridgeAbiVersion;
  final Map<String, GifsicleOptionCapability> options;
  final Set<GifsicleFeature> features;

  bool supportsOption(String name);
  GifsicleOptionCapability option(String name);
}

enum GifsicleSupportLevel {
  supported,
  partiallySupported,
  unsupported,
}

final class GifsicleOptionCapability {
  final GifsicleSupportLevel level;
  final String? reason;
}
~~~

能力状态以实际平台构建和运行测试为准：

- supported：完整支持并通过测试。
- partiallySupported：可以执行但存在已记录的平台差异。
- unsupported：当前平台实现不支持，调用时抛出 GifsicleUnsupportedFeatureException。

平台实现不得为了保持表面 API 一致而吞掉不支持的参数。

### 6.4 Options 快捷接口

~~~dart
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
  final int? lossy;
  final int? colors;
  final GifsicleGamma gamma;
  final GifsicleDither? dither;
  final GifsicleResize? resize;
  final GifsicleScale? scale;
  final GifsicleCrop? crop;
  final bool? interlace;
  final bool careful;
  final bool removeComments;
}
~~~

参数约束：

| 参数 | 约束 | 默认值 |
| --- | --- | --- |
| optimizationLevel | 0 至 3 | 3 |
| lossy | null 或 0 至 200 | null，即无损 |
| colors | null 或 2 至 256 | null |
| gamma | srgb、linear 或明确数值 | srgb |
| dither | null 或 Gifsicle 支持的 dither 配置 | null |
| scale | X/Y 必须大于 0 | null |
| resize | 宽高必须为正整数 | null |
| crop | 宽高为正，X/Y 不得为负 | null |
| interlace | null 表示保持当前策略 | null |
| careful | bool | false |
| removeComments | bool | false |

约束补充：

- resize 与 scale 不能同时设置。
- crop 发生在 resize 或 scale 之前。
- 默认操作必须是无损的，不得默认启用 lossy。
- 参数错误必须在进入原生层前抛出 ArgumentError。
- 快捷接口必须转换为 GifsicleCommand 或等价 argv，不得维护另一套算法实现。

### 6.5 Resize 与 Crop

~~~dart
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
}

final class GifsicleCrop {
  const GifsicleCrop({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}
~~~

### 6.6 执行与快捷接口结果

完整命令结果：

~~~dart
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

sealed class GifsicleOutputArtifact {
  const GifsicleOutputArtifact(this.id);

  final String id;
}

final class GifsicleMemoryOutputArtifact extends GifsicleOutputArtifact {
  final Uint8List bytes;
}

final class GifsicleFileOutputArtifact extends GifsicleOutputArtifact {
  final String path;
  final int size;
}

final class GifsicleGeneratedFile {
  final String relativePath;
  final Uint8List bytes;
}
~~~

stdout 必须是字节而不是 String，因为默认 Gifsicle 输出可能是 GIF 二进制；只有 info、help 等文本场景才由调用方显式按 UTF-8 解码。

generatedFiles 只包含隔离工作目录中新生成且未对应显式 Output Token 的普通文件。不得返回符号链接、目录或工作目录之外的文件。

快捷接口结果：

~~~dart
final class GifsicleBytesResult {
  const GifsicleBytesResult({
    required this.bytes,
    required this.inputSize,
    required this.outputSize,
    required this.elapsed,
    required this.warnings,
  });

  final Uint8List bytes;
  final int inputSize;
  final int outputSize;
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
  final int inputSize;
  final int outputSize;
  final Duration elapsed;
  final List<String> warnings;
}
~~~

### 6.7 错误模型

失败通过 GifsicleException 抛出，不返回模糊的 false。

~~~dart
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

final class GifsicleException implements Exception {
  const GifsicleException({
    required this.code,
    required this.message,
    this.nativeCode,
    this.warnings = const [],
  });
}
~~~

异常信息不得包含完整 GIF 内容，不得无条件输出用户文件路径到日志。

对于 Gifsicle 自身正常返回的非零退出码，execute 默认返回 GifsicleExecutionResult，由调用方检查 exitCode；只有 Bridge、平台能力、内存、工作目录或 ABI 层失败才抛出异常。快捷接口将非零退出码转换成 GifsicleException。

## 7. 原生 C ABI

### 7.1 导出规则

~~~c
#if defined(_WIN32)
#define GIFSICLE_FLUTTER_EXPORT __declspec(dllexport)
#else
#define GIFSICLE_FLUTTER_EXPORT \
  __attribute__((visibility("default"))) __attribute__((used))
#endif
~~~

所有导出函数必须：

- 使用 C ABI。
- 不抛出 C++ 异常。
- 不返回栈内存。
- 不依赖线程局部 last-error。
- 不让调用方跨 CRT 释放内存。

### 7.2 ABI 数据结构

~~~c
#include <stddef.h>
#include <stdint.h>

#define GS_BRIDGE_ABI_VERSION 1

typedef struct gs_options {
  uint32_t abi_version;
  uint32_t struct_size;
  int32_t optimization_level;
  int32_t lossy;
  int32_t colors;
  int32_t gamma_mode;
  double gamma_value;
  int32_t resize_mode;
  int32_t resize_width;
  int32_t resize_height;
  double scale_x;
  double scale_y;
  int32_t crop_enabled;
  int32_t crop_x;
  int32_t crop_y;
  int32_t crop_width;
  int32_t crop_height;
  int32_t interlace_mode;
  int32_t careful;
  int32_t remove_comments;
} gs_options;

typedef struct gs_result {
  int32_t status;
  uint8_t* output_data;
  size_t output_length;
  char* error_message;
  size_t error_message_length;
  char* warnings;
  size_t warnings_length;
} gs_result;

typedef struct gs_execution_result {
  int32_t bridge_status;
  int32_t exit_code;
  uint8_t* stdout_data;
  size_t stdout_length;
  char* stderr_data;
  size_t stderr_length;
} gs_execution_result;
~~~

约定：

- lossy=-1 表示关闭。
- colors=-1 表示不修改。
- resize_mode=0 表示不缩放。
- interlace_mode=-1 表示保持默认策略。
- 字符串统一使用 UTF-8。
- warnings 使用换行分隔；Dart 层转换为不可变字符串列表。
- struct_size 用于未来向后兼容地追加字段。
- 完整命令生成的文件由 Dart 隔离工作目录收集，不在 C ABI 中返回可变长度结构数组。

### 7.3 ABI 函数

~~~c
GIFSICLE_FLUTTER_EXPORT
uint32_t gs_bridge_abi_version(void);

GIFSICLE_FLUTTER_EXPORT
const char* gs_gifsicle_version(void);

GIFSICLE_FLUTTER_EXPORT
const char* gs_capabilities_json(void);

GIFSICLE_FLUTTER_EXPORT
gs_execution_result* gs_execute(
    int32_t argc,
    const char* const* argv,
    const uint8_t* stdin_data,
    size_t stdin_length,
    const char* working_directory);

GIFSICLE_FLUTTER_EXPORT
gs_result* gs_transform(
    const uint8_t* input_data,
    size_t input_length,
    const gs_options* options);

GIFSICLE_FLUTTER_EXPORT
void gs_result_free(gs_result* result);

GIFSICLE_FLUTTER_EXPORT
void gs_execution_result_free(gs_execution_result* result);
~~~

gs_execute 约定：

- Dart 传入的 arguments 不包含 argv[0]，Bridge 自动补充固定程序名。
- 每个 argv Token 是独立 UTF-8 字符串，不执行 Shell 展开。
- stdin_data 可以为空；非空时映射为 Gifsicle stdin。
- stdout 始终按字节捕获，允许承载 GIF。
- stderr 按 UTF-8 捕获，不能写入宿主进程全局 stderr。
- working_directory 必须是插件创建或调用方显式传入的现有目录。
- working_directory 只能由 gs_context 的文件抽象解析，禁止调用 chdir 或 SetCurrentDirectory 修改宿主进程全局工作目录。
- Gifsicle 自身错误通过 exit_code 表达；Bridge 错误通过 bridge_status 表达。

gs_transform 是常用单输入单输出快捷入口，也可以在内部转换成 gs_execute 请求。两种入口必须共享相同的解析、转换和错误处理核心。

生命周期：

1. Dart 分配并填充输入和 Options。
2. 调用 gs_transform 或 gs_execute。
3. 原生层复制或消费输入时不得越界。
4. 成功或失败都返回对应 result。
5. Dart 将输出和消息复制到 Dart 管理内存。
6. Dart 在 finally 中调用且只调用一次对应 free 函数。

gs_transform 返回空指针只允许代表无法创建最小错误结果的灾难性内存不足；Dart 将其转换为 outOfMemory。

gs_capabilities_json 返回由当前原生构建生成的静态 UTF-8 JSON，不需要释放。内容必须包含平台、上游版本、Bridge ABI、完整支持项、部分支持项和不支持项。Dart 层 capabilities 将该信息与无副作用的运行环境检查合并；例如桌面平台编译时支持外部命令，不代表运行环境一定允许执行指定命令。

## 8. Gifsicle 上游改造

### 8.1 源码范围

首版编译下列模块，具体列表以 Gifsicle 1.96 为准：

- clp.c
- fmalloc.c
- giffunc.c
- gifread.c
- gifunopt.c
- gifwrite.c
- kcolor.c
- merge.c
- optimize.c
- quantize.c
- support.c
- xform.c
- 经嵌入式改造后的 gifsicle 主循环
- gifsicle_bridge.c
- gifsicle_context.c

不得编译：

- gifview。
- gifdiff。
- X11 相关源码。
- 命令行 executable main。

### 8.2 Config 策略

消费项目构建时不得执行 autoreconf 或 configure。

项目内提供 gifsicle_platform_config.h，根据目标平台、编译器和架构设置必要宏：

- Android/Linux 风格 ABI。
- Apple Darwin ABI。
- Windows LLP64 ABI。
- 32 位和 64 位指针宽度。
- 可用标准头文件和函数。
- 是否启用 pthread。

必须保留编译期 static_assert，至少校验：

- sizeof(unsigned int)。
- sizeof(unsigned long)。
- sizeof(void*)。
- uint32_t 和 uint64_t 宽度。

首版关闭 Gifsicle 内部多线程，以减少平台差异并保证确定性。插件外层仍在后台 isolate 执行。

### 8.3 移除进程终止行为

必须审计所有：

- exit。
- abort。
- assert。
- fatal_error。
- 内存分配失败分支。

原生库不得因为单个损坏 GIF 或参数错误终止宿主 Flutter 进程。

改造要求：

1. 将命令行 main 改成接收 gs_context 的可返回函数。
2. fatal_error 记录错误并返回到统一清理出口。
3. 内存分配失败转换为 GS_OUT_OF_MEMORY。
4. 所有资源通过单一 cleanup 路径释放。
5. 仅允许用于开发期不变量的 assert；所有用户输入相关判断必须返回错误。

不建议在正式版本依赖 longjmp。若原型阶段暂时使用，必须在 1.0 前替换，并用 LeakSanitizer 证明所有跳转路径都能释放资源。

### 8.4 全局状态处理

首版方案：

- 每次调用前显式 reset 所有 Gifsicle 静态状态。
- 调用期间持有全局 mutex。
- 调用结束后释放所有输入、帧、调色板、输出和 parser 状态。
- 禁止缓存上一任务的 Gif_Stream。

必须编写连续调用测试，确认不同 Options 和不同 GIF 之间不存在状态泄漏。

长期方案：

- 将可变静态变量迁移进 gs_context。
- 当所有状态都上下文化且通过 ThreadSanitizer 后，提升 ABI 次版本并允许并行。

### 8.5 内存读写

输入：

- 使用 Gif_FullReadRecord 或等价的内存 reader。
- 明确输入长度，不使用零结尾假设。
- 拒绝长度溢出和尺寸乘法溢出。

输出：

- 增加可增长内存 writer。
- 所有容量增长执行溢出检查。
- 写入失败返回明确错误。
- 输出所有权交给 gs_result，并由 gs_result_free 统一释放。
- info/help 等文本输出和默认 GIF stdout 都通过 gs_context writer 捕获。
- warning 和 error 通过 gs_context error writer 捕获。
- 禁止使用 freopen、dup2 或修改进程级 stdout/stderr 完成捕获，避免影响宿主及其他插件。

### 8.6 完整 CLI 保真

嵌入式入口必须保留 Gifsicle 1.96 原始参数解析器和处理主循环，不能只把当前快捷 Options 映射到少量内部函数。

完整性实施要求：

1. 从固定版本的 gifsicle.1、--help 和源码 options 表生成 gifsicle_1_96_options.json。
2. Manifest 记录 canonical name、短别名、参数类型、参数是否可重复、分类和平台限制。
3. 每个 Manifest 项必须至少有一个 parser conformance test。
4. 涉及实际图像行为的选项必须有功能 Fixture。
5. 快捷 API 生成的 argv 也必须经过同一个参数解析器。
6. 上游升级时自动比较 Manifest，新增、删除或变更参数必须触发人工审阅。

需要覆盖的 CLI 语义包括：

- 参数顺序影响后续输入文件的行为。
- 单个输入文件后的帧选择器。
- 短参数组合。
- 正向和反向选项。
- 选项的长名称缩写规则。
- stdin 标记 -。
- stdout 默认输出。
- 多输入合并。
- batch 和 explode 生成动态文件名。
- info 等文本输出。
- 错误、警告和非零退出码。

插件公共 API 中所说的“支持全部 Gifsicle 命令”指 Gifsicle 主程序 1.96 的全部命令和选项，不包含同一源码包中的独立程序 gifview 与 gifdiff。

### 8.7 平台相关选项

所有纯 GIF 算法和普通文件操作应优先在四个平台实现。依赖平台环境的选项按能力声明处理。

重点审计：

- transform-colormap 等需要执行外部命令的能力。
- 依赖 Shell、管道或 popen 的路径。
- 依赖终端检测的行为。
- 临时文件创建和重命名语义。
- Windows 不同 CRT 和文件路径编码。
- iOS 沙盒和禁止动态下载、执行代码的限制。

建议的首版能力基线：

| 能力 | Android | iOS | macOS | Windows |
| --- | --- | --- | --- | --- |
| 纯 GIF 读取、写入、转换 | 支持 | 支持 | 支持 | 支持 |
| stdin/stdout 内存映射 | 支持 | 支持 | 支持 | 支持 |
| 多输入、batch、explode | 支持 | 支持 | 支持 | 支持 |
| info/help/version 文本输出 | 支持 | 支持 | 支持 | 支持 |
| use-colormap 文件输入 | 支持 | 支持 | 支持 | 支持 |
| 外部命令型 colormap transform | 默认不支持 | 不支持 | 条件支持 | 条件支持 |

此表是实施目标，不是未经验证的承诺。最终能力表必须由各平台集成测试生成；某平台未通过的能力应降级为 partiallySupported 或 unsupported。

## 9. Build Hook 设计

### 9.1 基础结构

hook/build.dart 使用 CBuilder.library：

~~~dart
void main(List<String> args) async {
  await build(args, (input, output) async {
    final target = input.config.code.targetOS;

    final builder = CBuilder.library(
      name: 'gifsicle_flutter',
      assetName: 'src/bindings/gifsicle_bindings_generated.dart',
      sources: gifsicleSources,
      includes: const [
        'src/bridge',
        'src/third_party/gifsicle/include',
        'src/third_party/gifsicle/src',
      ],
      defines: platformDefines(target),
      flags: platformFlags(target),
      language: Language.c,
      std: 'c11',
    );

    await builder.run(
      input: input,
      output: output,
      logger: createBuildLogger(),
    );
  });
}
~~~

以上是结构示意。实现时以当前 native_toolchain_c 实际 API 为准，并锁定经过 CI 验证的版本范围。

### 9.2 通用编译要求

- C 标准：C11。
- Release 优化：O3。
- Debug：保留符号并降低优化，便于 Sanitizer。
- 默认隐藏符号，仅导出 gs_ 前缀 API。
- 开启常用警告。
- 项目自有 Bridge 代码将警告视为错误。
- 上游源码可以对已知警告做精确抑制，禁止全局关闭警告。
- 不链接 C++ 标准库。
- 构建过程不得访问网络。

### 9.3 Android

- 使用 Flutter/Android 工具链提供的 Clang 和 NDK。
- 添加 16 KB 链接参数。
- 不生成或打包命令行 executable。
- 不依赖 libc++_shared.so。
- 最终 .so 只能依赖 Android 系统库。
- 示例应用不得设置 useLegacyPackaging。

必须验证：

~~~text
llvm-readelf -lW libgifsicle_flutter.so
zipalign -c -P 16 -v 4 example-release.apk
bundletool dump config --bundle=example-release.aab
~~~

所有 LOAD p_align 必须不小于 0x4000。

### 9.4 iOS

- 使用 Xcode Clang。
- 支持 arm64 真机。
- 支持 arm64 和 x86_64 Simulator。
- 代码由应用构建流程编译并签名。
- 不创建子进程。
- 不下载可执行代码。
- 不依赖私有 API。
- 导出符号可通过 DynamicLibrary.process 或 Code Asset 自动绑定找到。

### 9.5 macOS

- 使用 Xcode Clang。
- 支持 arm64 和 x86_64。
- 动态库 install name 和实际打包名称必须一致。
- 产物随宿主应用签名和公证。
- 不依赖用户预装 Homebrew gifsicle。
- 不读取系统 PATH 查找外部命令。

### 9.6 Windows

- 使用 MSVC 工具链。
- 首版支持 x64。
- 使用 __declspec(dllexport) 导出公共 ABI。
- 使用与 Flutter Windows Runner 兼容的动态 CRT。
- Bridge 代码启用 UTF-8 源码编译。
- 原生边界仅接收字节，不依赖窄字符文件路径。
- 不要求用户安装 gifsicle.exe、MSYS2 或 MinGW。
- DLL 名称、FFI Asset 名称和 ffigen 绑定保持一致。

## 10. FFI 绑定与 Isolate

### 10.1 绑定生成

- ffigen 仅扫描 src/bridge/gifsicle_bridge.h。
- 不把完整 Gifsicle 内部头文件暴露给 Dart。
- 生成文件位于 lib/src/bindings。
- 生成文件禁止手工编辑。
- CI 执行 ffigen 后必须确认 Git diff 为空。

### 10.2 后台执行

Gifsicle 是长耗时 CPU 任务，不允许在 UI isolate 直接调用。

实现一个长期存活的 Worker isolate：

1. 主 isolate 首次调用时惰性启动 Worker。
2. 请求使用递增 requestId。
3. Command、argv 和平台能力检查结果必须可序列化。
4. 输入字节使用 TransferableTypedData 传递。
5. Worker 完成工作目录准备、FFI 调用、输出收集和原生内存复制。
6. stdout、内存输出和动态生成文件使用 TransferableTypedData 返回主 isolate。
7. Worker 异常必须完成对应 Future，不得遗留永不完成的请求。
8. 提供 disposeForTesting，仅供测试释放 Worker。

首版可以在 Dart 层排队，但原生 mutex 仍然必须存在，防止不同 isolate 或其他直接 FFI 调用绕过队列。

### 10.3 取消

首版 1.0 不承诺立即取消正在执行的原生压缩。Future 被调用方忽略时，任务仍安全执行并释放资源。

后续版本的协作取消设计：

- 每个任务获得原子 cancel flag。
- 在解析、量化、缩放、优化等阶段检查。
- 返回 cancelled 错误码。
- 禁止通过终止 isolate 强行中断正在使用的原生指针。

README 必须明确首版取消语义。

## 11. 命令与文件 I/O 行为

transformFile 的标准流程：

1. 校验输入文件存在且可读。
2. 读取输入字节。
3. 在 Worker isolate 调用 transformBytes。
4. 在目标目录创建唯一临时文件。
5. 完整写入输出字节并关闭文件。
6. 最低限度验证输出以 GIF87a 或 GIF89a 开头。
7. 根据 overwrite 策略替换目标文件。
8. 失败时删除插件创建的临时文件。
9. 返回最终绝对路径和统计信息。

完整 GifsicleCommand 的标准流程：

1. 创建仅属于当前 requestId 的随机工作目录。
2. 把每个输入映射为不含用户路径信息的 ASCII 文件名。
3. 建立输入文件清单及初始文件 hash。
4. 按 Argument Token 顺序生成 argv。
5. 对声明的输出使用独立 ASCII 暂存路径。
6. 将 stdin 字节和 argv 一起传入 gs_execute。
7. 捕获 stdout 和 stderr。
8. 比较运行前后的工作目录，识别 batch、explode 等动态输出。
9. 拒绝任何逃逸工作目录的相对路径或符号链接输出。
10. 将声明输出写入调用方目标，将动态输出作为 generatedFiles 返回。
11. 在所有成功和失败路径清理工作目录。

对于 GifsicleArgument.frameSelector，插件只能校验基本格式，最终语义由 Gifsicle 原始 parser 决定。

对于 executeArguments direct 模式：

- 不创建输入输出映射。
- 调用方负责 workingDirectory 和路径权限。
- 插件仍不得调用 Shell。
- 插件仍捕获 stdout、stderr 和退出码。
- 不自动收集 workingDirectory 中任意新增文件，避免误读调用方数据。
- capabilities 明确为 directFileSystemAccess 时才能启用。

覆盖规则：

- outputPath 已存在且 overwrite=false：抛出 writeFailed。
- inputPath 与 outputPath 相同：允许，始终通过临时文件替换。
- 不允许在原生处理成功前截断原文件。
- Windows 目标已存在时需使用经过测试的替换流程，不假设 rename 可以覆盖。
- 插件只删除自己创建且路径经过精确校验的临时文件。

## 12. 安全与健壮性

### 12.1 不可信输入

GIF 输入必须按不可信数据处理：

- 检查所有长度、尺寸和乘法溢出。
- 对损坏、截断、递归或异常扩展块返回错误。
- 不允许越界读取或写入。
- 不允许因为输入触发宿主进程退出。
- 不把原生错误原样作为格式化字符串。

外部命令型选项属于高风险能力：

- 默认关闭。
- iOS 标记为 unsupported。
- Android 首版标记为 unsupported。
- macOS 和 Windows 只有在 capability 支持且 allowExternalCommands=true 时执行。
- 外部命令内容不得来自不可信用户输入。
- 插件不得宣称能够对外部命令做完整沙盒隔离。
- README 必须单独标注该能力的安全风险。

### 12.2 资源限制

提供可选的 Dart 层保护参数：

~~~dart
final class GifsicleLimits {
  const GifsicleLimits({
    this.maxInputBytes,
    this.maxOutputBytes,
    this.maxFrameCount,
    this.maxCanvasPixels,
  });
}
~~~

默认值应在实现阶段通过真实样本和移动端内存测试确定。任何默认限制必须在 README 中明确，并允许调用方合理调整。

### 12.3 日志

- 默认不输出原生 stdout/stderr。
- warning 通过结果返回。
- Debug 日志不得包含 GIF 二进制内容。
- 文件路径默认只记录 basename；完整路径仅在调用方显式开启诊断日志时输出。

## 13. 测试方案

### 13.1 Dart 单元测试

必须覆盖：

- Options 默认值。
- 每个参数边界。
- 非法组合。
- 快捷 Options 到 argv 的映射。
- Argument Token 顺序保持。
- input/output 暂存映射。
- executeArguments 不进行 Shell 拆分。
- 平台 capabilities 解析。
- unsupported 选项错误。
- 原生错误码到 Dart Exception 的映射。
- Native result 在成功和失败路径都只释放一次。
- Worker 请求与响应匹配。
- Worker 异常不会挂起 Future。
- 文件覆盖策略。
- 同路径输入输出。
- 中文、空格和 emoji 路径。
- stdin/stdout 二进制。
- batch/explode 动态输出收集。
- 工作目录逃逸防护。

### 13.2 原生单元测试

必须覆盖：

- 空指针和零长度输入。
- 非 GIF 数据。
- 截断 GIF。
- 正常 GIF。
- OOM 模拟。
- 输出 buffer 扩容。
- 每个 Options 字段。
- gs_execute 的 argv、stdin、stdout 和 stderr。
- help、version 和 info 文本命令。
- 非零 CLI 退出码。
- capabilities JSON。
- result_free 接受完整结果、部分结果和空指针。
- 连续调用至少 100 次。
- 多线程同时调用时能够正确串行。

### 13.3 GIF Fixture

测试集至少包含：

- 单帧 GIF87a。
- 单帧 GIF89a。
- 多帧动画。
- 全局调色板。
- 局部调色板。
- 透明帧。
- disposal none、background、previous。
- 0 延迟和极短延迟帧。
- interlaced GIF。
- 包含 comment 和 application extension。
- 超过 256 个源颜色。
- 首帧未覆盖逻辑画布。
- 输入中包含尾随垃圾。
- 损坏 LZW 数据。
- 极端画布尺寸但文件体积很小的恶意样本。

Fixture 优先使用自行生成的小型样本，避免测试数据来源不明。

### 13.4 CLI 完整性测试

- gifsicle_1_96_options.json 中每个选项必须有 parser 测试。
- 每个纯算法选项至少在一个目标平台有功能测试。
- 平台声称 supported 的每个选项必须在该平台运行通过。
- partiallySupported 必须有记录差异的测试。
- unsupported 必须验证抛出明确异常，不能落入 unknown error。
- 覆盖短别名、长名称、长名称缩写、反向选项和重复选项。
- 覆盖参数顺序、逐文件 Options、帧范围和多个 output。
- 覆盖 batch、explode、multifile、info、stdin 和 stdout。
- 将官方 Gifsicle 1.96 CLI 作为桌面参考实现，对相同 argv 比较退出码、输出和 stderr。

### 13.5 语义验收

无损模式必须比较：

- 帧数。
- 逻辑画布尺寸。
- 每帧宽高和位置。
- 每帧 delay。
- disposal。
- loop count。
- 透明语义。
- 完整解码后的逐帧像素。

有损模式必须比较：

- 帧数和时序完全一致。
- 尺寸和动画元数据一致。
- 解码图像差异处于为 Fixture 明确设定的阈值。
- 输出可以被主流 Flutter/系统解码器正常读取。

### 13.6 确定性

同平台、同版本、同输入、同 Options 连续运行必须得到字节一致的输出。

跨平台优先要求字节一致；如果底层浮点或编译器差异导致字节不同，则至少必须满足：

- 动画元数据一致。
- 解码像素在定义阈值内一致。
- 文件大小差异在基准允许范围内。

任何跨平台差异都必须记录为测试基线，不能静默忽略。

### 13.7 Sanitizer 与 Fuzz

- macOS 或 Linux Host 原生测试启用 AddressSanitizer 和 UndefinedBehaviorSanitizer。
- 可用时启用 LeakSanitizer。
- 对 gs_transform 和 gs_execute parser 建立 libFuzzer 入口。
- 初始语料使用 test fixtures。
- CI 快速 fuzz 固定时间运行。
- 发布前执行更长时间 fuzz。
- 所有崩溃样本加入回归集。

## 14. 平台测试矩阵

| 平台 | 构建 | 自动运行 | 手工验收 |
| --- | --- | --- | --- |
| Android arm64-v8a 4 KB | 必须 | 模拟器或真机 | 必须 |
| Android arm64-v8a 16 KB | 必须 | 16 KB 模拟器 | 必须 |
| Android x86_64 | 必须 | 模拟器 | 可选 |
| iOS arm64 Simulator | 必须 | 必须 | 必须 |
| iOS x86_64 Simulator | 必须 | 条件允许时 | 可选 |
| iOS arm64 Device | 必须 | 不强制 CI | 必须 |
| macOS arm64 | 必须 | 必须 | 必须 |
| macOS x86_64 | 必须 | 条件允许时 | 发布前必须 |
| Windows x64 | 必须 | 必须 | 必须 |

Android 16 KB 验收不能只看编译参数，必须同时验证：

- 原生 ELF 对齐。
- APK ZIP 对齐。
- AAB 配置。
- 16 KB 设备实际加载。
- 至少一次真实 GIF 优化。

## 15. 性能与内存基准

建立固定 Benchmark corpus：

- 小型单帧 GIF。
- 小型动画 GIF。
- 大画布低帧数 GIF。
- 小画布高帧数 GIF。
- 高颜色复杂度 GIF。
- 透明动画 GIF。

记录：

- 输入大小。
- 输出大小。
- 总耗时。
- 纯原生耗时。
- Dart 与 Native 数据复制耗时。
- 峰值 RSS。
- 处理后 RSS 回落情况。

对照组：

- 同版本 Gifsicle 1.96 CLI。
- 快捷 API 与等价完整 Command API。
- 内存输入模式与隔离工作目录模式。

1.0 发布门槛：

- Bridge 相对同版本 CLI 不得出现明显算法级性能退化。
- 连续 100 次调用无持续线性内存增长。
- UI isolate 在压缩过程中保持可响应。
- 大输入失败时返回可识别错误，不导致宿主崩溃。

具体数值阈值在首轮 Benchmark 后写入 BENCHMARK_BASELINE.md。

## 16. CI 设计

### 16.1 基础检查

每次 Pull Request：

1. dart format --output=none --set-exit-if-changed .
2. dart analyze。
3. dart test。
4. 重新运行 ffigen 并确认无差异。
5. 校验上游源码 checksum。
6. 重新生成 CLI Manifest 并确认无差异。
7. 检查公共 ABI 只导出允许的 gs_ 符号。
8. 校验每个平台 capabilities 与平台测试结果一致。

### 16.2 平台构建

CI Matrix：

- macos-latest：iOS Simulator、macOS、原生测试。
- windows-latest：Windows x64、原生测试。
- Linux Runner：Android arm64-v8a/x86_64 构建和 ELF 检查。

每个平台都必须构建 example，不允许只编译原生库。

### 16.3 发布前检查

- flutter pub publish --dry-run。
- 示例 Android release APK。
- 示例 Android release AAB。
- 示例 iOS release no-codesign 构建。
- 示例 macOS release 构建。
- 示例 Windows release 构建。
- Android 16 KB 自动检查。
- Gifsicle 1.96 全部 CLI Options 覆盖报告。
- 四平台 capabilities 报告。
- CHANGELOG 与版本一致。
- Git tag、pub package version、Bridge ABI version 可追溯。

## 17. 版本策略

插件版本与 Gifsicle 上游版本分开管理：

- 插件从 0.1.0 开始。
- 达到所有 1.0 验收项后发布 1.0.0。
- Dart 公共 API 按 Semantic Versioning。
- C ABI 使用独立整数 GS_BRIDGE_ABI_VERSION。
- Gifsicle 上游版本通过 gs_gifsicle_version 查询。

升级上游 Gifsicle 时：

1. 更新源码和 checksum。
2. 重新应用或重写补丁。
3. 审阅 NEWS 和安全修复。
4. 执行完整 Fixture、Fuzz、性能和四平台测试。
5. 若输出行为变化，在 CHANGELOG 中明确说明。
6. 若 C ABI 未变，不应无理由提升 Bridge ABI。

## 18. 许可证处理

根据本次范围约定，开源许可证问题暂不纳入本轮实施范围：

- 不作为原型、功能开发、测试或 1.0 技术验收的阻断项。
- 当前 Spec 不制定闭源分发、pub.dev 发布或商业授权策略。
- 不在 CI 中增加许可证发布门禁。
- LICENSE 和 NOTICE 文件是否加入，由后续单独的许可任务决定。

为了保证工程可复现，当前实施仍需记录 Gifsicle 上游版本、源码来源、checksum 和本地补丁；这些记录只属于源码与构建追踪要求，不代表本轮已经完成许可评估。

## 19. 独立插件集成契约

gifsicle_flutter 必须作为独立包完成开发、测试和发布，不假设消费方使用任何特定状态管理、MethodChannel、FFmpeg 包或目录结构。

### 19.1 最小消费示例

~~~yaml
dependencies:
  gifsicle_flutter: ^1.0.0
~~~

~~~dart
final result = await Gifsicle.transformFile(
  inputPath: inputPath,
  outputPath: outputPath,
  overwrite: true,
  options: const GifsicleOptions(
    optimizationLevel: 3,
    lossy: 20,
    colors: 128,
  ),
);
~~~

### 19.2 完整命令消费示例

~~~dart
final result = await Gifsicle.execute(
  GifsicleCommand(
    arguments: [
      const GifsicleArgument.option('--explode'),
      GifsicleArgument.inputFile(
        id: 'animation',
        path: inputPath,
      ),
    ],
    collectGeneratedFiles: true,
  ),
);

for (final file in result.generatedFiles) {
  // 由消费方决定保存、展示或丢弃。
}
~~~

### 19.3 插件边界

插件负责：

- Gifsicle 原生源码构建和四平台捆绑。
- FFI ABI 和内存安全。
- 完整 argv 调用。
- 类型安全快捷接口。
- 平台能力查询。
- 工作目录和临时文件。
- stdout、stderr、输出文件和错误映射。

消费项目负责：

- 文件选择和系统相册权限。
- UI、进度展示和业务状态。
- 决定输出文件最终位置。
- 根据 capabilities 决定是否展示平台相关功能。
- 根据业务需要设置资源限制。

### 19.4 独立性验收

至少创建两个不共享业务代码的消费示例：

1. 仓库内标准 Flutter example。
2. CI 动态创建的最小 Flutter 应用，只添加 pub/path dependency。

第二个应用不得复制插件仓库中的平台构建配置。四个平台都能构建和运行，才可以证明插件没有隐含依赖。

## 20. 分阶段实施

### Phase 0：脚手架与源码基线

- [ ] 使用 Flutter package_ffi 创建项目。
- [ ] 设置 Flutter 3.38+/Dart 3.10+。
- [ ] 建立基础 CI。
- [ ] 添加 Gifsicle 1.96 源码、来源和 checksum。
- [ ] 添加 README 和 CHANGELOG。

完成标准：空实现能够在四个平台构建 example，且消费项目不需手工原生配置。

### Phase 1：最小原生 Bridge

- [ ] 定义 gifsicle_bridge.h。
- [ ] 定义 ABI 版本和 Options/Result。
- [ ] 完成 export 宏。
- [ ] 完成 result 分配与释放。
- [ ] 完成 version 查询。
- [ ] 完成 capabilities 查询。
- [ ] 完成 gs_execute 的 argv/stdin/stdout/stderr。
- [ ] 接入最小 GIF 读取和原样写出。
- [ ] 替换 fatal exit。
- [ ] 建立原生 mutex。

完成标准：四平台可以通过 FFI 输入一个 GIF 并返回合法 GIF，也可以执行 help/version/info。

### Phase 2：完整 Gifsicle CLI 能力

- [ ] 生成 Gifsicle 1.96 CLI Manifest。
- [ ] 参数顺序和逐文件 Options。
- [ ] stdin 和 stdout。
- [ ] 多输入合并。
- [ ] 帧选择与帧范围。
- [ ] batch。
- [ ] explode。
- [ ] multifile。
- [ ] info。
- [ ] 优化等级。
- [ ] lossy。
- [ ] colors。
- [ ] colormap。
- [ ] dither。
- [ ] gamma。
- [ ] scale。
- [ ] resize。
- [ ] crop。
- [ ] rotate。
- [ ] flip。
- [ ] position。
- [ ] delay。
- [ ] disposal。
- [ ] loop。
- [ ] background。
- [ ] transparency。
- [ ] logical screen。
- [ ] interlace。
- [ ] careful。
- [ ] conserve-memory。
- [ ] comment、name 和 extension。
- [ ] removeComments。
- [ ] warning 收集。
- [ ] 错误码映射。
- [ ] 平台相关选项 capability 标记。
- [ ] Manifest 中其余全部参数。

完成标准：Manifest 无遗漏；各平台对每个参数都有 supported、partiallySupported 或 unsupported 的测试结论。

### Phase 3：Dart API 与 Worker

- [ ] 完成 ffigen。
- [ ] 完成 Dart Models。
- [ ] 完成参数校验。
- [ ] 完成 GifsicleCommand 和 Argument Tokens。
- [ ] 完成 capabilities API。
- [ ] 完成长期 Worker isolate。
- [ ] 使用 TransferableTypedData。
- [ ] 完成 execute。
- [ ] 完成 executeArguments。
- [ ] 完成 transformBytes。
- [ ] 完成 transformFile。
- [ ] 完成隔离工作目录。
- [ ] 完成 batch/explode 动态输出收集。
- [ ] 完成安全覆盖和临时文件清理。
- [ ] 完成 Exception 映射。

完成标准：示例应用可以无卡顿地调用快捷 API 和完整命令 API。

### Phase 4：平台硬化

- [ ] Android 16 KB ELF。
- [ ] Android 16 KB APK/AAB。
- [ ] Android 4 KB 和 16 KB 运行测试。
- [ ] iOS Simulator。
- [ ] iOS 真机。
- [ ] macOS arm64。
- [ ] macOS x86_64。
- [ ] Windows x64。
- [ ] Unicode 路径。
- [ ] 输入输出同路径。
- [ ] 四平台 CLI Manifest 能力报告。
- [ ] 平台不支持选项错误。

完成标准：平台矩阵全部通过。

### Phase 5：安全、性能与发布

- [ ] ASan。
- [ ] UBSan。
- [ ] Leak 检查。
- [ ] Fuzz。
- [ ] Benchmark。
- [ ] API 文档。
- [ ] README 使用示例。
- [ ] Flutter example。
- [ ] pub publish dry-run。

完成标准：满足 1.0 Definition of Done。

### Phase 6：独立消费验证

- [ ] 仓库内 example 使用预发布版本。
- [ ] CI 创建空白 Flutter 消费应用。
- [ ] 消费应用只添加 gifsicle_flutter 依赖。
- [ ] 不添加平台原生配置。
- [ ] Android/iOS/macOS/Windows 构建和运行。
- [ ] 验证快捷 API。
- [ ] 验证完整命令 API。
- [ ] 验证 capabilities。
- [ ] 验证发布后的 pub 包不缺少原生源码或 Build Hook 文件。

## 21. 风险清单

| 编号 | 风险 | 影响 | 缓解 |
| --- | --- | --- | --- |
| R-001 | 插件隐含依赖某个消费项目配置 | 其他项目无法直接使用 | 空白消费应用 CI、禁止手工平台配置 |
| R-002 | 上游 CLI 大量全局状态 | 并发错误、状态污染 | 原生 mutex、每次 reset、连续调用测试 |
| R-003 | fatal_error 或 exit 终止宿主 | 应用崩溃 | 全量审计并改为错误返回 |
| R-004 | 损坏 GIF 触发内存安全问题 | 崩溃或安全漏洞 | Sanitizer、Fuzz、尺寸和溢出检查 |
| R-005 | 上游升级改变参数或输出行为 | API 或结果回归 | 固定版本、CLI Manifest diff、Fixture 基线 |
| R-006 | Windows Unicode 路径 | 文件读取失败 | 原生字节 API、Dart 文件读写 |
| R-007 | 大 GIF 字节复制导致内存峰值 | 移动端 OOM | TransferableTypedData、Limits、Benchmark |
| R-008 | Build Hook 工具包 API 变化 | 插件构建失败 | 锁定版本、CI 四平台验证 |
| R-009 | Android 仅 ELF 对齐但 APK 未对齐 | 16 KB 设备安装或启动失败 | 同时验证 ELF、APK、AAB 和设备 |
| R-010 | Apple 链接器裁剪 FFI 符号 | 运行时找不到函数 | visibility、used、导出符号测试 |
| R-011 | Windows CRT 跨边界释放 | 堆损坏 | 所有原生内存由 gs_result_free 释放 |
| R-012 | 强制取消破坏原生状态 | 崩溃或泄漏 | 1.0 不强制中断，后续协作取消 |
| R-013 | 完整 CLI 参数存在遗漏 | 对外能力声明不真实 | 从 help/man/options 表生成 Manifest 并逐项测试 |
| R-014 | 外部命令类选项受平台限制 | 四端行为不一致 | capabilities、明确 unsupported、桌面条件支持 |
| R-015 | batch/explode 输出逃逸工作目录 | 覆盖用户文件或读取无关文件 | 隔离目录、规范化路径、拒绝符号链接和目录逃逸 |

## 22. Definition of Done

插件 1.0.0 只有在以下条件全部满足后才算完成：

- [ ] 通过 pubspec.yaml 一条依赖即可使用。
- [ ] 插件构建、测试和发布不引用任何特定消费项目文件。
- [ ] Android、iOS、macOS、Windows 公共 Dart API 完全一致。
- [ ] 消费项目不需要手工原生构建配置。
- [ ] 不执行外部 Gifsicle 命令或子进程。
- [ ] Gifsicle 1.96 CLI Manifest 中全部命令和参数均有实现状态。
- [ ] 四个平台对每项能力明确标记 supported、partiallySupported 或 unsupported。
- [ ] 所有平台声称 supported 的选项均有对应平台测试。
- [ ] execute 支持 Token 化 argv、多输入、stdin、stdout 和声明输出。
- [ ] batch、explode 和其他动态输出能够安全收集。
- [ ] 不支持的平台选项返回明确异常，不静默忽略。
- [ ] Android arm64-v8a 支持 16 KB ELF 和 ZIP 对齐。
- [ ] Android 16 KB 环境实际处理 GIF 成功。
- [ ] iOS Simulator 和真机处理 GIF 成功。
- [ ] macOS arm64 和 x86_64 构建通过。
- [ ] Windows x64 构建和运行通过。
- [ ] 中文、空格、emoji 路径通过。
- [ ] 同路径输入输出不会提前破坏原文件。
- [ ] 默认操作无损。
- [ ] 损坏输入只返回异常，不终止宿主。
- [ ] 连续 100 次调用无资源泄漏趋势。
- [ ] 多 isolate 调用不发生状态串扰。
- [ ] ASan、UBSan、Fuzz 无未解决崩溃。
- [ ] ffigen 生成结果可复现。
- [ ] 上游源码、版本、checksum 和补丁可追溯。
- [ ] README、API 文档、CHANGELOG、example 完整。
- [ ] flutter pub publish --dry-run 通过。

## 23. 后续可选能力

不阻断 1.0：

- Linux 支持。
- Windows ARM64。
- Android armeabi-v7a。
- 真正并行的上下文化 Gifsicle Core。
- 协作取消和进度回调。
- 文件流式输入输出，降低大 GIF 内存峰值。
- 为全部 CLI 参数增加一一对应的类型安全 Builder；1.0 已可通过完整命令 API 调用。
- 联邦插件形式的平台扩展。
- 独立原生 SDK 产物，例如 Android AAR、Apple XCFramework 和 Windows NuGet。

## 24. 参考资料

- Gifsicle 官方仓库：https://github.com/kohler/gifsicle
- Gifsicle 官网：https://www.lcdf.org/gifsicle/
- Gifsicle 1.96 变更：https://github.com/kohler/gifsicle/blob/master/NEWS.md
- Flutter FFI：https://docs.flutter.dev/platform-integration/bind-native-code
- Dart Build Hooks：https://dart.dev/tools/hooks
- Android 16 KB 页面支持：https://developer.android.com/guide/practices/page-sizes
- Android Library 发布：https://developer.android.com/build/publish-library/upload-library
- React Native Gifsicle 参考实现：https://github.com/numandev1/react-native-gifsicle
