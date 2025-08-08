import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'plate_matcher.dart';

class WatchlistStore {
  static const _key = 'watchlist_v1';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    return raw.map((e) => normalizePlate(e)).toSet();
  }

  Future<void> save(Set<String> normalizedSet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, normalizedSet.toList()..sort());
  }

  Future<void> add(String plate) async {
    final set = await load();
    set.add(normalizePlate(plate));
    await save(set);
  }

  Future<void> remove(String plate) async {
    final set = await load();
    set.remove(normalizePlate(plate));
    await save(set);
  }

  Future<void> importFromJson(String jsonStr) async {
    final list = (json.decode(jsonStr) as List).cast<String>();
    final set = list.map(normalizePlate).toSet();
    await save(set);
  }

  Future<String> exportToJson() async {
    final set = await load();
    return json.encode(set.toList()..sort());
  }
}
