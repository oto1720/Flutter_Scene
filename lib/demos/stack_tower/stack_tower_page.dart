import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';

import 'stack_tower_game.dart';

/// 積み木タワーの画面。ゲームロジックは [StackTowerGame] に任せ、
/// ここでは表示と入力の受け渡しだけを行う。
class StackTowerPage extends StatefulWidget {
  const StackTowerPage({super.key});

  @override
  State<StackTowerPage> createState() => _StackTowerPageState();
}

class _StackTowerPageState extends State<StackTowerPage> {
  final StackTowerGame _game = StackTowerGame();
  bool _ready = false;
  int _best = 0;

  @override
  void initState() {
    super.initState();
    _game.load().then((_) {
      if (mounted) setState(() => _ready = true);
    });
    _game.phase.addListener(_onPhaseChanged);
  }

  void _onPhaseChanged() {
    if (_game.phase.value == StackPhase.gameOver &&
        _game.score.value > _best) {
      setState(() => _best = _game.score.value);
    }
  }

  @override
  void dispose() {
    _game.phase.removeListener(_onPhaseChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('積み木タワー'),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _game.onTap(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: SceneView(
                      _game.scene,
                      onTick: (elapsed, dt) => _game.tick(dt),
                    ),
                  ),
                  SafeArea(child: _Hud(game: _game, best: _best)),
                ],
              ),
            ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.game, required this.best});
  final StackTowerGame game;
  final int best;

  static const _shadow = [Shadow(blurRadius: 8, color: Colors.black45)];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StackPhase>(
      valueListenable: game.phase,
      builder: (context, phase, _) {
        return Column(
          children: [
            const SizedBox(height: 56),
            ValueListenableBuilder<int>(
              valueListenable: game.score,
              builder: (context, score, _) => Text(
                '$score',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: _shadow,
                ),
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: game.combo,
              builder: (context, combo, _) => AnimatedOpacity(
                opacity: combo >= 2 ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  'PERFECT ×$combo',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.yellowAccent,
                    shadows: _shadow,
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (phase != StackPhase.playing)
              Padding(
                padding: const EdgeInsets.only(bottom: 64),
                child: Column(
                  children: [
                    if (phase == StackPhase.gameOver)
                      const Text(
                        'GAME OVER',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          shadows: _shadow,
                        ),
                      ),
                    if (best > 0)
                      Text(
                        'ベスト: $best',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          shadows: _shadow,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      phase == StackPhase.ready
                          ? 'タップでスタート'
                          : 'タップでもう一度',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        shadows: _shadow,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
