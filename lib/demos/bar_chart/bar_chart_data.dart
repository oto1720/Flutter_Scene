import 'dart:math' as math;

/// 3D 棒グラフ用のサンプルデータ: 月 × カテゴリの売上 (万円)。
class ChartDataset {
  const ChartDataset({
    required this.title,
    required this.months,
    required this.categories,
    required this.values,
  });

  final String title;
  final List<String> months;
  final List<ChartCategory> categories;

  /// values[month][category]
  final List<List<double>> values;

  double get maxValue =>
      values.expand((row) => row).fold(0.0, (a, b) => math.max(a, b));
}

class ChartCategory {
  const ChartCategory(this.name, this.hue);
  final String name;

  /// 表示色の色相 (度数)。
  final double hue;
}

const _months = [
  '1月', '2月', '3月', '4月', '5月', '6月', //
  '7月', '8月', '9月', '10月', '11月', '12月',
];

const _categories = [
  ChartCategory('ドリンク', 200),
  ChartCategory('フード', 30),
  ChartCategory('スイーツ', 330),
  ChartCategory('グッズ', 140),
];

/// 季節の傾向を持たせた、再現可能な疑似データを作る。
ChartDataset _generate(String title, int seed, double growth) {
  final rand = math.Random(seed);
  final values = List.generate(_months.length, (m) {
    final season = math.sin((m - 3) / 12 * 2 * math.pi); // 夏にピーク
    return List.generate(_categories.length, (c) {
      final base = switch (c) {
        0 => 40 + 35 * season, // ドリンクは夏に強い
        1 => 55 + 10 * season,
        2 => 35 - 15 * season + (m == 1 || m == 11 ? 30 : 0), // 2月・12月
        _ => 20 + (m == 11 ? 25 : 0) + 3 * m,
      };
      final noise = rand.nextDouble() * 12 - 6;
      return math.max(2.0, (base + noise) * growth);
    });
  });
  return ChartDataset(
    title: title,
    months: _months,
    categories: _categories,
    values: values,
  );
}

final sampleDatasets = [
  _generate('2025年 売上', 2025, 1.0),
  _generate('2026年 売上', 2026, 1.18),
];
