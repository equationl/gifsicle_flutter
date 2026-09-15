import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gifsicle_flutter/gifsicle_flutter.dart';

import 'demo_catalog.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xff006b62),
    ),
    home: const ExampleApp(),
  ),
);

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});
  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  Uint8List? sample;
  GifsicleCapabilities? capabilities;
  DemoResult? result;
  String? error;
  String version = '读取版本中…', query = '';
  int page = 0, selected = 0;
  bool busy = false, useStdin = true;
  final cli = TextEditingController(
    text: '["--resize-width", "120", "--optimize=3"]',
  );

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    try {
      final data = await rootBundle.load('assets/sample.gif');
      final caps = await Gifsicle.capabilities();
      final label =
          '${caps.platform} · Gifsicle ${Gifsicle.gifsicleVersion} · Bridge ABI ${Gifsicle.bridgeVersion}';
      if (mounted) {
        setState(() {
          sample = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          capabilities = caps;
          version = label;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          version = '初始化失败';
        });
      }
    }
  }

  @override
  void dispose() {
    cli.dispose();
    super.dispose();
  }

  Future<void> perform(Future<DemoResult> Function() action) async {
    setState(() {
      busy = true;
      result = null;
      error = null;
    });
    try {
      final value = await action();
      if (mounted) setState(() => result = value);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is GifsicleException
              ? '${e.code.name} · nativeCode=${e.nativeCode}\n${e.message}\n${e.warnings.join('\n')}'
              : '$e',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<DemoResult> executeCli() async {
    final decoded = jsonDecode(cli.text);
    if (decoded is! List || decoded.any((e) => e is! String)) {
      throw const FormatException('请输入 JSON 字符串数组，例如 ["--info"]。');
    }
    // 高级接口可直接访问路径；此处只传入用户明确输入的参数。
    return describeExecution(
      await Gifsicle.executeArguments(
        decoded.cast<String>(),
        stdin: useStdin ? sample : null,
      ),
    );
  }

  Widget preview(String name, Uint8List bytes) => SizedBox(
    width: 220,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$name · ${bytes.length} 字节',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: 220,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, error, stack) =>
                const Center(child: Text('无法预览此 GIF')),
          ),
        ),
      ],
    ),
  );
  Widget panel(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget resultPanel() => panel('运行结果', [
    if (busy) const LinearProgressIndicator(),
    if (error != null)
      SelectableText(
        error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    if (!busy && error == null && result == null)
      const Text('选择功能并运行。结果保留退出码、耗时、输出文件和警告。'),
    if (result != null) ...[
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: result!.text));
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('结果已复制')));
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('复制结果'),
        ),
      ),
      SelectableText(result!.text),
      const SizedBox(height: 16),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: result!.images.entries
            .map((e) => preview(e.key, e.value))
            .toList(),
      ),
    ],
  ]);

  Widget demoPage() {
    final demo = demos[selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panel('API 演示 · ${demos.length} 个场景', [
          const Text('使用随包内置的多帧动画，不需要存储权限或外部文件。文件演示在应用临时目录内运行并自动清理。'),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '选择演示',
              border: OutlineInputBorder(),
            ),
            items: [
              for (var i = 0; i < demos.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${i + 1}. ${demos[i].title}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: busy
                ? null
                : (v) => setState(() {
                    selected = v!;
                    result = null;
                    error = null;
                  }),
          ),
          const SizedBox(height: 16),
          Text(demo.description),
          const SizedBox(height: 8),
          SelectableText(
            demo.api,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (demo.options != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SelectableText(demo.options!.toArguments().join(' ')),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                key: const Key('run-demo'),
                onPressed: busy || sample == null
                    ? null
                    : () => perform(() => runDemo(demo, sample!)),
                icon: const Icon(Icons.play_arrow),
                label: Text(busy ? '处理中…' : '运行演示'),
              ),
              if (sample != null) preview('原始动画', sample!),
            ],
          ),
        ]),
        resultPanel(),
      ],
    );
  }

  Widget cliPage() => Column(
    children: [
      panel('CLI 参数实验室', [
        const Text(
          '输入 JSON 字符串数组，一个元素对应一个 argv token。可使用全部可用 CLI 选项；不会执行 shell。stdout 是二进制，只有非 GIF 输出才按 UTF-8 展示。',
        ),
        const SizedBox(height: 12),
        const Text(
          '此处调用 executeArguments，可访问显式参数中的本地路径。移动端路径须位于应用可访问的目录。需要隔离文件及输出收集时，使用演示页的 execute 场景。',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: cli,
          enabled: !busy,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: '参数数组',
            border: OutlineInputBorder(),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('将内置动画作为 stdin'),
          value: useStdin,
          onChanged: busy ? null : (v) => setState(() => useStdin = v),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in {
              '优化': '["--optimize=3"]',
              '信息': '["--info"]',
              '帮助 / 全部参数说明': '["--help"]',
              '版本': '["--version"]',
              '抽取首帧': '["-", "#0"]',
            }.entries)
              ActionChip(
                label: Text(preset.key),
                onPressed: busy
                    ? null
                    : () => setState(() {
                        cli.text = preset.value;
                      }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy || sample == null ? null : () => perform(executeCli),
          child: const Text('执行参数'),
        ),
      ]),
      resultPanel(),
    ],
  );

  Widget capabilitiesPage() {
    final caps = capabilities;
    final entries =
        caps?.options.entries
            .where((e) => e.key.toLowerCase().contains(query.toLowerCase()))
            .toList() ??
        [];
    entries.sort((a, b) => a.key.compareTo(b.key));
    return Column(
      children: [
        panel('平台能力与 API 说明', [
          SelectableText(version),
          const SizedBox(height: 12),
          const Text(
            'supported：已声明完全支持；partiallySupported：可执行但平台或边界验收尚未齐全；unsupported：不可用。supportsOption 只对 supported 返回 true。',
          ),
          const SizedBox(height: 8),
          if (caps != null)
            SelectableText(
              '特性：${caps.features.map((e) => e.name).join(', ')}\n'
              'option("--resize"): ${caps.option('--resize').level.name}\n'
              'supportsOption("--resize"): ${caps.supportsOption('--resize')}\n'
              '未知选项：${caps.option('--unknown').reason}',
            ),
          const SizedBox(height: 12),
          const Text(
            '限制：外部命令不可用；原生请求串行；丢弃 Future 不会取消转换。GifsicleLimits 可限制输入/输出字节、帧数及画布像素；输出限制在收集时检查，不是原生内存硬上限。',
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: '搜索 CLI 能力，例如 resize / no- / lossy',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 12),
          Text('匹配 ${entries.length} 项；具体用法见 CLI 页的“帮助 / 全部参数说明”。'),
          for (final e in entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.key),
              subtitle: Text(
                '${e.value.level.name}\n${e.value.reason ?? '无额外限制说明'}',
              ),
              isThreeLine: true,
            ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Gifsicle 功能演示'),
      actions: [
        IconButton(
          tooltip: '重新读取版本与能力',
          onPressed: busy ? null : initialize,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850;
          final content = Expanded(
            child: SingleChildScrollView(
              key: PageStorageKey(page),
              padding: EdgeInsets.all(wide ? 28 : 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1050),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        version,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 16),
                      if (page == 0)
                        demoPage()
                      else if (page == 1)
                        cliPage()
                      else
                        capabilitiesPage(),
                    ],
                  ),
                ),
              ),
            ),
          );
          return Row(
            children: [
              if (wide)
                NavigationRail(
                  selectedIndex: page,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: busy
                      ? null
                      : (v) => setState(() {
                          page = v;
                          result = null;
                        }),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.auto_awesome),
                      label: Text('API 演示'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.terminal),
                      label: Text('CLI 实验室'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.fact_check),
                      label: Text('能力与说明'),
                    ),
                  ],
                ),
              content,
            ],
          );
        },
      ),
    ),
    bottomNavigationBar: MediaQuery.sizeOf(context).width >= 850
        ? null
        : NavigationBar(
            selectedIndex: page,
            onDestinationSelected: busy
                ? null
                : (v) => setState(() {
                    page = v;
                    result = null;
                  }),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.auto_awesome),
                label: 'API 演示',
              ),
              NavigationDestination(
                icon: Icon(Icons.terminal),
                label: 'CLI 实验室',
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check),
                label: '能力与说明',
              ),
            ],
          ),
  );
}
