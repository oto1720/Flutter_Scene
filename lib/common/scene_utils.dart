import 'dart:math' as math;

import 'package:flutter/painting.dart' show HSVColor;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// sRGB (0〜1) の色を、マテリアルが期待するリニアな RGBA に変換する。
vm.Vector4 srgbToLinear(double r, double g, double b, [double a = 1]) {
  double lin(double c) => math.pow(c, 2.2).toDouble();
  return vm.Vector4(lin(r), lin(g), lin(b), a);
}

/// HSV からリニアな RGBA を作る。hue は度数 (0〜360)。
vm.Vector4 hsvToLinear(double hue, double saturation, double value) {
  final c = HSVColor.fromAHSV(1, hue % 360, saturation, value).toColor();
  return srgbToLinear(c.r, c.g, c.b);
}

/// 樹脂っぽい見た目の PBR マテリアル。
///
/// `PhysicallyBasedMaterial` の metallic の初期値は 1.0 (金属) なので、
/// 明示的に 0 にしておく。
PhysicallyBasedMaterial plasticMaterial(
  vm.Vector4 linearColor, {
  double roughness = 0.45,
}) {
  return PhysicallyBasedMaterial()
    ..baseColorFactor = linearColor
    ..metallicFactor = 0.0
    ..roughnessFactor = roughness;
}

/// 影を落とす平行光源を [from] から原点方向へ向けてシーンに追加する。
Node addSunLight(Scene scene, {vm.Vector3? from, double intensity = 3.0}) {
  final light = DirectionalLight(intensity: intensity, castsShadow: true);
  final node = Node(name: 'sun')
    ..addComponent(DirectionalLightComponent(light))
    ..lookAtFrom(from ?? vm.Vector3(-4, 10, -6), vm.Vector3.zero());
  scene.add(node);
  return node;
}

/// 背景のグラデーション空を設定する。
void setGradientSky(
  Scene scene, {
  required vm.Vector3 zenith,
  required vm.Vector3 horizon,
  vm.Vector3? ground,
}) {
  scene.skybox = Skybox(
    GradientSkySource(
      zenithColor: zenith,
      horizonColor: horizon,
      groundColor: ground ?? horizon,
      sunColor: vm.Vector3.zero(),
    ),
  );
}
