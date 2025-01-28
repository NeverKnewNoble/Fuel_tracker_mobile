// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:fuel_tracker/frappe_API/config.dart';
// import 'package:intl/intl.dart';
// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class FuelInfoPage extends StatefulWidget {
//   final String documentName; // Add this parameter

//   const FuelInfoPage({super.key, required this.documentName});

//   @override
//   State<FuelInfoPage> createState() => _FuelInfoPageState();
// }

// class _FuelInfoPageState extends State<FuelInfoPage> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController _dateController = TextEditingController();
//   final TextEditingController fuelUsedController = TextEditingController();
//   final TextEditingController requisitionNumberController = TextEditingController();

//   String? selectedFuelTanker;
//   String? selectedResource;
//   String? selectedSite;

//   List<String> fuelTankers = [];
//   List<String> resources = [];
//   List<String> sites = [];

//   Map<String, dynamic>? documentData; // To store the fetched document data

//   @override
//   void initState() {
//     super.initState();
//     _fetchDocumentData(); // Fetch document data when the page loads
//   }

//   Future<void> _fetchDocumentData() async {
//     try {
//       final url = Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.get_all_fuel_used_records');
//       final response = await http.get(
//         url,
//         headers: {
//           'Authorization': 'Basic ${base64Encode(utf8.encode(apiKeyApiSecret))}',
//         },
//       );

//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body);
//         final document = (responseData['data'] as List).firstWhere(
//           (doc) => doc['name'] == widget.documentName,
//           orElse: () => null,
//         );

//         if (document != null) {
//           setState(() {
//             documentData = document;
//             _populateFormFields(document); // Populate form fields with fetched data
//           });
//         }
//       } else {
//         if (kDebugMode) {
//           print('Failed to fetch document data: ${response.body}');
//         }
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error fetching document data: $e');
//       }
//     }
//   }


//   void _populateFormFields(Map<String, dynamic> document) {
//     _dateController.text = document['date'] ?? '';
//     selectedFuelTanker = document['fuel_tanker'] ?? '';
//     selectedResource = document['resource'] ?? '';
//     selectedSite = document['site'] ?? '';
//     fuelUsedController.text = document['fuel_issued_lts']?.toString() ?? '';
//     requisitionNumberController.text = document['requisition_number'] ?? '';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         title: const Text('Fuel Used Today', style: TextStyle(fontWeight: FontWeight.bold)),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: _dateController,
//                   decoration: InputDecoration(
//                     labelText: 'Date',
//                     hintText: 'Select date',
//                     border: const OutlineInputBorder(),
//                     suffixIcon: IconButton(
//                       icon: const Icon(Icons.calendar_today, color: Colors.blue),
//                       onPressed: () async {
//                         DateTime? selectedDate = await showDatePicker(
//                           context: context,
//                           initialDate: DateTime.now(),
//                           firstDate: DateTime(2000),
//                           lastDate: DateTime(2100),
//                         );
//                         if (selectedDate != null) {
//                           _dateController.text = DateFormat('yyyy-MM-dd').format(selectedDate);
//                         }
//                       },
//                     ),
//                   ),
//                   readOnly: true,
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please select a date';
//                     }
//                     return null;
//                   },
//                 ),
//                 const SizedBox(height: 16),
//                 DropdownButtonFormField<String>(
//                   value: selectedFuelTanker,
//                   decoration: const InputDecoration(
//                     labelText: 'Fuel Tanker',
//                     border: OutlineInputBorder(),
//                   ),
//                   items: fuelTankers
//                       .map((tanker) => DropdownMenuItem(
//                             value: tanker,
//                             child: Text(tanker),
//                           ))
//                       .toList(),
//                   onChanged: (value) {
//                     setState(() {
//                       selectedFuelTanker = value;
//                     });
//                   },
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please select a fuel tanker';
//                     }
//                     return null;
//                   },
//                 ),
//                 const SizedBox(height: 16),
//                 DropdownButtonFormField<String>(
//                   value: selectedResource,
//                   decoration: const InputDecoration(
//                     labelText: 'Resource',
//                     border: OutlineInputBorder(),
//                   ),
//                   items: resources
//                       .map((resource) => DropdownMenuItem(
//                             value: resource,
//                             child: Text(resource),
//                           ))
//                       .toList(),
//                   onChanged: (value) {
//                     setState(() {
//                       selectedResource = value;
//                     });
//                   },
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please select a resource';
//                     }
//                     return null;
//                   },
//                 ),
//                 const SizedBox(height: 16),
//                 DropdownButtonFormField<String>(
//                   value: selectedSite,
//                   decoration: const InputDecoration(
//                     labelText: 'Site',
//                     border: OutlineInputBorder(),
//                   ),
//                   items: sites
//                       .map((site) => DropdownMenuItem(
//                             value: site,
//                             child: Text(site),
//                           ))
//                       .toList(),
//                   onChanged: (value) {
//                     setState(() {
//                       selectedSite = value;
//                     });
//                   },
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please select a site';
//                     }
//                     return null;
//                   },
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: fuelUsedController,
//                   decoration: const InputDecoration(
//                     labelText: 'Fuel Used (LTS)',
//                     hintText: 'Enter fuel used in liters',
//                     border: OutlineInputBorder(),
//                   ),
//                   keyboardType: TextInputType.number,
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter the fuel used';
//                     }
//                     return null;
//                   },
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: requisitionNumberController,
//                   decoration: const InputDecoration(
//                     labelText: 'Requisition Number',
//                     hintText: 'Enter requisition number',
//                     border: OutlineInputBorder(),
//                   ),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter the requisition number';
//                     }
//                     return null;
//                   },
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }







// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:fuel_tracker/frappe_API/config.dart';
// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class FuelInfoPage extends StatefulWidget {
//   final String documentName;

//   const FuelInfoPage({super.key, required this.documentName});

//   @override
//   State<FuelInfoPage> createState() => _FuelInfoPageState();
// }

// class _FuelInfoPageState extends State<FuelInfoPage> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
//   final TextEditingController _dateController = TextEditingController();
//   final TextEditingController fuelUsedController = TextEditingController();
//   final TextEditingController requisitionNumberController = TextEditingController();

//   String? selectedFuelTanker;
//   String? selectedResource;
//   String? selectedSite;

//   List<String> fuelTankers = [];
//   List<String> resources = [];
//   List<String> sites = [];

//   Map<String, dynamic>? documentData;

//   @override
//   void initState() {
//     super.initState();
//     _fetchDocumentData();
//   }

//   Future<void> _fetchDocumentData() async {
//     try {
//       final url = Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.get_all_fuel_used_records');
//       final response = await http.get(
//         url,
//         headers: {
//           'Authorization': 'Basic ${base64Encode(utf8.encode(apiKeyApiSecret))}',
//         },
//       );

//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body);
//         final document = (responseData['data'] as List).firstWhere(
//           (doc) => doc['name'] == widget.documentName,
//           orElse: () => null,
//         );

//         if (document != null) {
//           setState(() {
//             documentData = document;
//             _populateFormFields(document);
//           });
//         }
//       } else {
//         if (kDebugMode) {
//           print('Failed to fetch document data: ${response.body}');
//         }
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error fetching document data: $e');
//       }
//     }
//   }

//   void _populateFormFields(Map<String, dynamic> document) {
//     _dateController.text = document['date'] ?? '';
//     selectedFuelTanker = document['fuel_tanker'];
//     selectedResource = document['resource'];
//     selectedSite = document['site'];
//     fuelUsedController.text = document['fuel_issued_lts']?.toString() ?? '';
//     requisitionNumberController.text = document['requisition_number'] ?? '';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         title: const Text('Fuel Used Details', style: TextStyle(fontWeight: FontWeight.bold)),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 buildReadOnlyField(_dateController, 'Date'),
//                 buildReadOnlyDropdown(selectedFuelTanker, 'Fuel Tanker', fuelTankers),
//                 buildReadOnlyDropdown(selectedResource, 'Resource', resources),
//                 buildReadOnlyDropdown(selectedSite, 'Site', sites),
//                 buildReadOnlyField(fuelUsedController, 'Fuel Used (LTS)'),
//                 buildReadOnlyField(requisitionNumberController, 'Requisition Number'),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget buildReadOnlyField(TextEditingController controller, String label) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 16),
//       child: TextFormField(
//         controller: controller,
//         decoration: InputDecoration(
//           labelText: label,
//           border: const OutlineInputBorder(),
//           suffixIcon: Icon(Icons.lock_outline, color: Colors.grey),
//         ),
//         readOnly: true,
//       ),
//     );
//   }

//   Widget buildReadOnlyDropdown(String? selectedValue, String label, List<String> items) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 16),
//       child: DropdownButtonFormField<String>(
//         value: selectedValue,
//         decoration: InputDecoration(
//           labelText: label,
//           border: const OutlineInputBorder(),
//           suffixIcon: Icon(Icons.lock_outline, color: Colors.grey),
//         ),
//         items: items.map((String value) {
//           return DropdownMenuItem<String>(
//             value: value,
//             child: Text(value),
//           );
//         }).toList(),
//         onChanged: null, // Disables the dropdown
//       ),
//     );
//   }
// }

















































import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuel_tracker/frappe_API/config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
      final url = Uri.parse('$baseUrl/api/v2/method/fuel_tracker.api.fuel_used.get_all_fuel_used_records');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode(apiKeyApiSecret))}',
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
