import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuel_tracker/frappe_API/config.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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
  final TextEditingController requisitionNumberController =
      TextEditingController();
  final TextEditingController _fuelTankerController = TextEditingController();
  final TextEditingController _siteController = TextEditingController();
  final TextEditingController _resourceController = TextEditingController();

  String? selectedFuelTanker;
  String? selectedResource;
  String? selectedSite;

  List<String> fuelTankers = [];
  List<String> resources = [];
  List<String> sites = [];

  @override
  void dispose() {
    _dateController.dispose();
    fuelUsedController.dispose();
    requisitionNumberController.dispose();
    _fuelTankerController.dispose();
    _siteController.dispose();
    _resourceController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Set current date by default
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadCachedData().then((_) {
      fetchFuelTankers();
      fetchResources();
      fetchSites();
    });
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTankers = prefs.getStringList('cachedFuelTankers');
    final cachedRes = prefs.getStringList('cachedResources');
    final cachedSts = prefs.getStringList('cachedSites');

    // Load default settings
    final defaultTanker = prefs.getString('defaultFuelTanker');
    final defaultSite = prefs.getString('defaultSite');

    if (mounted) {
      setState(() {
        if (cachedTankers != null && cachedTankers.isNotEmpty) {
          fuelTankers = cachedTankers;
          // Set default tanker if it exists in the list
          if (defaultTanker != null && cachedTankers.contains(defaultTanker)) {
            selectedFuelTanker = defaultTanker;
            _fuelTankerController.text = defaultTanker;
          }
        }
        if (cachedRes != null && cachedRes.isNotEmpty) {
          resources = cachedRes;
        }
        if (cachedSts != null && cachedSts.isNotEmpty) {
          sites = cachedSts;
          // Set default site if it exists in the list
          if (defaultSite != null && cachedSts.contains(defaultSite)) {
            selectedSite = defaultSite;
            _siteController.text = defaultSite;
          }
        }
      });
    }
  }

  Future<void> _saveCachedData(String key, List<String> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, data);
  }

  Future<void> fetchFuelTankers() async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.get_fuel_tankers'),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data']['status'] == 'success') {
          final fetchedTankers =
              List<String>.from(data['data']['data'].map((e) => e['name']));
          final prefs = await SharedPreferences.getInstance();
          final defaultTanker = prefs.getString('defaultFuelTanker');
          setState(() {
            fuelTankers = fetchedTankers;
            // Apply default if not already selected
            if (selectedFuelTanker == null && defaultTanker != null && fetchedTankers.contains(defaultTanker)) {
              selectedFuelTanker = defaultTanker;
              _fuelTankerController.text = defaultTanker;
            }
          });
          await _saveCachedData('cachedFuelTankers', fetchedTankers);
          if (kDebugMode) {
            print('Fuel Tankers fetched: $fuelTankers');
          }
        }
      } else {
        if (kDebugMode) {
          print(
              'Failed to fetch Fuel Tankers. Status Code: ${response.statusCode}');
        }
      }
    } catch (e) {
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

      final String credentials = '$apiKey:$apiSecret';
      final String encodedCredentials = base64Encode(utf8.encode(credentials));

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.get_filtered_items'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $encodedCredentials',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resourcesData = data['data']['data'];
        final fetchedResources =
            List<String>.from(resourcesData.map((e) => e['item_name']));
        setState(() {
          resources = fetchedResources;
        });
        await _saveCachedData('cachedResources', fetchedResources);
        if (kDebugMode) {
          print('Resources fetched: $resources');
        }
      } else {
        if (kDebugMode) {
          print('Failed to fetch Resources. Status Code: ${response.statusCode}');
          print('Response Body: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching Resources: $e');
      }
    }
  }

  Future<void> fetchSites() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.get_site'),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data']['status'] == 'success') {
          final fetchedSites = List<String>.from(
              data['data']['data'].map((e) => e['site_name']));
          final prefs = await SharedPreferences.getInstance();
          final defaultSite = prefs.getString('defaultSite');
          setState(() {
            sites = fetchedSites;
            // Apply default if not already selected
            if (selectedSite == null && defaultSite != null && fetchedSites.contains(defaultSite)) {
              selectedSite = defaultSite;
              _siteController.text = defaultSite;
            }
          });
          await _saveCachedData('cachedSites', fetchedSites);
          if (kDebugMode) {
            print('Sites fetched: $sites');
          }
        }
      } else {
        if (kDebugMode) {
          print('Failed to fetch Sites. Status Code: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching Sites: $e');
      }
    }
  }

  // Generate a temporary ID for offline/pending documents
  String _generateTempId() {
    return 'TEMP-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      resizeToAvoidBottomInset: true,
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
                    child: _buildForm(),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Fuel Entry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Fill in the details below',
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

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateField(),
            const SizedBox(height: 20),
            _buildAutocompleteField(
              label: 'Fuel Tanker',
              hint: 'Type to search tankers...',
              icon: Icons.local_shipping_outlined,
              controller: _fuelTankerController,
              items: fuelTankers,
              onSelected: (value) {
                setState(() => selectedFuelTanker = value);
                _fuelTankerController.text = value;
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a fuel tanker';
                }
                if (!fuelTankers.contains(value)) {
                  return 'Please select a valid fuel tanker';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildAutocompleteField(
              label: 'Site',
              hint: 'Type to search sites...',
              icon: Icons.location_on_outlined,
              controller: _siteController,
              items: sites,
              onSelected: (value) {
                setState(() => selectedSite = value);
                _siteController.text = value;
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a site';
                }
                if (!sites.contains(value)) {
                  return 'Please select a valid site';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildAutocompleteField(
              label: 'Resource',
              hint: 'Type to search resources...',
              icon: Icons.build_outlined,
              controller: _resourceController,
              items: resources,
              onSelected: (value) {
                setState(() => selectedResource = value);
                _resourceController.text = value;
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a resource';
                }
                if (!resources.contains(value)) {
                  return 'Please select a valid resource';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: fuelUsedController,
              label: 'Fuel Used (LTS)',
              hint: 'Enter fuel used in liters',
              icon: Icons.local_gas_station_outlined,
              keyboardType: TextInputType.number,
              validator: (value) => value == null || value.isEmpty
                  ? 'Please enter the fuel used'
                  : null,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: requisitionNumberController,
              label: 'Requisition Number',
              hint: 'Enter requisition number',
              icon: Icons.numbers_outlined,
              validator: (value) => value == null || value.isEmpty
                  ? 'Please enter the requisition number'
                  : null,
            ),
            const SizedBox(height: 32),
            _buildSubmitButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date',
          style: TextStyle(
            color: Color(0xFF1A237E),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _dateController,
          decoration: InputDecoration(
            hintText: 'Select date',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: const Icon(
              Icons.calendar_today_outlined,
              color: Color(0xFF3949AB),
              size: 22,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.edit_calendar, color: Color(0xFF3949AB)),
              onPressed: () async {
                DateTime? selectedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xFF3949AB),
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: Color(0xFF1A237E),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (selectedDate != null) {
                  _dateController.text =
                      DateFormat('yyyy-MM-dd').format(selectedDate);
                }
              },
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF3949AB), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.red.shade300),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          readOnly: true,
          validator: (value) =>
              value == null || value.isEmpty ? 'Please select a date' : null,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1A237E)),
        ),
      ],
    );
  }

  Widget _buildAutocompleteField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required List<String> items,
    required void Function(String) onSelected,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1A237E),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return items;
            }
            return items.where((item) =>
                item.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          onSelected: onSelected,
          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
            // Sync the external controller with autocomplete's internal controller
            if (controller.text.isNotEmpty && textController.text.isEmpty) {
              textController.text = controller.text;
            }
            controller.addListener(() {
              if (controller.text != textController.text) {
                textController.text = controller.text;
              }
            });
            return TextFormField(
              controller: textController,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(icon, color: const Color(0xFF3949AB), size: 22),
                suffixIcon: textController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 20),
                        onPressed: () {
                          textController.clear();
                          controller.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF3949AB), width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.red.shade300),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: validator,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1A237E)),
              onChanged: (value) {
                controller.text = value;
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(14),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 200,
                    maxWidth: MediaQuery.of(context).size.width - 40,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: index < options.length - 1
                                ? Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  )
                                : null,
                          ),
                          child: Text(
                            option,
                            style: const TextStyle(
                              color: Color(0xFF1A237E),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1A237E),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF3949AB), size: 22),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF3949AB), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.red.shade300),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1A237E)),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState?.validate() ?? false) {
            // Generate a temporary ID - real name comes from Frappe after sync
            final tempId = _generateTempId();

            final newDocument = {
              'name': tempId,
              'date': _dateController.text,
              'fuel_tanker': _fuelTankerController.text,
              'resource': _resourceController.text,
              'site': _siteController.text,
              'fuel_used': fuelUsedController.text,
              'requisition_number': requisitionNumberController.text,
              'status': 'Pending',
            };

            // Don't call createFuelUsedDocument here - home.dart will handle syncing
            Navigator.pop(context, newDocument);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3949AB),
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0xFF3949AB).withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 22),
            SizedBox(width: 10),
            Text(
              'Submit Entry',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
