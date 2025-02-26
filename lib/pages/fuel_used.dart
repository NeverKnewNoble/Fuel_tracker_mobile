import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuel_tracker/frappe_API/config.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FuelUsedPage extends StatefulWidget {
  const FuelUsedPage({super.key, required String documentName});

  @override
  State<FuelUsedPage> createState() => _FuelUsedPageState();
}

class _FuelUsedPageState extends State<FuelUsedPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController fuelUsedController = TextEditingController();
  final TextEditingController requisitionNumberController = TextEditingController();

  String? selectedFuelTanker;
  String? selectedResource;
  String? selectedSite;

  List<String> fuelTankers = [];
  List<String> resources = [];
  List<String> sites = [];

  // Persistent cache for offline usage
  static List<String> cachedFuelTankers = [];
  static List<String> cachedResources = [];
  static List<String> cachedSites = [];
  static String cachedLatestDocumentName = 'FU-00001';

  @override
  void initState() {
    super.initState();
    fetchFuelTankers();
    fetchResources();
    fetchSites();
  }

  Future<void> fetchFuelTankers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.get_fuel_tankers'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data']['status'] == 'success') {
          setState(() {
            fuelTankers = List<String>.from(data['data']['data'].map((e) => e['name']));
            cachedFuelTankers = List<String>.from(fuelTankers); // Cache the response
          });
          if (kDebugMode) {
            print('Fuel Tankers fetched: $fuelTankers');
          }
        }
      } else {
        // Use cached data if request fails
        setState(() {
          fuelTankers = List<String>.from(cachedFuelTankers);
        });
        if (kDebugMode) {
          print('Failed to fetch Fuel Tankers. Status Code: ${response.statusCode}');
        }
      }
    } catch (e) {
      setState(() {
        fuelTankers = List<String>.from(cachedFuelTankers);
      });
      if (kDebugMode) {
        print('Error fetching Fuel Tankers: $e');
      }
    }
  }

  Future<void> fetchResources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('cachedApiKey');
      final apiSecret = prefs.getString('cachedApiSecret');

      // Combine them in the usual username:password format for Basic auth:
      final String credentials = '$apiKey:$apiSecret';

      // Now base64-encode the credentials:
      final String encodedCredentials = base64Encode(utf8.encode(credentials));
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.get_filtered_items'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $encodedCredentials',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resourcesData = data['data']['data'];
        setState(() {
          resources = List<String>.from(resourcesData.map((e) => e['item_name']));
          cachedResources = List<String>.from(resources); // Cache the response
        });
        if (kDebugMode) {
          print('Resources fetched: $resources');
        }
      } else {
        // Use cached data if request fails
        setState(() {
          resources = List<String>.from(cachedResources);
        });
        if (kDebugMode) {
          print('Failed to fetch Resources. Status Code: ${response.statusCode}');
          print('Response Body: ${response.body}');
        }
      }
    } catch (e) {
      setState(() {
        resources = List<String>.from(cachedResources);
      });
      if (kDebugMode) {
        print('Error fetching Resources: $e');
      }
    }
  }

  Future<void> fetchSites() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.get_site'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data']['status'] == 'success') {
          setState(() {
            sites = List<String>.from(data['data']['data'].map((e) => e['site_name']));
            cachedSites = List<String>.from(sites); // Cache the response
          });
          if (kDebugMode) {
            print('Sites fetched: $sites');
          }
        }
      } else {
        // Use cached data if request fails
        setState(() {
          sites = List<String>.from(cachedSites);
        });
        if (kDebugMode) {
          print('Failed to fetch Sites. Status Code: ${response.statusCode}');
        }
      }
    } catch (e) {
      setState(() {
        sites = List<String>.from(cachedSites);
      });
      if (kDebugMode) {
        print('Error fetching Sites: $e');
      }
    }
  }

  Future<String> getLatestDocumentName() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.fuel_list'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data']['status'] == 'success') {
          final documents = data['data']['data'];
          if (documents.isNotEmpty) {
            // Extract the numeric part of the document names and find the maximum
            final latestDocument = documents
                .map((doc) => int.parse(doc['name'].split('-')[1]))
                .reduce((a, b) => a > b ? a : b);

            cachedLatestDocumentName = 'FU-${(latestDocument + 1).toString().padLeft(5, '0')}';
            return cachedLatestDocumentName;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching latest document name: $e');
      }
    }

    // Use cached data if request fails
    return cachedLatestDocumentName;
  }

  Future<void> createFuelUsedDocument(Map<String, dynamic> document) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('cachedApiKey');
      final apiSecret = prefs.getString('cachedApiSecret');

      final response = await http.post(
        Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.create_fuel_used'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $apiKey:$apiSecret',
        },
        body: jsonEncode(document),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data']['status'] == 'success') {
          final docName = data['data']['docname'];
          if (kDebugMode) {
            print('Document created successfully: $docName');
          }
        }
      } else {
        if (kDebugMode) {
          print('Failed to create document. Status Code: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating document: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Fuel Used Today', style: TextStyle(fontWeight: FontWeight.bold)),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dateController,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    hintText: 'Select date',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today, color: Colors.blue),
                      onPressed: () async {
                        DateTime? selectedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (selectedDate != null) {
                          _dateController.text = DateFormat('yyyy-MM-dd').format(selectedDate);
                        }
                      },
                    ),
                  ),
                  readOnly: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a date';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedFuelTanker,
                  decoration: const InputDecoration(
                    labelText: 'Fuel Tanker',
                    border: OutlineInputBorder(),
                  ),
                  items: fuelTankers
                      .map((tanker) => DropdownMenuItem(
                            value: tanker,
                            child: Text(tanker),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedFuelTanker = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a fuel tanker';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedResource,
                  decoration: const InputDecoration(
                    labelText: 'Resource',
                    border: OutlineInputBorder(),
                  ),
                  items: resources
                      .map((resource) => DropdownMenuItem(
                            value: resource,
                            child: Text(resource),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedResource = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a resource';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedSite,
                  decoration: const InputDecoration(
                    labelText: 'Site',
                    border: OutlineInputBorder(),
                  ),
                  items: sites
                      .map((site) => DropdownMenuItem(
                            value: site,
                            child: Text(site),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSite = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a site';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: fuelUsedController,
                  decoration: const InputDecoration(
                    labelText: 'Fuel Used (LTS)',
                    hintText: 'Enter fuel used in liters',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the fuel used';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: requisitionNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Requisition Number',
                    hintText: 'Enter requisition number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the requisition number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        final newDocumentName = await getLatestDocumentName();

                        final newDocument = {
                          'name': newDocumentName,
                          'date': _dateController.text,
                          'fuel_tanker': selectedFuelTanker,
                          'resource': selectedResource,
                          'site': selectedSite,
                          'fuel_used': fuelUsedController.text,
                          'requisition_number': requisitionNumberController.text,
                          'status': 'Pending',
                        };

                        await createFuelUsedDocument(newDocument);

                        Navigator.pop(context, newDocument);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}