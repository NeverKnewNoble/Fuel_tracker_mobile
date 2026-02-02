import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _tankerController = TextEditingController();
  final TextEditingController _siteController = TextEditingController();

  String? selectedDefaultTanker;
  String? selectedDefaultSite;

  List<String> fuelTankers = [];
  List<String> sites = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tankerController.dispose();
    _siteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load cached options
    final cachedTankers = prefs.getStringList('cachedFuelTankers') ?? [];
    final cachedSites = prefs.getStringList('cachedSites') ?? [];

    // Load current defaults
    final defaultTanker = prefs.getString('defaultFuelTanker');
    final defaultSite = prefs.getString('defaultSite');

    if (mounted) {
      setState(() {
        fuelTankers = cachedTankers;
        sites = cachedSites;
        selectedDefaultTanker = defaultTanker;
        selectedDefaultSite = defaultSite;
        if (defaultTanker != null) {
          _tankerController.text = defaultTanker;
        }
        if (defaultSite != null) {
          _siteController.text = defaultSite;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDefaultTanker(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value != null && value.isNotEmpty) {
      await prefs.setString('defaultFuelTanker', value);
    } else {
      await prefs.remove('defaultFuelTanker');
    }
    setState(() {
      selectedDefaultTanker = value;
    });
  }

  Future<void> _saveDefaultSite(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value != null && value.isNotEmpty) {
      await prefs.setString('defaultSite', value);
    } else {
      await prefs.remove('defaultSite');
    }
    setState(() {
      selectedDefaultSite = value;
    });
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
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildContent(),
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
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Configure your defaults',
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

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Default Values',
            style: TextStyle(
              color: Color(0xFF1A237E),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These values will be pre-selected when creating new fuel entries.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          _buildAutocompleteCard(
            label: 'Default Fuel Tanker',
            hint: 'Type to search tankers...',
            icon: Icons.local_shipping_outlined,
            controller: _tankerController,
            items: fuelTankers,
            onSelected: (value) {
              _tankerController.text = value;
              _saveDefaultTanker(value);
            },
            onCleared: () {
              _tankerController.clear();
              _saveDefaultTanker(null);
            },
          ),
          const SizedBox(height: 16),
          _buildAutocompleteCard(
            label: 'Default Site',
            hint: 'Type to search sites...',
            icon: Icons.location_on_outlined,
            controller: _siteController,
            items: sites,
            onSelected: (value) {
              _siteController.text = value;
              _saveDefaultSite(value);
            },
            onCleared: () {
              _siteController.clear();
              _saveDefaultSite(null);
            },
          ),
          const SizedBox(height: 32),
          if (fuelTankers.isEmpty && sites.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No options available. Please go to the fuel entry page while online to load tankers and sites.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (selectedDefaultTanker != null || selectedDefaultSite != null)
            _buildClearButton(),
        ],
      ),
    );
  }

  Widget _buildAutocompleteCard({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required List<String> items,
    required void Function(String) onSelected,
    required VoidCallback onCleared,
  }) {
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3949AB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF3949AB), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1A237E),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
              // Sync with external controller
              if (controller.text.isNotEmpty && textController.text.isEmpty) {
                textController.text = controller.text;
              }
              return TextField(
                controller: textController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  suffixIcon: textController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 20),
                          onPressed: () {
                            textController.clear();
                            onCleared();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3949AB), width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A237E)),
                onChanged: (value) {
                  setState(() {});
                },
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 200,
                      maxWidth: MediaQuery.of(context).size.width - 72,
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
      ),
    );
  }

  Widget _buildClearButton() {
    return Center(
      child: TextButton.icon(
        onPressed: () async {
          _tankerController.clear();
          _siteController.clear();
          await _saveDefaultTanker(null);
          await _saveDefaultSite(null);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Defaults cleared'),
                backgroundColor: const Color(0xFF3949AB),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        },
        icon: Icon(Icons.clear_all, color: Colors.grey.shade600),
        label: Text(
          'Clear all defaults',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }
}
