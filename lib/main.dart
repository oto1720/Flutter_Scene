import 'package:flutter/material.dart';

import 'demos/bar_chart/bar_chart_page.dart';
import 'demos/stack_tower/stack_tower_page.dart';

void main() => runApp(const FlutterSceneLabApp());

class FlutterSceneLabApp extends StatelessWidget {
  const FlutterSceneLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Scene Lab',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      // `--dart-define=DEMO=bar_chart` などで起動するとデモを直接開く。
      home: switch (const String.fromEnvironment('DEMO')) {
        'bar_chart' => const BarChartPage(),
        'stack_tower' => const StackTowerPage(),
        _ => const DemoMenuPage(),
      },
    );
  }
}

class _Demo {
  const _Demo(this.title, this.description, this.icon, this.builder);
  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;
}

final _demos = [
  _Demo(
    '3D 棒グラフ',
    '月 × カテゴリの売上を立体で表示。回転・ズーム・タップで値を確認',
    Icons.bar_chart,
    (_) => const BarChartPage(),
  ),
  _Demo(
    '積み木タワー',
    '往復するブロックをタップで落として高く積み上げるミニゲーム',
    Icons.view_in_ar,
    (_) => const StackTowerPage(),
  ),
];

class DemoMenuPage extends StatelessWidget {
  const DemoMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Scene Lab')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _demos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final demo = _demos[i];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(demo.icon, size: 36),
              title: Text(demo.title),
              subtitle: Text(demo.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: demo.builder)),
            ),
          );
        },
      ),
    );
  }
}
