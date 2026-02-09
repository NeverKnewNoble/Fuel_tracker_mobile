import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuel_tracker/frappe_API/config.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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
  final TextEditingController fuelDispensedController = TextEditingController();
  final TextEditingController requisitionNumberController = TextEditingController();
  final TextEditingController _fuelTankerController = TextEditingController();
  final TextEditingController _siteController = TextEditingController();
  final TextEditingController _resourceController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();

  String? selectedFuelTanker;
  String? selectedResource;
  String? selectedSite;

  List<String> fuelTankers = [];
  List<String> resources = [];
  List<String> sites = [];

  // Map to store full resource data (type, odometer, hours)
  Map<String, Map<String, dynamic>> _resourceData = {};

  // Selected resource info
  String? _selectedResourceType;
  double _previousOdometer = 0.0;
  double _previousHours = 0.0;

  // Check if selected resource is equipment (uses hours) or truck (uses odometer)
  bool get _usesHours => _selectedResourceType == 'Equipment';

  // Image picker for odometer/hours photo
  final ImagePicker _imagePicker = ImagePicker();
  File? _odometerImage;

  @override
  void dispose() {
    _dateController.dispose();
    fuelDispensedController.dispose();
    requisitionNumberController.dispose();
    _fuelTankerController.dispose();
    _siteController.dispose();
    _resourceController.dispose();
    _odometerController.dispose();
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
    // Recover image if the app was killed while camera was open
    _retrieveLostImage();
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTankers = prefs.getStringList('cachedFuelTankers');
    final cachedRes = prefs.getStringList('cachedResources');
    final cachedSts = prefs.getStringList('cachedSites');

    // Load default settings
    final defaultTanker = prefs.getString('defaultFuelTanker');
    final defaultSite = prefs.getString('defaultSite');

    // Load cached resource data
    await _loadCachedResourceData();

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

  Future<void> _saveCachedResourceData(Map<String, Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(data);
    await prefs.setString('cachedResourceData', jsonString);
  }

  Future<void> _loadCachedResourceData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('cachedResourceData');
    if (jsonString != null) {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      _resourceData = decoded.map((key, value) =>
        MapEntry(key, Map<String, dynamic>.from(value as Map)));
    }
  }

  /// Save form state before opening camera so it can be restored
  /// if Android kills the app while the camera is in the foreground.
  Future<void> _saveFormState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('_formState_date', _dateController.text);
    await prefs.setString('_formState_fuelTanker', _fuelTankerController.text);
    await prefs.setString('_formState_site', _siteController.text);
    await prefs.setString('_formState_resource', _resourceController.text);
    await prefs.setString('_formState_odometer', _odometerController.text);
    await prefs.setString('_formState_fuelDispensed', fuelDispensedController.text);
    await prefs.setString('_formState_requisition', requisitionNumberController.text);
    await prefs.setBool('_formState_cameraOpen', true);
  }

  /// Restore form state after activity recreation.
  Future<void> _restoreFormState() async {
    final prefs = await SharedPreferences.getInstance();
    final wasCameraOpen = prefs.getBool('_formState_cameraOpen') ?? false;
    if (!wasCameraOpen) return;

    final date = prefs.getString('_formState_date');
    final tanker = prefs.getString('_formState_fuelTanker');
    final site = prefs.getString('_formState_site');
    final resource = prefs.getString('_formState_resource');
    final odometer = prefs.getString('_formState_odometer');
    final fuel = prefs.getString('_formState_fuelDispensed');
    final requisition = prefs.getString('_formState_requisition');

    if (mounted) {
      setState(() {
        if (date != null && date.isNotEmpty) _dateController.text = date;
        if (tanker != null && tanker.isNotEmpty) {
          _fuelTankerController.text = tanker;
          selectedFuelTanker = tanker;
        }
        if (site != null && site.isNotEmpty) {
          _siteController.text = site;
          selectedSite = site;
        }
        if (resource != null && resource.isNotEmpty) {
          _resourceController.text = resource;
          selectedResource = resource;
          final data = _resourceData[resource];
          if (data != null) {
            _selectedResourceType = data['resource_type'] as String?;
            _previousOdometer = data['current_odometer'] as double? ?? 0.0;
            _previousHours = data['current_hours'] as double? ?? 0.0;
          }
        }
        if (odometer != null && odometer.isNotEmpty) _odometerController.text = odometer;
        if (fuel != null && fuel.isNotEmpty) fuelDispensedController.text = fuel;
        if (requisition != null && requisition.isNotEmpty) requisitionNumberController.text = requisition;
      });
    }

    // Clear the flag
    await prefs.setBool('_formState_cameraOpen', false);
  }

  /// Recover a lost image after the OS killed the app while the camera was open.
  Future<void> _retrieveLostImage() async {
    try {
      final LostDataResponse response = await _imagePicker.retrieveLostData();
      if (response.isEmpty) return;

      if (response.file != null) {
        // Restore the form fields first
        await _restoreFormState();
        if (mounted) {
          setState(() {
            _odometerImage = File(response.file!.path);
          });
        }
      } else if (response.exception != null) {
        if (kDebugMode) {
          print('Lost image error: ${response.exception}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving lost image: $e');
      }
    }
  }

  Future<void> _showImageSourcePicker() async {
    try {
      // Save form state before launching in case Android kills the app
      await _saveFormState();

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
        maxWidth: 800,
        maxHeight: 800,
      );

      // Clear the camera-open flag since we returned normally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('_formState_cameraOpen', false);

      if (image != null) {
        setState(() {
          _odometerImage = File(image.path);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error picking image: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to capture image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> fetchFuelTankers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('cachedApiKey');
      final apiSecret = prefs.getString('cachedApiSecret');

      final String credentials = '$apiKey:$apiSecret';
      final String encodedCredentials = base64Encode(utf8.encode(credentials));

      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.get_fuel_tankers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $encodedCredentials',
        },
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
        final resourcesData = data['data']['data'] as List;
        final fetchedResources =
            List<String>.from(resourcesData.map((e) => e['name']));

        // Store full resource data (type, odometer, hours)
        final Map<String, Map<String, dynamic>> resourceDataMap = {};
        for (var resource in resourcesData) {
          final name = resource['name'] as String;
          resourceDataMap[name] = {
            'resource_type': resource['resource_type'] ?? '',
            'current_odometer': (resource['current_odometer'] ?? 0).toDouble(),
            'current_hours': (resource['current_hours'] ?? 0).toDouble(),
            'reg_no': resource['reg_no'] ?? '',
          };
        }

        setState(() {
          resources = fetchedResources;
          _resourceData = resourceDataMap;
        });
        await _saveCachedData('cachedResources', fetchedResources);
        await _saveCachedResourceData(resourceDataMap);
        if (kDebugMode) {
          print('Resources fetched: $resources');
          print('Resource data: $_resourceData');
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
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('cachedApiKey');
      final apiSecret = prefs.getString('cachedApiSecret');

      final String credentials = '$apiKey:$apiSecret';
      final String encodedCredentials = base64Encode(utf8.encode(credentials));

      final response = await http.get(
        Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.get_site'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $encodedCredentials',
        },
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
                setState(() {
                  selectedResource = value;
                  final data = _resourceData[value];
                  if (data != null) {
                    _selectedResourceType = data['resource_type'] as String?;
                    _previousOdometer = data['current_odometer'] as double? ?? 0.0;
                    _previousHours = data['current_hours'] as double? ?? 0.0;
                  } else {
                    _selectedResourceType = null;
                    _previousOdometer = 0.0;
                    _previousHours = 0.0;
                  }
                  // Clear the input when switching resources
                  _odometerController.clear();
                });
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
            const SizedBox(height: 6),
            // Show previous odometer or hours based on resource type
            if (selectedResource != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  _usesHours
                      ? 'Previous Hours: ${_previousHours.toStringAsFixed(1)} Hrs'
                      : 'Previous Odometer: ${_previousOdometer.toStringAsFixed(0)} KM',
                  style: const TextStyle(
                    color: Color.fromARGB(255, 247, 43, 43),
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _odometerController,
              label: _usesHours ? 'Current Hours' : 'Current Odometer (KM)',
              hint: _usesHours ? 'Enter current hours reading' : 'Enter current odometer reading',
              icon: _usesHours ? Icons.access_time_outlined : Icons.speed_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _usesHours
                      ? 'Please enter the hours reading'
                      : 'Please enter the odometer reading';
                }
                final currentValue = double.tryParse(value);
                if (currentValue == null) {
                  return 'Please enter a valid number';
                }
                if (_usesHours) {
                  if (currentValue < _previousHours) {
                    return 'Cannot be less than previous (${_previousHours.toStringAsFixed(1)} Hrs)';
                  }
                } else {
                  if (currentValue < _previousOdometer) {
                    return 'Cannot be less than previous (${_previousOdometer.toStringAsFixed(0)} KM)';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildImageCaptureField(),
            const SizedBox(height: 20),
            _buildTextField(
              controller: fuelDispensedController,
              label: 'Fuel Dispensed (LTS)',
              hint: 'Enter fuel dispensed in liters',
              icon: Icons.local_gas_station_outlined,
              keyboardType: TextInputType.number,
              validator: (value) => value == null || value.isEmpty
                  ? 'Please enter the fuel dispensed'
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

  Widget _buildImageCaptureField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _usesHours ? 'Hours Meter Photo' : 'Odometer Photo',
          style: const TextStyle(
            color: Color(0xFF1A237E),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showImageSourcePicker,
          child: Container(
            width: double.infinity,
            height: _odometerImage != null ? 200 : 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: _odometerImage != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          _odometerImage!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          children: [
                            // Retake button
                            GestureDetector(
                              onTap: _showImageSourcePicker,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3949AB),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Remove button
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _odometerImage = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _usesHours
                            ? 'Tap to take photo of hours meter'
                            : 'Tap to take photo of odometer',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '(Required)',
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () async {
          if (_formKey.currentState?.validate() ?? false) {
            // Check if image was captured
            if (_odometerImage == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _usesHours
                        ? 'Please take a photo of the hours meter'
                        : 'Please take a photo of the odometer',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Encode image to base64 now while the file definitely exists
            String base64Image = '';
            String imageFilename = '';
            if (_odometerImage != null && _odometerImage!.existsSync()) {
              final imageBytes = await _odometerImage!.readAsBytes();
              base64Image = base64Encode(imageBytes);
              imageFilename = _odometerImage!.path.split('/').last;
            }

            // Generate a temporary ID - real name comes from Frappe after sync
            final tempId = _generateTempId();

            final newDocument = {
              'name': tempId,
              'date': _dateController.text,
              'fuel_tanker': _fuelTankerController.text,
              'resource': _resourceController.text,
              'site': _siteController.text,
              'resource_type': _selectedResourceType ?? '',
              'odometer_km': _usesHours ? '' : _odometerController.text,
              'hours_copy': _usesHours ? _odometerController.text : '',
              'fuel_used': fuelDispensedController.text,
              'requisition_number': requisitionNumberController.text,
              'odometer_image': base64Image,
              'odometer_image_filename': imageFilename,
              'status': 'Pending',
            };

            if (!mounted) return;
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
