import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';

import 'csv_download.dart';

class AiDatasetDashboardPage extends StatefulWidget {
  const AiDatasetDashboardPage({super.key});

  @override
  State<AiDatasetDashboardPage> createState() => _AiDatasetDashboardPageState();
}

class _AiDatasetDashboardPageState extends State<AiDatasetDashboardPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _sortBy = 'Newest';
  String _filterCategory = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F6FA),
      appBar: AppBar(
        title: const Text('AI Dataset Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Dataset',
            onPressed: () => _exportDataset(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('ai_dataset').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;
          
          // Stats
          int totalImages = docs.length;
          int totalBytes = 0;
          for(var d in docs) {
            totalBytes += (d['fileSize'] as num?)?.toInt() ?? 0;
          }
          final String storageUsed = _formatBytes(totalBytes);
          final String avgSize = totalImages > 0 ? _formatBytes(totalBytes ~/ totalImages) : '0 B';

          // Filtering
          var filtered = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final searchMatch = _searchQuery.isEmpty || 
                (data['foodName']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                (data['donorName']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                (data['fileName']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                (data['datasetId']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
            
            final categoryMatch = _filterCategory == 'All' || data['category'] == _filterCategory;

            return searchMatch && categoryMatch;
          }).toList();

          // Sorting
          filtered.sort((a, b) {
            final ad = a.data() as Map<String, dynamic>;
            final bd = b.data() as Map<String, dynamic>;
            if (_sortBy == 'Newest') {
              final aTime = ad['uploadTime'] as Timestamp?;
              final bTime = bd['uploadTime'] as Timestamp?;
              return (bTime ?? Timestamp(0,0)).compareTo(aTime ?? Timestamp(0,0));
            } else if (_sortBy == 'Oldest') {
              final aTime = ad['uploadTime'] as Timestamp?;
              final bTime = bd['uploadTime'] as Timestamp?;
              return (aTime ?? Timestamp(0,0)).compareTo(bTime ?? Timestamp(0,0));
            } else if (_sortBy == 'Largest') {
              return (bd['fileSize'] as num? ?? 0).compareTo(ad['fileSize'] as num? ?? 0);
            } else if (_sortBy == 'Smallest') {
              return (ad['fileSize'] as num? ?? 0).compareTo(bd['fileSize'] as num? ?? 0);
            } else if (_sortBy == 'Category') {
              return (ad['category']?.toString() ?? '').compareTo(bd['category']?.toString() ?? '');
            } else {
              return (ad['foodName']?.toString() ?? '').compareTo(bd['foodName']?.toString() ?? '');
            }
          });

          return Column(
            children: [
              // Stats Header
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Total Images', '$totalImages'),
                    _statItem('Storage Used', storageUsed),
                    _statItem('Avg Image Size', avgSize),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Toolbar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search dataset...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _filterCategory,
                      items: ['All', 'cookedMeals', 'fruits', 'vegetables', 'bakery', 'dairy', 'meat', 'beverages', 'other']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _filterCategory = val!),
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _sortBy,
                      items: ['Newest', 'Oldest', 'Largest', 'Smallest', 'Category', 'Alphabetical']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setState(() => _sortBy = val!),
                    ),
                  ],
                ),
              ),
              
              // Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _ImageCard(
                      data: data,
                      onTap: () => _showImageDetails(context, data, doc.reference),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes > 0) ? (bytes.toDouble() / 1024).floor().toString().length ~/ 3 : 0;
    if (i >= suffixes.length) i = suffixes.length - 1;
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _exportDataset(BuildContext context) async {
    final snapshot = await _db.collection('ai_dataset').get();
    
    // Create CSV
    final headers = ['datasetId', 'fileName', 'foodName', 'category', 'donorName', 'downloadUrl', 'storagePath', 'uploadTime', 'expiryDate', 'status'];
    final rows = [headers.join(',')];
    
    for (var doc in snapshot.docs) {
      final d = doc.data();
      final row = headers.map((h) {
        if (h == 'uploadTime' || h == 'expiryDate') {
          return (d[h] as Timestamp?)?.toDate().toIso8601String() ?? '';
        }
        return '"${d[h]?.toString().replaceAll('"', '""') ?? ''}"';
      }).join(',');
      rows.add(row);
    }
    
    final csvContent = rows.join('\n');
    final fileName = 'food_ai_dataset_${DateTime.now().millisecondsSinceEpoch}.csv';

    try {
      final result = await downloadCsvString(csvContent, fileName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dataset exported: $result')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showImageDetails(BuildContext context, Map<String, dynamic> data, DocumentReference docRef) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 800,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Preview
              Expanded(
                flex: 3,
                child: Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    child: Image.network(data['downloadUrl'] ?? '', fit: BoxFit.contain),
                  ),
                ),
              ),
              // Metadata
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['foodName'] ?? 'Unknown', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _metaRow('Dataset ID', data['datasetId']),
                        _metaRow('Filename', data['fileName']),
                        _metaRow('Category', data['category']),
                        _metaRow('Donor', data['donorName']),
                        _metaRow('Size', _formatBytes(data['fileSize'] as int? ?? 0)),
                        _metaRow('Upload Time', (data['uploadTime'] as Timestamp?)?.toDate().toString() ?? ''),
                        const SizedBox(height: 24),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.verified, color: Colors.green),
                              tooltip: 'Verify & Label Image',
                              onPressed: () {
                                Navigator.pop(context);
                                _showVerifyDialog(context, data, docRef);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              tooltip: 'Copy URL',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: data['downloadUrl'] ?? ''));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL Copied')));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete Image permanently',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Delete Dataset Image?'),
                                    content: const Text('This will permanently delete the image from Firebase Storage and remove its metadata. This cannot be undone.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    // Delete Storage
                                    await FirebaseStorage.instance.ref(data['storagePath']).delete();
                                    // Delete Firestore
                                    await docRef.delete();
                                    Navigator.pop(context);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showVerifyDialog(BuildContext context, Map<String, dynamic> data, DocumentReference docRef) {
    final foodTypeCtrl = TextEditingController(text: data['foodType'] ?? data['category'] ?? '');
    String freshness = data['freshnessLabel'] ?? 'fresh';
    double quality = (data['qualityScore'] as num?)?.toDouble() ?? 10.0;
    final notesCtrl = TextEditingController(text: data['notes'] ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: const Text('Verify & Label Image'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: foodTypeCtrl,
                      decoration: const InputDecoration(labelText: 'Food Type / Specific Class'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Freshness Label', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: freshness,
                      isExpanded: true,
                      items: ['fresh', 'acceptable', 'expiring_soon', 'spoiled']
                          .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                          .toList(),
                      onChanged: (v) => setStateSB(() => freshness = v!),
                    ),
                    const SizedBox(height: 16),
                    const Text('Quality Score (0-10)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: quality,
                            min: 0,
                            max: 10,
                            divisions: 10,
                            label: quality.toStringAsFixed(1),
                            onChanged: (v) => setStateSB(() => quality = v),
                          ),
                        ),
                        Text(quality.toStringAsFixed(1)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Admin Notes / Annotations'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  await docRef.update({
                    'foodType': foodTypeCtrl.text.trim(),
                    'freshnessLabel': freshness,
                    'qualityScore': quality,
                    'notes': notesCtrl.text.trim(),
                    'verifiedByHuman': true,
                    'verifiedAt': FieldValue.serverTimestamp(),
                    'isVerified': true,
                  });
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save Labels'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _ImageCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.network(
                data['downloadUrl'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (_,__,___) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['foodName'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['donorName'] ?? 'Anonymous',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(4)),
                        child: Text(data['category'] ?? '', style: TextStyle(color: Colors.indigo.shade700, fontSize: 10)),
                      ),
                      if (data['isVerified'] == true)
                        const Icon(Icons.verified, color: Colors.blue, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
