\
import 'dart:math';

String normalizePlate(String input) {
  final up = input.toUpperCase();
  final cleaned = up.replaceAll(RegExp(r"[\s\-·\.]+"), "");
  return cleaned;
}

final List<RegExp> kPlatePatterns = [
  RegExp(r"\b([A-Z]{2})[- ]?(\d{3})[- ]?([A-Z]{2})\b"), // FR
  RegExp(r"\b(\d{4})[- ]?([A-Z]{3})\b"),                // ES
  RegExp(r"\b([A-Z]{2})[- ]?(\d{3})[- ]?([A-Z]{2})\b"), // IT-like
  RegExp(r"\b(\d{4})[- ]?([A-Z]{1,2})\b"),              // AD approx
  RegExp(r"\b([A-Z]{2})[- ]?(\d{2})[- ]?([A-Z]{2})\b"), // PT
  RegExp(r"\b([A-Z0-9]{6,8})\b"),                        // fallback
];

Set<String> extractPlateCandidates(String text) {
  final up = text.toUpperCase();
  final found = <String>{};
  for (final rx in kPlatePatterns) {
    for (final m in rx.allMatches(up)) {
      final raw = m.group(0)!;
      found.add(normalizePlate(raw));
    }
  }
  return found;
}

int _levenshtein(String a, String b) {
  final m = a.length, n = b.length;
  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = 0; i <= m; i++) dp[i][0] = i;
  for (var j = 0; j <= n; j++) dp[0][j] = j;
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      dp[i][j] = [
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost,
      ].reduce(min);
    }
  }
  return dp[m][n];
}

List<String> matchAgainstWatchlist(Iterable<String> candidates, Set<String> normalizedWatchlist) {
  final hits = <String>[];
  for (final c in candidates) {
    if (normalizedWatchlist.contains(c)) {
      hits.add(c);
      continue;
    }
    for (final w in normalizedWatchlist) {
      if ((c.length - w.length).abs() <= 1 && _levenshtein(c, w) <= 1) {
        hits.add(c);
        break;
      }
    }
  }
  return hits;
}
