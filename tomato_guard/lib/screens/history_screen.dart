import 'package:flutter/material.dart';
import '../models/scan_record.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/history_card.dart';
import '../widgets/section_header.dart';
import 'classification_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScanRecord> _scans = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  Future<void> _loadScans() async {
    setState(() => _isLoading = true);
    final results = await DatabaseService.searchScans(_searchQuery);
    if (mounted) {
      setState(() {
        _scans = results;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _loadScans();
  }

  Future<void> _deleteScan(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Scan Record'),
        content: const Text('Are you sure you want to remove this scan from your history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.deleteScan(id);
      _loadScans();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scan record deleted'),
            backgroundColor: AppTheme.primaryDark,
          ),
        );
      }
    }
  }

  Future<void> _clearAllHistory() async {
    if (_scans.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Entire History'),
        content: const Text('This will delete all saved scan records. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.clearAllScans();
      _loadScans();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scan history cleared'),
            backgroundColor: AppTheme.primaryDark,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int ladaCount = _scans.where((s) => s.isEnhancedByLada).length;

    return Scaffold(
      backgroundColor: AppTheme.softBackground,
      appBar: AppBar(
        title: const Text('Detection History'),
        actions: [
          if (_scans.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear All History',
              onPressed: _clearAllHistory,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Stats Header
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                children: [
                  // Search Input
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by disease name or severity...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryDark),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.softBackground,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Stats Pill Banner
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBadge(
                          icon: Icons.history,
                          label: 'Total Scans',
                          value: '${_scans.length}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatBadge(
                          icon: Icons.auto_awesome,
                          label: 'LADA Enhanced',
                          value: '$ladaCount',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Scan List Body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryDark),
                      ),
                    )
                  : _scans.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _scans.length,
                          itemBuilder: (context, index) {
                            final scan = _scans[index];
                            return Dismissible(
                              key: Key('scan_${scan.id ?? index}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.only(right: 20),
                                alignment: Alignment.centerRight,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Swipe to Delete',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.delete_forever,
                                        color: Colors.white, size: 24),
                                  ],
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                if (scan.id != null) {
                                  return await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Scan Record'),
                                          content: const Text(
                                              'Are you sure you want to remove this scan from your history?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.redAccent),
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;
                                }
                                return false;
                              },
                              onDismissed: (direction) {
                                if (scan.id != null) {
                                  DatabaseService.deleteScan(scan.id!);
                                  setState(() {
                                    _scans.removeAt(index);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Scan record deleted'),
                                      backgroundColor: AppTheme.primaryDark,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              child: HistoryCard(
                                record: scan,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ClassificationScreen(
                                        diseaseResult: scan.toDiseaseResult(),
                                      ),
                                    ),
                                  );
                                },
                                onDelete: () {
                                  if (scan.id != null) {
                                    _deleteScan(scan.id!);
                                  }
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentMint.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryDark, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.content_paste_search_rounded,
                color: AppTheme.primaryDark,
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Scan History Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scans you classify will automatically be saved to your local database history.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
