# 实施与验收状态

日期：2026-09-14。按预约执行，已使用 `flutter create --template=package_ffi --project-name gifsicle_flutter .` 创建项目。原始 `IMPLEMENTATION_SPEC.md` 保留不变。当前版本 **0.1.0 原型，尚未满足全部 1.0 验收条件**；没有提交、推送或发布。

## 已实现

- 固定 Gifsicle 1.96 源码、归档、版本和文件 SHA-256，以及可复现补丁；保留原始 CLI 参数解析器。
- Dart Build Hooks、C ABI、自动生成 FFI 绑定；Android/iOS/macOS/Windows 构建配置。
- 原生进程内互斥、状态恢复、按请求分配追踪和统一释放；独立内存输入输出及日志流。禁止外部命令，内部线程受限为单线程。
- 持久 Worker isolate、请求队列、TransferableTypedData、错误恢复和 dispose/restart；字节转换直接走内存流。
- 类型化转换参数、保序 CLI token、隔离文件暂存、Unicode 路径、批处理和 explode 输出收集、同路径原子替换及禁止覆盖。
- GIF 结构/资源预检、原生参数边界检查；修复发现的 dither 参数栈越界、短应用扩展读取、非有限 gamma/scale、截断输入和 Android 读流关闭错误。
- 示例、单元/原生/集成测试、CLI 对照清单、fuzz harness、基准和 CI。CI 工作流已编写，尚未在远端运行。

## 已有验证证据

| 范围 | 结果与边界 |
| --- | --- |
| Dart | `dart analyze` 无问题；13 项测试通过，含并发、跨 isolate、Unicode、同路径写入、错误恢复及销毁重启 |
| 原生内存安全 | ASan、UBSan、LeakSanitizer 测试通过，含并发重复调用及 180 个分配失败注入点 |
| CLI | 112 项基础用例与未修改的同版本 CLI 对照通过；不是全部参数组合和边界的穷尽验证 |
| macOS Apple Silicon | Release 构建、真实解码及 112 项 CLI 集成用例通过；独立空白消费项目仅加 path 依赖后构建通过 |
| iOS | 模拟器运行并通过两组集成测试（包含 112 项 CLI）；无签名真机 Release 构建通过，未验证物理设备 |
| Android | 4 KB 和 16 KB 模拟器分别通过两组集成测试（包含 112 项 CLI）；APK/AAB Release 构建通过 |
| Android 对齐 | APK 内 9 个原生库 ELF LOAD 和 ZIP 数据偏移满足 16 KB；AAB 配置为 PAGE_ALIGNMENT_16K |
| 原生交叉编译 | macOS x86_64、iOS arm64 真机、iOS x86_64 模拟器已编译；不等价于对应应用运行 |
| Windows | 已实现代码和 CI 配置；当前主机未进行 Windows 编译/运行验收 |
| Fuzz | GIF 9,226 次、参数 6,434 次，分别约 46 秒，无 sanitizer 报告；GIF harness 有尺寸和帧数约束，不代表无界输入覆盖 |
| 输出与性能 | 7 类确定性样本无损输出与原版 CLI 一致，合成 RGBA/时序一致；详见 BENCHMARK_BASELINE.md |
| 源码追溯 | 归档、补丁及 33 个文件哈希通过；从原始归档在临时目录应用补丁后逐文件复现 |
| 符号 | 仅导出 9 个 gs ABI 函数；POSIX 原生库未导入宿主 exit/assert、stdio 重定向或子进程调用 |

Android 物理设备安装曾返回 `INSTALL_FAILED_USER_RESTRICTED`，未绕过设备限制；改用独立模拟器完成上述验证。

## 仍未满足的 1.0 条件

1. **Spec §8.3 的错误恢复重构尚未完成**：当前使用带完整请求分配追踪和清理的 `setjmp/longjmp` 原型方案。仍须改为显式上下文/返回码错误传播，并重新审计所有退出及清理路径，才能满足该节的 1.0 要求。
2. Windows 实际构建/运行、物理 iOS/Android 验收、macOS x86_64 应用运行、四平台独立消费者构建与运行矩阵尚不完整。最低 Flutter 3.38/Dart 3.10 工具链未单独验证。
3. 112 项 CLI 基础对照不能覆盖全部别名、取反、参数排列和组合边界；能力清单保守标记为 partiallySupported（外部命令为 unsupported），没有宣称完全支持。`supportsOption` 仅对 supported 返回 true。
4. 需要更长时间 fuzz、更广输入分布、真实照片有损质量及移动端峰值/回落内存基准。当前限制项可配置且默认未强制设定；输出大小限制在收集后执行，不是原生内存硬上限。
5. `flutter pub publish --dry-run` 已执行但未通过：包根 LICENSE 尚未确定，并有 homepage/repository 和精确依赖版本警告。遵照 Spec §18 暂不决定项目许可证；未把此项作为开发阻断，也未将上游许可证冒充为项目许可证。

## 复核入口

使用 README.md 的快速开始；`tool/` 中包含原生构建、源码校验、CLI 对照、对齐检查、消费者构建及基准工具。测试记录位于 `tool/reports/`，本机日志位于 `build/`（均从发布包排除）。原始 spec 的全部验收项仍以实际平台证据为准，本文不等同于最终 1.0 验收签字。


## 2026-09-15：完整 Demo

- Android/iOS/macOS/Windows 共用响应式示例，包含 25 个真实 API 演示、JSON argv 编辑器、完整 CLI 帮助入口、可搜索能力表、原始/结果 GIF 预览及可复制结果。
- `example/README.md` 提供功能说明、参数语义、全部公开业务 API 对照及各平台启动方法。
- `flutter analyze` 通过；新增 `demo_test.dart` 在 macOS、iOS 26.5 模拟器、Android 16 KB 模拟器均通过：逐一执行 25 个场景，并验证窄屏/宽屏布局和运行按钮。Windows 新 demo 尚未实际编译/运行，已纳入 CI。
- Android 文件演示暴露默认不覆盖发布的硬链接失败问题；Android 改为 `renameat2(RENAME_NOREPLACE)` 原子发布。新建输出、同路径替换和拒绝覆盖均通过真实 Android 演示测试。其他平台保留既有发布实现。
