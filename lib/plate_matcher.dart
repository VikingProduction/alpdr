\
    import 'dart:math';

    /// Normalisation simple: majuscules, suppression espaces/traits/points.
    String normalizePlate(String input) {
      final up = input.toUpperCase();
      final cleaned = up.replaceAll(RegExp(r"[\s\-·\.]+"), "");
      return cleaned;
    }

    /// Quelques regex usuelles (Europe). On teste dans l’ordre, puis fallback générique.
    final List<RegExp> kPlatePatterns = [
      // France format SIV: AA-123-AA
      RegExp(r"\b([A-Z]{2})[- ]?(\d{3})[- ]?([A-Z]{2})\b"),
      // Espagne: 1234 ABC
      RegExp(r"\b(\d{4})[- ]?([A-Z]{3})\b"),
      // Italie (ex): AA 123 AA (assez proche FR)
      RegExp(r"\b([A-Z]{2})[- ]?(\d{3})[- ]?([A-Z]{2})\b"),
      // Andorre (approx.): 1234 A / 1234 AB
      RegExp(r"\b(\d{4})[- ]?([A-Z]{1,2})\b"),
      // Portugal (ex): AA-00-AA / 00-AA-00 (variantes)
      RegExp(r"\b([A-Z]{2})[- ]?(\d{2})[- ]?([A-Z]{2})\b"),
      // Fallback générique: 6 à 8 caractères alphanum
      RegExp(r"\b([A-Z0-9]{6,8})\b"),
    ];

    /// Extraction de candidats plausibles depuis un bloc de texte OCR.
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

    /// Distance de Levenshtein pour tolérance d’une petite erreur OCR.
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

    /// Matches exacts ou “proches” (distance <= 1) contre la watchlist normalisée.
    List<String> matchAgainstWatchlist(Iterable<String> candidates, Set<String> normalizedWatchlist) {
      final hits = <String>[];
      for (final c in candidates) {
        if (normalizedWatchlist.contains(c)) {
          hits.add(c);
          continue;
        }
        // tolérance légère
        for (final w in normalizedWatchlist) {
          if ((c.length - w.length).abs() <= 1 && _levenshtein(c, w) <= 1) {
            hits.add(c);
            break;
          }
        }
      }
      return hits;
    }
