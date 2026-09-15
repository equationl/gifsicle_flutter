## 未发布

- 完善四平台 demo：25 个 API 场景、CLI 参数编辑、能力检索、GIF 预览和中文功能说明。
- 修复 Android 默认不覆盖文件输出因硬链接受限而失败的问题，采用原子禁止覆盖重命名。

## 0.1.0

- Use the Flutter package_ffi template and Dart Build Hooks for an embedded Gifsicle 1.96 C core.
- Add complete tokenized CLI execution, typed transformations, a persistent worker isolate, and binary stdin/stdout.
- Add native serialization, tracked request allocation cleanup, state restoration, isolated file I/O, UTF-8 diagnostics and atomic output replacement.
- Add 112-entry CLI manifest, conformance fixtures, native sanitizers/fuzzing, integration tests, build and package validation tools.
- Reject external processes, internal parallel execution, workspace escape and truncated GIF blocks explicitly.
- Initial development release. Full 1.0 acceptance is not complete; see IMPLEMENTATION_STATUS.md.
