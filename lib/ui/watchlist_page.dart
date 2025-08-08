import 'package:flutter/material.dart';
import '../plate_matcher.dart';
import '../watchlist_store.dart';

class WatchlistPage extends StatefulWidget {
  const WatchlistPage({super.key});

  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  final _store = WatchlistStore();
  Set<String> _items = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final s = await _store.load();
    setState(() {
      _items = s;
      _loading = false;
    });
  }

  Future<void> _addDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajouter une plaque'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Ex: AA-123-AA'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Ajouter')),
        ],
      ),
    );
    if (ok != null && ok.isNotEmpty) {
      await _store.add(ok);
      await _reload();
    }
  }

  Future<void> _importDialog() async {
    final ctrl = TextEditingController(text: '[]');
    final ok = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Importer (JSON)'),
        content: TextField(
          controller: ctrl,
          minLines: 4,
          maxLines: 12,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Importer')),
        ],
      ),
    );
    if (ok != null) {
      await _store.importFromJson(ok);
      await _reload();
    }
  }

  Future<void> _exportDialog() async {
    final json = await _store.exportToJson();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Export (JSON)'),
        content: SelectableText(json),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final list = _items.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Watchlist')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${list.length} plaque(s) enregistrée(s)'),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemBuilder: (_, i) {
                  final p = list[i];
                  return ListTile(
                    title: Text(p),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await _store.remove(p);
                        await _reload();
                      },
                    ),
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: list.length,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(onPressed: _addDialog, icon: const Icon(Icons.add), label: const Text('Ajouter')),
                const SizedBox(width: 8),
                OutlinedButton.icon(onPressed: _importDialog, icon: const Icon(Icons.file_download), label: const Text('Importer')),
                const SizedBox(width: 8),
                OutlinedButton.icon(onPressed: _exportDialog, icon: const Icon(Icons.file_upload), label: const Text('Exporter')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
