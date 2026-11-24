# Flutter Scene Lab

[flutter_scene](https://pub.dev/packages/flutter_scene) を使った 3D 表現のデモ集です。

| デモ | 内容 |
|---|---|
| 3D 棒グラフ | 月 × カテゴリの売上を立体で表示。ドラッグで回転、ピンチでズーム、棒をタップすると値を表示。データセットを切り替えると棒が伸び縮みする |
| 積み木タワー | 往復するブロックをタップで落として積み上げるミニゲーム。はみ出した部分は切り落とされて落ちる。ぴったり重ねるとコンボ |

## 動かし方

- Flutter 3.47 (stable) 以上
- iOS では `ios/Runner/Info.plist` の `FLTEnableFlutterGPU` で Flutter GPU を有効にしています

```sh
flutter pub get
flutter run --enable-flutter-gpu

# デモを直接開く
flutter run --enable-flutter-gpu --dart-define=DEMO=bar_chart
flutter run --enable-flutter-gpu --dart-define=DEMO=stack_tower
```

## 構成

```
lib/
  main.dart                     デモ一覧
  common/scene_utils.dart       色変換・マテリアル・ライト・空の共通処理
  demos/bar_chart/              3D 棒グラフ
  demos/stack_tower/            積み木タワー (ゲームロジックは stack_tower_game.dart)
hook/build.dart                 flutter_scene のアセット変換 (dart run flutter_scene:init で生成)
.claude/skills/                 flutter_scene 同梱のコーディングエージェント向けスキル
```


https://github.com/user-attachments/assets/079889e2-f7d3-42ec-9248-5eabb08344fa

