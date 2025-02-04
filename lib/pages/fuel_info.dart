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
  final TextEditingController requisitionNumberController = TextEditingController();
  final TextEditingController fuelTankerController = TextEditingController();
  final TextEditingController resourceController = TextEditingController();
  final TextEditingController siteController = TextEditingController();

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

      // Combine them in the usual username:password format for Basic auth:
      final String credentials = '$apiKey:$apiSecret';

      // Now base64-encode the credentials:
      final String encodedCredentials = base64Encode(utf8.encode(credentials));

      final url = Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.get_all_fuel_used_records');
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
          });
        }
      } else {
        if (kDebugMode) {
          print('Failed to fetch document data: ${response.body}');
        }
      }
    } catch (e) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Fuel Used Details', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildReadOnlyField(_dateController, 'Date'),
                buildReadOnlyField(fuelTankerController, 'Fuel Tanker'),
                buildReadOnlyField(resourceController, 'Resource'),
                buildReadOnlyField(siteController, 'Site'),
                buildReadOnlyField(fuelUsedController, 'Fuel Used (LTS)'),
                buildReadOnlyField(requisitionNumberController, 'Requisition Number'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildReadOnlyField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Icon(Icons.lock_outline, color: Colors.grey),
        ),
        readOnly: true,  // Makes the field read-only
      ),
    );
  }
}
