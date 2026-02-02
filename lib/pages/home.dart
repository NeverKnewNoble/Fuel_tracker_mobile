import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuel_tracker/frappe_API/config.dart';
import 'package:fuel_tracker/pages/fuel_info.dart';
import 'package:fuel_tracker/pages/fuel_used.dart';
import 'package:fuel_tracker/pages/login.dart';
import 'package:fuel_tracker/pages/settings.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _isDrawerOpen = false;

  int documentCount = 0;
  List<Map<String, String>> documents = [];

  Map<String, dynamic> lastSuccessfulResponse = {};

  static const String _documentsKey = 'saved_documents';

  // Fuel stats
  double _fuelDispensedToday = 0.0;
  double? _fuelBalance;
  bool _isLoadingBalance = false;
  String? _defaultSite;
  String? _defaultTanker;
  String _lastCalculatedDate = '';

  // Animation controllers for reload buttons
  late AnimationController _syncAnimationController;
  late AnimationController _balanceRefreshAnimationController;
  late Animation<double> _syncRotationAnimation;
  late Animation<double> _balanceRotationAnimation;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize animation controllers
    _syncAnimationController = AnimationController(
      duration: const Duration(milliseconds: 5000), // Increased duration
      vsync: this,
    );
    _balanceRefreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 5000), // Increased duration
      vsync: this,
    );

    // Create rotation animations
    _syncRotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _syncAnimationController,
      curve: Curves.linear,
    ));

    _balanceRotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _balanceRefreshAnimationController,
      curve: Curves.linear,
    ));

    _loadDocuments();
    _loadDefaultSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncAnimationController.dispose();
    _balanceRefreshAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check if the day has changed when app comes to foreground
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (_lastCalculatedDate != today) {
        _calculateFuelDispensedToday();
        _fetchFuelBalance();
      }
    }
  }

  Future<void> _loadDefaultSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultSite = prefs.getString('defaultSite');
    _defaultTanker = prefs.getString('defaultFuelTanker');
    _fetchFuelBalance();
  }

  Future<void> _calculateFuelDispensedToday() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  
    // Try to fetch from API first
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('cachedApiKey');
      final apiSecret = prefs.getString('cachedApiSecret');

      if (apiKey != null && apiSecret != null) {
        final String credentials = '$apiKey:$apiSecret';
        final String encodedCredentials = base64Encode(utf8.encode(credentials));

        final response = await http.get(
          Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.user_dispensed_today'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Basic $encodedCredentials',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          if (responseData['data']['status'] == 'success') {
            final totalDispensed = responseData['data']['total_dispensed_today'] ?? 0;
            setState(() {
              _fuelDispensedToday = double.tryParse(totalDispensed.toString()) ?? 0.0;
              _lastCalculatedDate = today;
            });
            
            // Save the API result as fallback
            await prefs.setDouble('lastApiFuelDispensed', _fuelDispensedToday);
            await prefs.setString('lastApiDate', today);
            
            if (kDebugMode) {
              print('Fuel dispensed from API: $_fuelDispensedToday L');
            }
            return;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to fetch fuel dispensed from API: $e');
      }
    }

    // Fallback to local calculation if API fails
    double total = 0.0;
    for (var doc in documents) {
      if (doc['date'] == today) {
        final fuelUsed = double.tryParse(doc['fuel_used'] ?? '0') ?? 0.0;
        total += fuelUsed;
      }
    }
    
    setState(() {
      _fuelDispensedToday = total;
      _lastCalculatedDate = today;
    });
    
    if (kDebugMode) {
      print('Fuel dispensed from local storage: $_fuelDispensedToday L');
    }
  }

  Future<void> _fetchFuelBalance() async {
    if (_defaultSite == null || _defaultTanker == null) {
      setState(() {
        _fuelBalance = null;
        _isLoadingBalance = false;
      });
      return;
    }

    setState(() {
      _isLoadingBalance = true;
    });
    _balanceRefreshAnimationController.repeat();

    // Add minimum delay to ensure animation is visible
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('cachedApiKey');
      final apiSecret = prefs.getString('cachedApiSecret');

      if (apiKey == null || apiSecret == null) {
        throw Exception('API keys not found');
      }

      // final String credentials = '$apiKey:$apiSecret';
      // final String encodedCredentials = base64Encode(utf8.encode(credentials));

      final response = await http.post(
        Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.dashboard.fuelBalance'),
        headers: {
          'Content-Type': 'application/json',
          // 'Authorization': 'Basic $encodedCredentials',
        },
        body: jsonEncode({
          'site': _defaultSite,
          'fuel_tanker': _defaultTanker,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final balance = data['data'];
        _balanceRefreshAnimationController.stop();
        _balanceRefreshAnimationController.reset();
        setState(() {
          _fuelBalance = balance != null ? double.tryParse(balance.toString()) : null;
          _isLoadingBalance = false;
        });
      } else {
        _balanceRefreshAnimationController.stop();
        _balanceRefreshAnimationController.reset();
        setState(() {
          _fuelBalance = null;
          _isLoadingBalance = false;
        });
        if (kDebugMode) {
          print('Failed to fetch fuel balance: ${response.statusCode}');
        }
      }
    } catch (e) {
      _balanceRefreshAnimationController.stop();
      _balanceRefreshAnimationController.reset();
      setState(() {
        _fuelBalance = null;
        _isLoadingBalance = false;
      });
      if (kDebugMode) {
        print('Error fetching fuel balance: $e');
      }
    }
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
    
    // Fetch user documents from server and merge with local
    await _fetchUserDocumentsFromServer();
    _calculateFuelDispensedToday();
  }

  Future<void> _saveDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final documentsJson = documents.map((doc) => jsonEncode(doc)).toList();
    await prefs.setStringList(_documentsKey, documentsJson);
  }

  Future<void> _fetchUserDocumentsFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('cachedApiKey');
      final apiSecret = prefs.getString('cachedApiSecret');

      if (apiKey == null || apiSecret == null) {
        if (kDebugMode) {
          print('API keys not found, skipping server document fetch');
        }
        return;
      }

      final String credentials = '$apiKey:$apiSecret';
      final String encodedCredentials = base64Encode(utf8.encode(credentials));

      final response = await http.get(
        Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.get_user_fuel_used_documents'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $encodedCredentials',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['data']['status'] == 'success') {
          final serverDocs = responseData['data']['data'] as List;
          
          // Convert server documents to local format
          final List<Map<String, String>> serverDocuments = serverDocs.map((doc) {
            return {
              'name': doc['name']?.toString() ?? '',
              'date': doc['creation']?.toString().split(' ')[0] ?? '', // Extract date from creation timestamp
              'fuel_tanker': doc['fuel_tanker']?.toString() ?? '',
              'resource': doc['resource']?.toString() ?? '',
              'site': doc['site']?.toString() ?? '',
              'current_odometer': doc['odometer_km']?.toString() ?? '',
              'fuel_used': doc['fuel_used']?.toString() ?? '',
              'requisition_number': doc['requisition_number']?.toString() ?? '',
              'status': 'Sent', // Server documents are always synced
            };
          }).toList();

          // Merge server documents with local documents
          _mergeServerDocuments(serverDocuments);
        }
      } else {
        if (kDebugMode) {
          print('Failed to fetch user documents: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user documents from server: $e');
      }
    }
  }

  void _mergeServerDocuments(List<Map<String, String>> serverDocuments) {
    // Create a set of existing document names for quick lookup
    final Set<String> existingDocNames = documents.map((doc) => doc['name'] ?? '').toSet();
    
    // Add server documents that don't exist locally
    final List<Map<String, String>> newDocs = [];
    for (var serverDoc in serverDocuments) {
      final docName = serverDoc['name'] ?? '';
      if (docName.isNotEmpty && !existingDocNames.contains(docName)) {
        newDocs.add(serverDoc);
        existingDocNames.add(docName);
      }
    }

    if (newDocs.isNotEmpty) {
      setState(() {
        documents.addAll(newDocs);
        documentCount = documents.length;
      });
      _saveDocuments();
      
      if (kDebugMode) {
        print('Added ${newDocs.length} new documents from server');
      }
    }
  }

  void _addNewDocument(Map<String, String?> document) {
    setState(() {
      documents.add({
        'name': document['name'] ?? '',
        'date': document['date'] ?? '',
        'fuel_tanker': document['fuel_tanker'] ?? '',
        'resource': document['resource'] ?? '',
        'site': document['site'] ?? '',
        'current_odometer': document['current_odometer'] ?? '',
        'fuel_used': document['fuel_used'] ?? '',
        'requisition_number': document['requisition_number'] ?? '',
        'status': 'Stored, please press sync icon',
      });
      documentCount++;
    });
    _calculateFuelDispensedToday();
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
          'odometer_km': document['current_odometer'] ?? '',
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

  Future<void> _retryAllPosts() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });
    _syncAnimationController.repeat();

    // Add minimum delay to ensure animation is visible
    await Future.delayed(const Duration(milliseconds: 500));

    final pendingDocs = documents
        .where((d) => d['status'] == 'Stored, please press sync icon')
        .toList();

    for (var document in pendingDocs) {
      await _postDocumentToServer(document);
    }

    _syncAnimationController.stop();
    _syncAnimationController.reset();
    setState(() {
      _isSyncing = false;
    });
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
                  icon: RotationTransition(
                    turns: _syncRotationAnimation,
                    child: const Icon(Icons.sync, color: Colors.white),
                  ),
                  onPressed: _isSyncing ? null : () {
                    // Debug test for animation
                    if (kDebugMode) {
                      print('Sync button pressed - starting animation');
                      _syncAnimationController.repeat();
                      Future.delayed(const Duration(seconds: 3), () {
                        _syncAnimationController.stop();
                        _syncAnimationController.reset();
                        print('Animation stopped');
                      });
                    }
                    _retryAllPosts();
                  },
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
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                    // Refresh defaults and fuel balance after returning from settings
                    _loadDefaultSettings();
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
          Row(
            children: [
              Expanded(child: _buildFuelDispensedTodayCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildFuelBalanceCard()),
            ],
          ),
          const SizedBox(height: 16),
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

  Widget _buildFuelDispensedTodayCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_gas_station,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const Spacer(),
              Text(
                'Today',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_fuelDispensedToday.toStringAsFixed(1)} L',
            style: const TextStyle(
              color: Color(0xFF1A237E),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fuel Dispensed',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelBalanceCard() {
    final hasDefaults = _defaultSite != null && _defaultTanker != null;

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _isLoadingBalance ? null : _fetchFuelBalance,
                child: RotationTransition(
                  turns: _balanceRotationAnimation,
                  child: Icon(
                    Icons.refresh,
                    color: _isLoadingBalance
                        ? const Color(0xFF3949AB)
                        : Colors.grey.shade400,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasDefaults)
            Text(
              'Set defaults',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            )
          else if (_fuelBalance != null)
            Text(
              '${_fuelBalance!.toStringAsFixed(1)} L',
              style: const TextStyle(
                color: Color(0xFF1A237E),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              '--',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Fuel Balance',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    int sentCount = documents.where((d) => d['status'] == 'Sent').length;
    int pendingCount = documents.where((d) => d['status'] != 'Sent').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3949AB),
            Color(0xFF5C6BC0),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3949AB).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                documentCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Total Entries',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$sentCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.pending, color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$pendingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
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

    // Each document item is approximately 76px height (including margin)
    // Show 4 documents then scroll
    const double itemHeight = 76.0;
    const int visibleItems = 4;
    final double maxHeight = itemHeight * visibleItems + 16; // +16 for padding

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            // Show most recent first (reverse order)
            final reversedIndex = documents.length - 1 - index;
            return _buildDocumentItem(context, reversedIndex);
          },
        ),
      ),
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
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade100,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isTempDocument
                        ? Colors.orange.withValues(alpha: 0.1)
                        : const Color(0xFF3949AB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isTempDocument
                        ? Icons.hourglass_empty
                        : Icons.description_outlined,
                    color: isTempDocument
                        ? Colors.orange
                        : const Color(0xFF3949AB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isTempDocument
                              ? Colors.orange.shade700
                              : const Color(0xFF1A237E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            document['date'] ?? 'No date',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(statusIcon, color: statusColor, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            status == 'Stored, please press sync icon'
                                ? 'Pending'
                                : status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (status != 'Sent')
                  GestureDetector(
                    onTap: () => _retryPost(document),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3949AB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.sync,
                        color: Color(0xFF3949AB),
                        size: 18,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
