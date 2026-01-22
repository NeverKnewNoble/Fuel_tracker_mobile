import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuel_tracker/frappe_API/config.dart';
import 'package:fuel_tracker/pages/fuel_info.dart';
import 'package:fuel_tracker/pages/fuel_used.dart';
import 'package:fuel_tracker/pages/login.dart';
import 'package:fuel_tracker/pages/settings.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  bool _isDrawerOpen = false;

  int documentCount = 0;
  List<Map<String, String>> documents = [];

  Map<String, dynamic> lastSuccessfulResponse = {};

  static const String _documentsKey = 'saved_documents';

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDocuments = prefs.getStringList(_documentsKey);

    if (savedDocuments != null) {
      setState(() {
        documents = savedDocuments
            .map((doc) => Map<String, String>.from(jsonDecode(doc)))
            .toList();
        documentCount = documents.length;
      });
    }
  }

  Future<void> _saveDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final documentsJson = documents.map((doc) => jsonEncode(doc)).toList();
    await prefs.setStringList(_documentsKey, documentsJson);
  }

  void _addNewDocument(Map<String, String?> document) {
    setState(() {
      documents.add({
        'name': document['name'] ?? '',
        'date': document['date'] ?? '',
        'fuel_tanker': document['fuel_tanker'] ?? '',
        'resource': document['resource'] ?? '',
        'site': document['site'] ?? '',
        'fuel_used': document['fuel_used'] ?? '',
        'requisition_number': document['requisition_number'] ?? '',
        'status': 'Stored, please press sync icon',
      });
      documentCount++;
    });
    _saveDocuments();
    _postDocumentToServer(documents.last);
  }

  Future<void> _postDocumentToServer(Map<String, String> document) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('cachedApiKey');
      final apiSecret = prefs.getString('cachedApiSecret');

      if (apiKey == null || apiSecret == null) {
        throw Exception('API keys not found');
      }

      final String credentials = '$apiKey:$apiSecret';
      final String encodedCredentials = base64Encode(utf8.encode(credentials));

      final url = Uri.parse(
          '$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.fuel_used');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $encodedCredentials',
        },
        body: jsonEncode({
          'date': document['date'] ?? '',
          'fuel_tanker': document['fuel_tanker'] ?? '',
          'resource': document['resource'] ?? '',
          'site': document['site'] ?? '',
          'fuel_used': document['fuel_used'] ?? '',
          'requisition_number': document['requisition_number'] ?? '',
        }),
      );

      if (kDebugMode) {
        print('Response Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body)['data'];
        if (responseData['status'] == 'success') {
          setState(() {
            // Update the document name with Frappe's assigned name
            final frappeDocName = responseData['docname'];
            if (frappeDocName != null) {
              document['name'] = frappeDocName;
            }
            document['status'] = 'Sent';
          });
          lastSuccessfulResponse = responseData;
          _saveDocuments();
        } else {
          setState(() {
            document['status'] = 'Failed';
          });
          _saveDocuments();
        }
      } else {
        _handleFailedRequest(document);
      }
    } catch (e) {
      _handleFailedRequest(document);
      if (kDebugMode) {
        print('Error occurred during POST request: $e');
      }
    }
  }

  void _handleFailedRequest(Map<String, String> document) {
    setState(() {
      document['status'] = 'Stored, please press sync icon';
    });
    _saveDocuments();
  }

  void _retryPost(Map<String, String> document) {
    _postDocumentToServer(document);
  }

  void _retryAllPosts() async {
    for (var document in documents) {
      if (document['status'] == 'Stored, please press sync icon') {
        _retryPost(document);
      }
    }
  }

  // Helper to check if a document has a temporary ID
  bool _isTempId(String name) {
    return name.startsWith('TEMP-');
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A237E),
              Color(0xFF3949AB),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                        child: _buildMainContent(context),
                      ),
                    ),
                  ),
                ],
              ),
              if (_isDrawerOpen)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isDrawerOpen = false;
                    });
                  },
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newDocument = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    const FuelUsedPage(documentName: '')),
          );
          if (newDocument != null) {
            _addNewDocument(newDocument);
          }
        },
        backgroundColor: const Color(0xFF3949AB),
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Entry',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track your fuel entries',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.sync, color: Colors.white),
                  onPressed: _retryAllPosts,
                  tooltip: 'Sync all entries',
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                  tooltip: 'Settings',
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: _logout,
                  tooltip: 'Logout',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildWideLayout(context);
      },
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCard(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Entries',
                style: TextStyle(
                  color: Color(0xFF1A237E),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${documents.length} total',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDocumentsList(),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    int sentCount = documents.where((d) => d['status'] == 'Sent').length;
    int pendingCount = documents.where((d) => d['status'] != 'Sent').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3949AB),
            Color(0xFF5C6BC0),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3949AB).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Fuel Entries',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_gas_station_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            documentCount.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatChip(
                icon: Icons.check_circle_outline,
                label: 'Sent',
                count: sentCount,
                color: Colors.greenAccent,
              ),
              const SizedBox(width: 16),
              _buildStatChip(
                icon: Icons.pending_outlined,
                label: 'Pending',
                count: pendingCount,
                color: Colors.orangeAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList() {
    if (documents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 60,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No entries yet',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to add your first fuel entry',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        return _buildDocumentItem(context, index);
      },
    );
  }

  Widget _buildDocumentItem(BuildContext context, int index) {
    final document = documents[index];
    final status = document['status']!;
    final docName = document['name']!;
    final isTempDocument = _isTempId(docName);

    Color statusColor;
    IconData statusIcon;
    if (status == 'Sent') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status == 'Failed') {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
    }

    // Display name: show "Pending sync..." for temp IDs, otherwise show real name
    final displayName = isTempDocument ? 'Pending sync...' : docName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isTempDocument
              ? null // Disable tap for temp documents
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FuelInfoPage(documentName: docName),
                    ),
                  );
                },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isTempDocument
                        ? Colors.orange.withValues(alpha: 0.1)
                        : const Color(0xFF3949AB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isTempDocument
                        ? Icons.hourglass_empty
                        : Icons.description_outlined,
                    color: isTempDocument
                        ? Colors.orange
                        : const Color(0xFF3949AB),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isTempDocument
                              ? Colors.orange.shade700
                              : const Color(0xFF1A237E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        document['date'] ?? 'No date',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            status == 'Stored, please press sync icon'
                                ? 'Tap sync to upload'
                                : status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (status != 'Sent')
                  IconButton(
                    onPressed: () => _retryPost(document),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3949AB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.sync,
                        color: Color(0xFF3949AB),
                        size: 20,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
