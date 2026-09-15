# 四平台功能演示

Android、iOS、macOS、Windows 共用 `lib/main.dart`，均直接调用包的真实原生 API。手机使用底部导航，宽窗口使用侧边导航。所有预设使用自带多帧 GIF；文件演示自动创建并删除应用临时目录，不需要额外存储权限。

## 启动

在本目录执行：

```sh
flutter pub get
flutter run -d macos
# 或 flutter run -d windows / <Android 设备 ID> / <iOS 模拟器或设备 ID>
flutter devices
```

桌面可直接缩放窗口查看导航切换；所有页面支持滚动及长文本选择。GIF 预览按容器适配，精确输出尺寸以参数和 GIF 信息为准。

iOS 真机需要在 Xcode 中配置自己的签名团队。Windows 需要在 Windows 主机运行。选择目标平台的 Flutter 标准工具链即可，不需要手动复制原生库或修改平台构建文件。

## 页面

- **API 演示**：选择 25 个场景之一，阅读功能和参数说明，再点击运行。结果显示字节数、输出/输入比例、耗时、警告、退出码、输出产物及 GIF 预览。结果文本可复制。
- **CLI 实验室**：直接编辑 JSON 字符串数组；每项都是一个独立参数，包含空格的内容仍是一个参数。可切换是否将内置动画传给 stdin。预设包括优化、信息、完整帮助、版本及抽帧；通过帮助查看所有 CLI 选项的用途。可执行当前包支持的全部 CLI 参数组合，不经 shell。
- **能力与说明**：显示实际平台、Gifsicle/Bridge 版本、features、option/supportsOption 调用结果；搜索完整能力表，包括取反选项和不可用原因。

CLI 高级入口直接访问显式路径；路径必须在当前应用权限范围内。需要自动暂存、资源限制和输出收集时使用 `execute(GifsicleCommand)`。相对路径使用进程当前目录；“直接参数与工作目录”预设展示显式 workingDirectory 的用法。

## 公开 API 覆盖

| API / 类型 | 演示入口 |
| --- | --- |
| bridgeVersion、gifsicleVersion、capabilities | 页首、能力与说明、刷新按钮 |
| capabilities.options/features/platform/gifsicleVersion/bridgeAbiVersion、option、supportsOption | 能力与说明；support level 与 reason 原样展示 |
| transformBytes、GifsicleBytesResult 全部字段与 compressionRatio | 前 15 个转换场景；显示生成的 toArguments 参数 |
| optimizationLevel、lossy、colors | 无损优化、有损与减色、优化与兼容标志、关闭优化 |
| Gamma.srgb/linear/value | 无损优化、线性 Gamma、自定义 Gamma |
| Dither.none/floydSteinberg/ordered/自定义构造 | 无抖动、误差扩散、有序抖动、自定义抖动 |
| Resize.exact/fit（含 allowUpscale）/width/height | 对应 5 个尺寸场景；原始和结果预览 |
| Scale、Crop | 缩放倍率、裁剪区域；resize 和 scale 互斥 |
| interlace（null/true/false）、careful、removeComments | 默认场景、优化与兼容标志、关闭优化 / 交错 |
| transformFile、overwrite、GifsicleFileResult 全部字段 | 文件转换与同路径替换；中文路径，先禁止覆盖创建新文件，再允许同路径替换 |
| execute、GifsicleCommand | 内存输出、文件输出、多输入、拆帧、batch、stdin、错误场景 |
| option、literal、frameSelector | 声明内存输出、多输入与帧选择 |
| inputBytes（id/bytes/suggestedName）、inputFile | 声明内存/文件输入；suggestedName 只是提示，不是实际暂存路径 |
| outputMemory（id/suggestedName）、outputFile（id/path/overwrite） | 声明输出；通过 outputs 的 ID 访问 Memory/FileOutputArtifact |
| command.stdin、collectGeneratedFiles | 标准输入 / 输出（关闭收集）、拆帧和 batch（开启收集） |
| GifsicleLimits 四个限制 | 标准输入 / 输出启用全部限制；错误场景触发 maxInputBytes |
| ExecutionResult.exitCode/isSuccess/stdout/stderr/outputs/generatedFiles/elapsed | 所有命令结果统一展示；二进制 GIF 不强行按文本解码 |
| GifsicleGeneratedFile.relativePath/bytes | 拆帧及批处理结果预览 |
| executeArguments（stdin/workingDirectory/allowExternalCommands） | CLI 实验室、直接工作目录、错误场景 |
| GifsicleException、UnsupportedFeatureException、code/message/nativeCode/warnings | 错误分类与恢复；界面捕获未预期异常 |
| disposeForTesting | 队列与生命周期；等待请求排空，随后验证自动重启 |

factory 对应的具体 Argument/Resize 子类使用相同实现，演示通过公开 factory 构造。`toMessage`、`toArguments`、`argument`、`validate` 与 `positive` 属于模型序列化/校验辅助入口；运行各场景时由公开 API 调用，参数字符串可在转换场景查看。不直接演示内部 C ABI 或 `src/` 私有实现。

错误示例只触发可控错误；不会尝试制造真实 OOM、ABI 错配或取消原生任务。`cancelled` 枚举存在，但当前 API 不提供强制取消。未知 CLI 选项通常是非零退出码，桥接错误抛异常，两者区别会直接展示。

## 验证与边界

```sh
flutter analyze
flutter test integration_test/demo_test.dart -d macos
# 在对应平台连接设备后，将 macos 替换为目标 ID
```

`demo_test.dart` 逐一执行全部场景，并检查窄屏/宽屏布局及运行按钮。原有 `gifsicle_integration_test.dart` 保留 112 项 CLI 对照测试。

版本仍为 0.1.0；平台实际验证记录及尚未完成的 1.0 条件见根目录 IMPLEMENTATION_STATUS.md。能力标记 partiallySupported 不代表禁用；supportsOption 只对 supported 返回 true。输出限制在收集后执行，不是峰值内存硬限制。文件路径只用于演示，临时文件删除后不可再打开，但结果预览保留字节。


本轮实测（2026-09-15）：macOS、iOS 26.5 模拟器、Android 16 KB 模拟器均通过 25 个场景及响应式界面测试；静态分析通过。Windows 代码与测试已接入，尚无 Windows 主机上的运行结果。
