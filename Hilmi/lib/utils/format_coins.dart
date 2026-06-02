/// 金币展示：≥100,000 用 k，≥1,000,000 用 m；未满 10 万显示完整数字。
String formatCompactCoins(int coins) {
  if (coins < 0) return '0';
  if (coins >= 1000000) {
    return _compactUnit(coins / 1000000, 'm');
  }
  if (coins >= 100000) {
    return _compactUnit(coins / 1000, 'k');
  }
  return '$coins';
}

String _compactUnit(double value, String suffix) {
  if (value >= 100) {
    return '${value.round()}$suffix';
  }
  final text = value.toStringAsFixed(1);
  if (text.endsWith('.0')) {
    return '${text.substring(0, text.length - 2)}$suffix';
  }
  return '$text$suffix';
}
