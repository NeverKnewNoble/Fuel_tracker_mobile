import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuel_tracker/frappe_API/config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FuelInfoPage extends StatefulWidget {
  final String documentName;

  const FuelInfoPage({super.key, required this.documentName});

  @override
  State<FuelInfoPage> createState() => _FuelInfoPageState();
}

class _FuelInfoPageState extends State<FuelInfoPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController fuelUsedController = TextEditingController();
  final TextEditingController requisitionNumberController =
      TextEditingController();
  final TextEditingController fuelTankerController = TextEditingController();
  final TextEditingController resourceController = TextEditingController();
  final TextEditingController siteController = TextEditingController();
  final TextEditingController odometerController = TextEditingController();
  final TextEditingController hoursController = TextEditingController();

  bool _isLoading = true;
  String _resourceType = '';

  @override
  void initState() {
    super.initState();
    _fetchDocumentData();
  }

  Future<void> _fetchDocumentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('cachedApiKey');
      final apiSecret = prefs.getString('cachedApiSecret');

      final String credentials = '$apiKey:$apiSecret';
      final String encodedCredentials = base64Encode(utf8.encode(credentials));

      final url = Uri.parse(
          '$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.get_all_fuel_used_records');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Basic $encodedCredentials',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final document = (responseData['data'] as List).firstWhere(
          (doc) => doc['name'] == widget.documentName,
          orElse: () => null,
        );

        if (document != null) {
          setState(() {
            _populateFormFields(document);
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        if (kDebugMode) {
          print('Failed to fetch document data: ${response.body}');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Error fetching document data: $e');
      }
    }
  }

  void _populateFormFields(Map<String, dynamic> document) {
    _dateController.text = document['date'] ?? '';
    fuelTankerController.text = document['fuel_tanker'] ?? '';
    resourceController.text = document['resource'] ?? '';
    siteController.text = document['site'] ?? '';
    fuelUsedController.text = document['fuel_issued_lts']?.toString() ?? '';
    requisitionNumberController.text = document['requisition_number'] ?? '';
    odometerController.text = document['odometer_km']?.toString() ?? '';
    hoursController.text = document['hours_copy']?.toString() ?? '';
    _resourceType = document['resource_type']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Column(
            children: [
              _buildAppBar(context),
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
                    child: _isLoading ? _buildLoadingState() : _buildContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.documentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fuel entry details',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3949AB)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading details...',
            style: TextStyle(
              color: Color(0xFF3949AB),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: _dateController.text,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              icon: Icons.local_shipping_outlined,
              label: 'Fuel Tanker',
              value: fuelTankerController.text,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              icon: Icons.build_outlined,
              label: 'Resource',
              value: resourceController.text,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              icon: Icons.location_on_outlined,
              label: 'Site',
              value: siteController.text,
            ),
            const SizedBox(height: 16),
            // Show odometer or hours based on resource type
            if (_resourceType == 'Equipment' && hoursController.text.isNotEmpty)
              _buildInfoCard(
                icon: Icons.access_time_outlined,
                label: 'Hours',
                value: hoursController.text,
              )
            else if (odometerController.text.isNotEmpty)
              _buildInfoCard(
                icon: Icons.speed_outlined,
                label: 'Odometer (KM)',
                value: odometerController.text,
              ),
            if ((_resourceType == 'Equipment' && hoursController.text.isNotEmpty) ||
                odometerController.text.isNotEmpty)
              const SizedBox(height: 16),
            _buildInfoCard(
              icon: Icons.local_gas_station_outlined,
              label: 'Fuel Used (LTS)',
              value: fuelUsedController.text,
              highlight: true,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              icon: Icons.numbers_outlined,
              label: 'Requisition Number',
              value: requisitionNumberController.text,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF3949AB).withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? const Color(0xFF3949AB).withValues(alpha: 0.3)
              : Colors.grey.shade200,
          width: highlight ? 2 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: const Color(0xFF3949AB).withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: highlight
                  ? const Color(0xFF3949AB).withValues(alpha: 0.15)
                  : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF3949AB),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Not specified' : value,
                  style: TextStyle(
                    color: value.isEmpty
                        ? Colors.grey.shade400
                        : const Color(0xFF1A237E),
                    fontSize: 16,
                    fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (highlight)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF3949AB),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'LTS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
