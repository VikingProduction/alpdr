import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class WatchlistPage extends StatefulWidget {
  const WatchlistPage({super.key});

  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  List<WatchlistEntry> _watchlist = [];
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final List<String> plateList = prefs.getStringList('watchlist') ?? [];
    final List<String> reasonList = prefs.getStringList('watchlist_reasons') ?? [];
    final List<String> dateList = prefs.getStringList('watchlist_dates') ?? [];
    final List<String> alertCountList = prefs.getStringList('watchlist_alert_counts') ?? [];

    setState(() {
      _watchlist = [];
      for (int i = 0; i < plateList.length; i++) {
        _watchlist.add(WatchlistEntry(
          plate: plateList[i],
          reason: i < reasonList.length ? reasonList[i] : 'Non spécifié',
          dateAdded: i < dateList.length 
            ? DateTime.tryParse(dateList[i]) ?? DateTime.now() 
            : DateTime.now(),
          alertCount: i < alertCountList.length 
            ? int.tryParse(alertCountList[i]) ?? 0 
            : 0,
        ));
      }
      _isLoading = false;
    });
  }

  Future<void> _saveWatchlist() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList('watchlist', _watchlist.map((e) => e.plate).toList());
    await prefs.setStringList('watchlist_reasons', _watchlist.map((e) => e.reason).toList());
    await prefs.setStringList('watchlist_dates', _watchlist.map((e) => e.dateAdded.toIso8601String()).toList());
    await prefs.setStringList('watchlist_alert_counts', _watchlist.map((e) => e.alertCount.toString()).toList());
  }

  void _addToWatchlist() {
    String plate = _plateController.text.trim().toUpperCase();
    String reason = _reasonController.text.trim();

    if (plate.isEmpty) {
      _showMessage('Veuillez entrer une plaque d\'immatriculation', isError: true);
      return;
    }

    if (!_isValidLicensePlate(plate)) {
      _showMessage('Format de plaque invalide (ex: AB-123-CD)', isError: true);
      return;
    }

    if (_watchlist.any((entry) => entry.plate == plate)) {
      _showMessage('Cette plaque est déjà dans la watchlist', isError: true);
      return;
    }

    setState(() {
      _watchlist.insert(0, WatchlistEntry(
        plate: plate,
        reason: reason.isEmpty ? 'Non spécifié' : reason,
        dateAdded: DateTime.now(),
        alertCount: 0,
      ));
    });

    _saveWatchlist();
    _plateController.clear();
    _reasonController.clear();

    _showMessage('Plaque $plate ajoutée à la watchlist');
    Navigator.of(context).pop(); // Fermer le dialog
  }

  bool _isValidLicensePlate(String plate) {
    // Format français: AB-123-CD ou 1234-AB-12
    RegExp regExp = RegExp(r'^[A-Z]{2}-?[0-9]{3}-?[A-Z]{2}$|^[0-9]{4}-?[A-Z]{2}-?[0-9]{2}$');
    return regExp.hasMatch(plate);
  }

  void _removeFromWatchlist(WatchlistEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer de la watchlist'),
        content: Text('Êtes-vous sûr de vouloir supprimer la plaque ${entry.plate} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _watchlist.remove(entry);
              });
              _saveWatchlist();
              Navigator.of(context).pop();
              _showMessage('Plaque ${entry.plate} supprimée');
            },
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editEntry(WatchlistEntry entry) {
    _reasonController.text = entry.reason;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier ${entry.plate}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'Motif de surveillance',
                hintText: 'Véhicule suspect, vol, etc.',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                entry.reason = _reasonController.text.trim().isEmpty 
                  ? 'Non spécifié' 
                  : _reasonController.text.trim();
              });
              _saveWatchlist();
              _reasonController.clear();
              Navigator.of(context).pop();
              _showMessage('Motif mis à jour');
            },
            child: Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter à la watchlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _plateController,
              decoration: InputDecoration(
                labelText: 'Plaque d\'immatriculation',
                hintText: 'AB-123-CD',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9-]')),
                LengthLimitingTextInputFormatter(10),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'Motif de surveillance (optionnel)',
                hintText: 'Véhicule suspect, vol, etc.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _plateController.clear();
              _reasonController.clear();
              Navigator.of(context).pop();
            },
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: _addToWatchlist,
            child: Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _importWatchlist() {
    // TODO: Implémenter l'import depuis fichier CSV/JSON
    _showMessage('Import depuis fichier à implémenter');
  }

  void _exportWatchlist() {
    // TODO: Implémenter l'export vers fichier CSV/JSON
    _showMessage('Export vers fichier à implémenter');
  }

  List<WatchlistEntry> get _filteredWatchlist {
    if (_searchQuery.isEmpty) return _watchlist;

    return _watchlist.where((entry) => 
      entry.plate.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      entry.reason.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Watchlist'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.upload_file),
                    SizedBox(width: 8),
                    Text('Importer'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Exporter'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Vider la liste', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _importWatchlist();
                  break;
                case 'export':
                  _exportWatchlist();
                  break;
                case 'clear':
                  _clearWatchlist();
                  break;
              }
            },
          ),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Barre de recherche et statistiques
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher une plaque ou motif...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatCard(
                          title: 'Total',
                          value: _watchlist.length.toString(),
                          color: Colors.blue,
                          icon: Icons.list,
                        ),
                        _StatCard(
                          title: 'Alertes',
                          value: _watchlist.fold(0, (sum, entry) => sum + entry.alertCount).toString(),
                          color: Colors.red,
                          icon: Icons.warning,
                        ),
                        _StatCard(
                          title: 'Récentes',
                          value: _watchlist.where((e) => 
                            DateTime.now().difference(e.dateAdded).inDays < 7
                          ).length.toString(),
                          color: Colors.green,
                          icon: Icons.new_releases,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Liste des plaques
              Expanded(
                child: _filteredWatchlist.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.list_alt, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty 
                              ? 'Aucune plaque dans la watchlist'
                              : 'Aucun résultat trouvé',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _searchQuery.isEmpty
                              ? 'Appuyez sur + pour ajouter une plaque'
                              : 'Essayez un autre terme de recherche',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredWatchlist.length,
                      itemBuilder: (context, index) {
                        final entry = _filteredWatchlist[index];
                        return _WatchlistTile(
                          entry: entry,
                          onEdit: () => _editEntry(entry),
                          onDelete: () => _removeFromWatchlist(entry),
                        );
                      },
                    ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.orange[600],
        child: Icon(Icons.add),
      ),
    );
  }

  void _clearWatchlist() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vider la watchlist'),
        content: Text('Êtes-vous sûr de vouloir supprimer toutes les plaques de la watchlist ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _watchlist.clear());
              _saveWatchlist();
              Navigator.of(context).pop();
              _showMessage('Watchlist vidée');
            },
            child: Text('Vider', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _plateController.dispose();
    _reasonController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class WatchlistEntry {
  String plate;
  String reason;
  DateTime dateAdded;
  int alertCount;

  WatchlistEntry({
    required this.plate,
    required this.reason,
    required this.dateAdded,
    this.alertCount = 0,
  });
}

class _WatchlistTile extends StatelessWidget {
  final WatchlistEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WatchlistTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.alertCount > 0 ? Colors.red : Colors.orange,
          child: entry.alertCount > 0 
            ? Text(entry.alertCount.toString(), style: TextStyle(color: Colors.white))
            : Icon(Icons.directions_car, color: Colors.white),
        ),
        title: Text(
          entry.plate,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.reason,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 4),
            Text(
              'Ajouté le ${_formatDate(entry.dateAdded)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Modifier'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('Supprimer', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
