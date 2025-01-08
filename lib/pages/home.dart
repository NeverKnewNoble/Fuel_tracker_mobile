import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuel_tracker/frappe_API/config.dart';
import 'package:fuel_tracker/pages/fuel_used.dart';
import 'package:fuel_tracker/pages/login.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  bool _isDrawerOpen = false;

  // State variables to hold fetched data
  int documentCount = 0;
  List<Map<String, String>> documents = [];

  // In-memory cache for storing the last successful API response
  Map<String, dynamic> lastSuccessfulResponse = {};

  @override
  void initState() {
    super.initState();
    documentCount = documents.length; // Initialize document count
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
        'status': document['status'] ?? 'Pending',
      });
      documentCount++;
    });
    _postDocumentToServer(documents.last);
  }

  Future<void> _postDocumentToServer(Map<String, String> document) async {
    try {
      final url = Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.fuel_used');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode(apiKeyApiSecret))}',
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
            document['status'] = 'Sent';
          });
          // Cache the response for future use
          lastSuccessfulResponse = responseData;
        } else {
          setState(() {
            document['status'] = 'Failed';
          });
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
      document['status'] = 'Failed';
    });

    if (lastSuccessfulResponse.isNotEmpty) {
      if (kDebugMode) {
        print('Using cached response for the failed request: $lastSuccessfulResponse');
      }
      // Process the cached response
      setState(() {
        document['status'] = 'Sent (from cache)';
      });
    }
  }

  void _retryPost(Map<String, String> document) {
    setState(() {
      document['status'] = 'Pending';
    });
    _postDocumentToServer(document);
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: Colors.blue,
            onPressed: () {
              _logout();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: _buildMainContent(context),
          ),
          if (_isDrawerOpen)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isDrawerOpen = false;
                });
              },
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newDocument = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FuelUsedPage()),
          );
          if (newDocument != null) {
            _addNewDocument(newDocument);
          }
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return _buildWideLayout(context);
        } else {
          return _buildWideLayout(context);
        }
      },
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCard(context, 'Documents Created', documentCount.toString()),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Documents',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: documents.isEmpty
                  ? const Center(
                      child: Text(
                        'No documents created yet.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: documents.length,
                      itemBuilder: (context, index) {
                        return _buildDocumentItem(context, index);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, String description) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        color: Colors.blue,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                description,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 40,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentItem(BuildContext context, int index) {
    final document = documents[index];
    final status = document['status']!;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.description, color: Colors.blue, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document['name']!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Created: ${document['date']}',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: $status',
                  style: TextStyle(
                    color: status == 'Failed'
                        ? Colors.red
                        : status == 'Sent'
                            ? Colors.green
                            : Colors.orange,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (status == 'Failed')
            ElevatedButton(
              onPressed: () => _retryPost(document),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
