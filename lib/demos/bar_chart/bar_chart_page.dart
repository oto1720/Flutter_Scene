import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../common/scene_utils.dart';
import 'bar_chart_data.dart';

/// 月 × カテゴリのデータを 3D の棒グラフで表示するデモ。
///
/// - ドラッグで回転、ピンチでズーム、2 本指ドラッグで移動
/// - 棒をタップすると値を表示
/// - データセットを切り替えると棒が伸び縮みするアニメーション
class BarChartPage extends StatefulWidget {
  const BarChartPage({super.key});

  @override
  State<BarChartPage> createState() => _BarChartPageState();
}

// レイアウト (ワールド座標)
const _spacingX = 0.75; // 月の間隔
const _spacingZ = 0.95; // カテゴリの間隔
const _footprint = 0.5; // 棒の太さ
const _maxBarHeight = 4.0;
const _sink = 0.05; // 棒の底を台座に少し埋めて、面の重なり (z-fighting) を避ける
const _animDuration = 0.9; // 秒

class _BarChartPageState extends State<BarChartPage> {
  final Scene _scene = Scene();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final Map<Node, _Bar> _barsByNode = {};
  late final OrbitCameraController _orbit;

  bool _ready = false;
  int _datasetIndex = 0;
  double _clock = 0;
  _Bar? _selected;

  ChartDataset get _dataset => sampleDatasets[_datasetIndex];
  int get _monthCount => _dataset.months.length;
  int get _categoryCount => _dataset.categories.length;
  double get _widthX => _monthCount * _spacingX + _footprint;
  double get _depthZ => _categoryCount * _spacingZ + _footprint;

  @override
  void initState() {
    super.initState();
    Scene.initializeStaticResources().then((_) {
      if (!mounted) return;
      _buildScene();
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _frame.dispose();
    super.dispose();
  }

  vm.Vector3 _barBase(int month, int category) => vm.Vector3(
    (month - (_monthCount - 1) / 2) * _spacingX,
    0,
    (category - (_categoryCount - 1) / 2) * _spacingZ,
  );

  void _buildScene() {
    setGradientSky(
      _scene,
      zenith: vm.Vector3(0.10, 0.16, 0.32),
      horizon: vm.Vector3(0.55, 0.62, 0.75),
      ground: vm.Vector3(0.20, 0.22, 0.26),
    );
    addSunLight(_scene, from: vm.Vector3(-5, 12, -8));

    // 台座: 上面が y = 0。棒はこの中から伸びてくる。
    const pedestalDepth = _maxBarHeight + 0.5;
    _scene.add(
      Node(
          name: 'pedestal',
          mesh: Mesh(
            CuboidGeometry(vm.Vector3(_widthX, pedestalDepth, _depthZ)),
            plasticMaterial(srgbToLinear(0.18, 0.2, 0.24), roughness: 0.8),
          ),
        )
        ..position = vm.Vector3(0, -pedestalDepth / 2, 0),
    );

    final dataset = _dataset;
    for (var m = 0; m < _monthCount; m++) {
      for (var c = 0; c < _categoryCount; c++) {
        final category = dataset.categories[c];
        final color = hsvToLinear(category.hue, 0.65, 0.9);
        final bar = _Bar(
          month: m,
          category: c,
          base: _barBase(m, c),
          color: color,
          material: plasticMaterial(color, roughness: 0.35),
          delay: m * 0.035 + c * 0.06,
        );
        bar.node = Node(name: 'bar_${m}_$c');
        _barsByNode[bar.node] = bar;
        _scene.add(bar.node);
      }
    }
    _applyDataset(animateFromZero: true);

    // カメラ: 回転ターゲットはグラフの少し上。
    final cameraNode = Node(name: 'camera');
    _orbit = OrbitCameraController(
      target: vm.Vector3(0, 1.2, 0),
      distance: 24, // 縦長のスマホ画面でも全体が収まる距離
      azimuth: 0.4,
      polar: 0.55,
      minPolar: 0.05, // 台座の下に回り込まない
      maxPolar: 1.45,
      minDistance: 5,
      maxDistance: 40,
    );
    cameraNode
      ..addComponent(CameraComponent(activateOnMount: true))
      ..addComponent(_orbit);
    _scene.add(cameraNode);
  }

  double _heightFor(double value) =>
      math.max(0.05, value / _niceMax * _maxBarHeight);

  /// 2 つのデータセットに共通の軸の最大値 (切り替えても目盛りが変わらない)。
  double get _niceMax {
    final max = sampleDatasets.map((d) => d.maxValue).reduce(math.max);
    return (max / 20).ceil() * 20;
  }

  void _applyDataset({bool animateFromZero = false}) {
    for (final bar in _barsByNode.values) {
      final target = _heightFor(_dataset.values[bar.month][bar.category]);
      bar.startAnimation(
        from: animateFromZero ? 0 : bar.currentTop,
        to: target,
        now: _clock,
      );
    }
  }

  void _onTick(Duration elapsed, double dt) {
    _clock += dt;
    for (final bar in _barsByNode.values) {
      bar.update(_clock);
    }
    _frame.value++; // ラベルを再描画
  }

  void _onTap(Offset position, Size viewSize) {
    final camera = _scene.camera;
    if (camera == null) return;
    final ray = camera.screenPointToRay(position, viewSize);
    final hit = _scene.raycast(ray);
    final bar = hit == null ? null : _barsByNode[hit.node];
    setState(() {
      _selected?.setHighlighted(false);
      _selected = bar == _selected ? null : bar;
      _selected?.setHighlighted(true);
    });
  }

  void _switchDataset(int index) {
    if (index == _datasetIndex) return;
    setState(() => _datasetIndex = index);
    _applyDataset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D 棒グラフ')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onTapUp: (d) => _onTap(d.localPosition, size),
                        child: CameraControls(
                          controller: _orbit,
                          child: SceneView(_scene, onTick: _onTick),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _LabelPainter(
                            repaint: _frame,
                            scene: _scene,
                            labels: _labels(),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 12,
                      child: _Header(
                        datasetIndex: _datasetIndex,
                        onChanged: _switchDataset,
                        categories: _dataset.categories,
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: _InfoCard(
                        text: _selected == null
                            ? 'ドラッグで回転・ピンチでズーム・棒をタップで値を表示'
                            : _describe(_selected!),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  String _describe(_Bar bar) {
    final value = _dataset.values[bar.month][bar.category];
    return '${_dataset.months[bar.month]} / '
        '${_dataset.categories[bar.category].name}: '
        '${value.toStringAsFixed(1)} 万円';
  }

  /// 3D 空間に置くテキストラベル (毎フレーム画面座標に投影して描く)。
  List<_WorldLabel> _labels() {
    final labels = <_WorldLabel>[];
    final frontZ = -_depthZ / 2 - 0.35;
    for (var m = 0; m < _monthCount; m++) {
      labels.add(
        _WorldLabel(
          () => vm.Vector3(_barBase(m, 0).x, 0, frontZ),
          _dataset.months[m],
        ),
      );
    }
    final sideX = _widthX / 2 + 0.25;
    for (var c = 0; c < _categoryCount; c++) {
      labels.add(
        _WorldLabel(
          () => vm.Vector3(sideX, 0, _barBase(0, c).z),
          _dataset.categories[c].name,
          alignLeft: true,
        ),
      );
    }
    final selected = _selected;
    if (selected != null) {
      labels.add(
        _WorldLabel(
          () => selected.base + vm.Vector3(0, selected.currentTop + 0.35, 0),
          _dataset.values[selected.month][selected.category].toStringAsFixed(1),
          emphasized: true,
        ),
      );
    }
    return labels;
  }
}

/// 1 本の棒の状態とアニメーション。
class _Bar {
  _Bar({
    required this.month,
    required this.category,
    required this.base,
    required this.color,
    required this.material,
    required this.delay,
  });

  final int month;
  final int category;
  final vm.Vector3 base;
  final vm.Vector4 color;
  final PhysicallyBasedMaterial material;
  final double delay;
  late final Node node;

  double currentTop = 0;
  double _from = 0;
  double _to = 0;
  double _startTime = 0;
  double _geometryHeight = -1;
  bool _animating = false;

  void startAnimation({
    required double from,
    required double to,
    required double now,
  }) {
    _from = from;
    _to = to;
    _startTime = now + delay;
    _animating = true;
    // ジオメトリは非一様スケールで伸ばすとライティングが崩れるので、
    // アニメーション中は「長い方の高さ」の箱を作り、台座から出す量で高さを表す。
    _setGeometryHeight(math.max(from, to) + _sink);
    _place(from);
  }

  void update(double now) {
    if (!_animating) return;
    final t = ((now - _startTime) / _animDuration).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(t);
    _place(_from + (_to - _from) * eased);
    if (t >= 1) {
      _animating = false;
      _setGeometryHeight(_to + _sink); // 最終的な高さの箱に差し替え
      _place(_to);
    }
  }

  void _place(double top) {
    // easeOutBack の行き過ぎで箱の底が台座から出ないようにする
    currentTop = math.min(top, _geometryHeight - _sink);
    node.position = base + vm.Vector3(0, currentTop - _geometryHeight / 2, 0);
  }

  void _setGeometryHeight(double height) {
    if ((height - _geometryHeight).abs() < 1e-4) return;
    _geometryHeight = height;
    node.mesh = Mesh(
      CuboidGeometry(vm.Vector3(_footprint, height, _footprint)),
      material,
    );
  }

  void setHighlighted(bool value) {
    material.emissiveFactor = value
        ? vm.Vector4(color.x, color.y, color.z, 1) * 0.8
        : vm.Vector4(0, 0, 0, 1);
  }
}

class _WorldLabel {
  _WorldLabel(
    this.position,
    this.text, {
    this.alignLeft = false,
    this.emphasized = false,
  });
  final vm.Vector3 Function() position;
  final String text;
  final bool alignLeft;
  final bool emphasized;
}

class _LabelPainter extends CustomPainter {
  _LabelPainter({
    required Listenable repaint,
    required this.scene,
    required this.labels,
  }) : super(repaint: repaint);

  final Scene scene;
  final List<_WorldLabel> labels;

  @override
  void paint(Canvas canvas, Size size) {
    final camera = scene.camera;
    if (camera == null) return;
    for (final label in labels) {
      final p = camera.worldToScreen(label.position(), size);
      if (p == null) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: label.text,
          style: TextStyle(
            color: Colors.white,
            fontSize: label.emphasized ? 15 : 11,
            fontWeight: label.emphasized ? FontWeight.bold : FontWeight.w500,
            shadows: const [Shadow(blurRadius: 3, color: Colors.black87)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = label.alignLeft
          ? Offset(p.dx, p.dy - painter.height / 2)
          : Offset(p.dx - painter.width / 2, p.dy - painter.height / 2);
      if (label.emphasized) {
        final rect = (offset & painter.size).inflate(5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = Colors.black.withValues(alpha: 0.6),
        );
      }
      painter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(_LabelPainter oldDelegate) =>
      oldDelegate.labels != labels;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.datasetIndex,
    required this.onChanged,
    required this.categories,
  });

  final int datasetIndex;
  final ValueChanged<int> onChanged;
  final List<ChartCategory> categories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<int>(
          segments: [
            for (var i = 0; i < sampleDatasets.length; i++)
              ButtonSegment(value: i, label: Text(sampleDatasets[i].title)),
          ],
          selected: {datasetIndex},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            for (final c in categories)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: HSVColor.fromAHSV(1, c.hue, 0.65, 0.9).toColor(),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    c.name,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}
