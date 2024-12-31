import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FuelUsedPage extends StatelessWidget {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController fuelTankerController = TextEditingController();
  final TextEditingController resourceController = TextEditingController();
  final TextEditingController siteController = TextEditingController();
  final TextEditingController fuelUsedController = TextEditingController();
  final TextEditingController requisitionNumberController = TextEditingController();

  FuelUsedPage({super.key});

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
                TextFormField(
                  controller: fuelTankerController,
                  decoration: const InputDecoration(
                    labelText: 'Fuel Tanker',
                    hintText: 'Enter fuel tanker',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the fuel tanker';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: resourceController,
                  decoration: const InputDecoration(
                    labelText: 'Resource',
                    hintText: 'Enter resource',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the resource';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: siteController,
                  decoration: const InputDecoration(
                    labelText: 'Site',
                    hintText: 'Enter site',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the site';
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
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        final newDocument = {
                          'name': 'FU-${DateTime.now().millisecondsSinceEpoch % 100000}',
                          'date': _dateController.text,
                          'fuel_tanker': fuelTankerController.text,
                          'resource': resourceController.text,
                          'site': siteController.text,
                          'fuel_used': fuelUsedController.text,
                          'requisition_number': requisitionNumberController.text,
                          'status': 'Pending',
                        };
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
