import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../common/scene_utils.dart';

enum StackPhase { ready, playing, gameOver }

/// 積み木タワーのゲームロジック。シーンとゲームの状態を持つ (Flutter UI 非依存)。
///
/// ブロックが左右 (X 軸 / Z 軸を交互) に往復し、タップで落とす。
/// 下のブロックからはみ出した部分は切り落とされ、落下していく。
class StackTowerGame {
  final Scene scene = Scene();

  /// UI が監視する状態。
  final ValueNotifier<int> score = ValueNotifier(0);
  final ValueNotifier<StackPhase> phase = ValueNotifier(StackPhase.ready);
  final ValueNotifier<int> combo = ValueNotifier(0);

  static const blockHeight = 0.5;
  static const _baseSize = 3.0;
  static const _travel = 4.0; // 往復の振れ幅
  static const _perfectTolerance = 0.1;
  static const _gravity = 18.0;

  late final Node _cameraNode;

  /// 平行投影 (遠近感なし) のカメラ。積みゲーらしい見た目になる。
  /// 縦長でも横長でも幅 11・高さ 14 の範囲が必ず収まる。
  final OrthographicProjection _projection = OrthographicProjection(
    size: const OrthographicSize.contain(11, 14),
  );
  final List<_Block> _stack = [];
  final List<_FallingPiece> _falling = [];
  _Block? _moving;
  double _moveTime = 0;
  double _cameraHeight = 0;
  double _hue = 0;
  final _random = math.Random();

  Future<void> load() async {
    await Scene.initializeStaticResources();
    setGradientSky(
      scene,
      zenith: vm.Vector3(0.20, 0.10, 0.35),
      horizon: vm.Vector3(0.95, 0.55, 0.45),
      ground: vm.Vector3(0.25, 0.12, 0.20),
    );
    addSunLight(scene, from: vm.Vector3(-6, 14, -4), intensity: 3.5);

    _cameraNode = Node(name: 'camera')
      ..addComponent(CameraComponent(
          projection: _projection,
          activateOnMount: true,
        ),
      );
    scene.add(_cameraNode);

    reset();
  }

  /// 盤面を初期状態に戻す。
  void reset() {
    for (final b in _stack) {
      scene.remove(b.node);
    }
    for (final p in _falling) {
      scene.remove(p.node);
    }
    _stack.clear();
    _falling.clear();
    if (_moving != null) scene.remove(_moving!.node);
    _moving = null;

    score.value = 0;
    combo.value = 0;
    _hue = _random.nextDouble() * 360;
    _cameraHeight = 0;

    // 土台 (背の高い柱) と 1 段目
    final pillar = _Block.create(
      size: vm.Vector2(_baseSize, _baseSize),
      height: 8,
      center: vm.Vector3(0, -4 - blockHeight / 2, 0),
      color: hsvToLinear(_hue, 0.25, 0.35),
    );
    scene.add(pillar.node);
    _stack.add(pillar);
    _stack.add(_spawnStatic(vm.Vector2(_baseSize, _baseSize), 0, 0, 0));

    phase.value = StackPhase.ready;
    _updateCamera(1, snap: true);
  }

  _Block _spawnStatic(vm.Vector2 size, double x, double z, int level) {
    final block = _Block.create(
      size: size,
      height: blockHeight,
      center: vm.Vector3(x, level * blockHeight, z),
      color: _colorForLevel(level),
    );
    scene.add(block.node);
    return block;
  }

  vm.Vector4 _colorForLevel(int level) =>
      hsvToLinear(_hue + level * 9, 0.55, 0.95);

  int get _level => _stack.length - 1; // 土台を除いた段数 + 1

  bool get _movesAlongX => _level.isOdd;

  void _spawnMoving() {
    final top = _stack.last;
    final block = _Block.create(
      size: top.size.clone(),
      height: blockHeight,
      center: top.center + vm.Vector3(0, blockHeight, 0),
      color: _colorForLevel(_level),
    );
    _moveTime = 0;
    _moving = block;
    scene.add(block.node);
    _applyMovingPosition();
  }

  double get _speed => 1.6 + math.min(score.value, 30) * 0.05;

  void _applyMovingPosition() {
    final moving = _moving!;
    final top = _stack.last;
    // 三角波で往復 (sin より端での待ちが短く、タイミングを読みやすい)
    final phaseT = (_moveTime * _speed / (2 * _travel)) % 2;
    final offset = (phaseT < 1 ? phaseT : 2 - phaseT) * 2 * _travel - _travel;
    final c = top.center + vm.Vector3(0, blockHeight, 0);
    if (_movesAlongX) {
      c.x = offset;
    } else {
      c.z = offset;
    }
    moving.center = c;
  }

  /// 画面タップ時に呼ぶ。
  void onTap() {
    switch (phase.value) {
      case StackPhase.ready:
        phase.value = StackPhase.playing;
        _spawnMoving();
      case StackPhase.playing:
        _drop();
      case StackPhase.gameOver:
        reset();
    }
  }

  void _drop() {
    final moving = _moving;
    if (moving == null) return;
    final top = _stack.last;
    final axis = _movesAlongX ? 0 : 1; // size の添字: 0 = x, 1 = z
    final delta = _movesAlongX
        ? moving.center.x - top.center.x
        : moving.center.z - top.center.z;
    final topSize = top.size[axis];
    final overlap = topSize - delta.abs();

    if (overlap <= 0) {
      // 完全に外れた: ブロックごと落下してゲームオーバー
      _moving = null;
      _falling.add(_FallingPiece(moving.node, _randomSpin()));
      phase.value = StackPhase.gameOver;
      return;
    }

    scene.remove(moving.node);
    _moving = null;

    if (delta.abs() <= _perfectTolerance) {
      // ぴったり: ずれを吸収してサイズを保つ
      combo.value++;
      final size = top.size.clone();
      // コンボが続くと少しずつ大きくなるご褒美
      if (combo.value >= 3) {
        size[axis] = math.min(_baseSize, size[axis] + 0.15);
      }
      _stack.add(_spawnStatic(size, top.center.x, top.center.z, _level));
    } else {
      combo.value = 0;
      final size = top.size.clone()..[axis] = overlap;
      final keptCenter = top.center.clone();
      final cutCenter = moving.center.clone();
      final dir = delta.sign;
      if (_movesAlongX) {
        keptCenter.x = top.center.x + delta / 2;
        cutCenter.x = keptCenter.x + dir * (overlap / 2 + delta.abs() / 2);
      } else {
        keptCenter.z = top.center.z + delta / 2;
        cutCenter.z = keptCenter.z + dir * (overlap / 2 + delta.abs() / 2);
      }
      _stack.add(_spawnStatic(size, keptCenter.x, keptCenter.z, _level));

      // 切り落とされた部分
      final cutSize = top.size.clone()..[axis] = delta.abs();
      final piece = _Block.create(
        size: cutSize,
        height: blockHeight,
        center: vm.Vector3(cutCenter.x, moving.center.y, cutCenter.z),
        color: moving.color,
      );
      scene.add(piece.node);
      _falling.add(_FallingPiece(piece.node, _randomSpin()));
    }

    score.value++;
    _spawnMoving();
  }

  vm.Vector3 _randomSpin() => vm.Vector3(
    _random.nextDouble() * 4 - 2,
    _random.nextDouble() * 2 - 1,
    _random.nextDouble() * 4 - 2,
  );

  /// SceneView の onTick から毎フレーム呼ぶ。
  void tick(double dt) {
    if (_moving != null && phase.value == StackPhase.playing) {
      _moveTime += dt;
      _applyMovingPosition();
    }

    final floorY = _stack.last.center.y - 20;
    for (final p in _falling.toList()) {
      p.velocity -= _gravity * dt;
      p.node.position += vm.Vector3(0, p.velocity * dt, 0);
      p.node.rotation =
          vm.Quaternion.euler(
            p.spin.y * p.age,
            p.spin.x * p.age,
            p.spin.z * p.age,
          ) *
          p.initialRotation;
      p.age += dt;
      if (p.node.position.y < floorY) {
        scene.remove(p.node);
        _falling.remove(p);
      }
    }

    _updateCamera(dt);
  }

  void _updateCamera(double dt, {bool snap = false}) {
    final targetHeight = _stack.last.center.y;
    // フレームレートに依存しない指数スムージング
    final k = snap ? 1.0 : 1 - math.exp(-4 * dt);
    _cameraHeight += (targetHeight - _cameraHeight) * k;
    final target = vm.Vector3(0, _cameraHeight + 1.5, 0);
    // ゲームオーバー時は引いてタワー全体を見せる (平行投影なので zoom で調整)
    final targetZoom = phase.value == StackPhase.gameOver
        ? 1 / (1.0 + math.min(_stack.length * 0.06, 3.0))
        : 1.0;
    _projection.zoom += (targetZoom - _projection.zoom) * k;
    // 平行投影では距離は見た目に影響しないので、手前で切れないよう遠めに置く
    final eye = target + vm.Vector3(-1, 0.9, -1) * 30;
    _cameraNode.lookAtFrom(eye, target);
  }
}

class _Block {
  _Block._(this.node, this.size, this.color, this._center);

  /// [size] は (x 方向の幅, z 方向の奥行き)。
  factory _Block.create({
    required vm.Vector2 size,
    required double height,
    required vm.Vector3 center,
    required vm.Vector4 color,
  }) {
    final node = Node(
      mesh: Mesh(
        CuboidGeometry(vm.Vector3(size.x, height, size.y)),
        plasticMaterial(color, roughness: 0.4),
      ),
    )..position = center;
    return _Block._(node, size, color, center.clone());
  }

  final Node node;
  final vm.Vector2 size;
  final vm.Vector4 color;
  vm.Vector3 _center;

  vm.Vector3 get center => _center.clone();
  set center(vm.Vector3 value) {
    _center = value.clone();
    node.position = value;
  }
}

class _FallingPiece {
  _FallingPiece(this.node, this.spin) : initialRotation = node.rotation;
  final Node node;
  final vm.Vector3 spin;
  final vm.Quaternion initialRotation;
  double velocity = 0;
  double age = 0;
}
