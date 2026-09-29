import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';

class ManageSchoolSettingsScreen extends StatefulWidget {
  const ManageSchoolSettingsScreen({super.key});

  @override
  State<ManageSchoolSettingsScreen> createState() => _ManageSchoolSettingsScreenState();
}

class _ManageSchoolSettingsScreenState extends State<ManageSchoolSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: "Saintgits College of Applied Sciences");
  final _addressController = TextEditingController(text: "Kottukulam Hills, Pathamuttom P.O., Kottayam, Kerala – 686532");
  final _latController = TextEditingController(text: "9.50921");
  final _lngController = TextEditingController(text: "76.55183");

  bool _isLoading = true;
  bool _isSaving = false;
  MapController? _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadSchoolSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _loadSchoolSettings() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getSchoolSettings();
      if (res['success'] == true && res['school'] != null) {
        final school = res['school'] as Map<String, dynamic>;
        setState(() {
          _nameController.text = school['school_name']?.toString() ?? "Saintgits College of Applied Sciences";
          _addressController.text = school['address']?.toString() ?? "Kottukulam Hills, Pathamuttom P.O., Kottayam, Kerala – 686532";
          _latController.text = school['latitude']?.toString() ?? "9.50921";
          _lngController.text = school['longitude']?.toString() ?? "76.55183";
          _isLoading = false;
        });
        _recenterMap();
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _recenterMap() {
    final lat = double.tryParse(_latController.text.trim()) ?? 9.50921;
    final lng = double.tryParse(_lngController.text.trim()) ?? 76.55183;
    try {
      _mapController?.move(LatLng(lat, lng), 15.5);
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid numeric latitude and longitude coordinates.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final res = await ApiService.updateSchoolSettings(
        schoolName: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: lat,
        longitude: lng,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(res['message']?.toString() ?? 'School location updated successfully!')),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _recenterMap();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Failed to update school settings'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLat = double.tryParse(_latController.text.trim()) ?? 9.50921;
    final currentLng = double.tryParse(_lngController.text.trim()) ?? 76.55183;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('School Settings'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadSchoolSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Banner Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacityCompat(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacityCompat(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fixed School Location',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Global destination point for all bus routes, live maps & ETA calculations',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Input Form Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'School Profile & Destination Coordinates',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'School Name *',
                                prefixIcon: Icon(Icons.account_balance_rounded, color: AppColors.primary),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'School name is required' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _addressController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'School Address *',
                                prefixIcon: Icon(Icons.location_city_rounded, color: AppColors.primary),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'School address is required' : null,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _latController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Latitude *',
                                      prefixIcon: Icon(Icons.my_location_rounded, color: AppColors.primary),
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => _recenterMap(),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Required';
                                      if (double.tryParse(val.trim()) == null) return 'Invalid number';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lngController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Longitude *',
                                      prefixIcon: Icon(Icons.map_rounded, color: AppColors.primary),
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => _recenterMap(),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Required';
                                      if (double.tryParse(val.trim()) == null) return 'Invalid number';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Map Preview Section Title
                    const Text(
                      'Location Map Preview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // OpenStreetMap Preview Container
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: LatLng(currentLat, currentLng),
                            initialZoom: 15.5,
                            maxZoom: 19.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.routesafe.app',
                              retinaMode: true,
                              maxZoom: 19,
                              maxNativeZoom: 19,
                              tileProvider: NetworkTileProvider(),
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(currentLat, currentLng),
                                  width: 120,
                                  height: 60,
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade900,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: const [
                                            BoxShadow(color: Colors.black26, blurRadius: 4),
                                          ],
                                        ),
                                        child: Text(
                                          _nameController.text.trim().isNotEmpty
                                              ? _nameController.text.trim()
                                              : 'Saintgits College',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.school_rounded,
                                        color: Colors.indigo,
                                        size: 30,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 3,
                        ),
                        onPressed: _isSaving ? null : _saveSettings,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded, size: 22),
                        label: Text(
                          _isSaving ? 'Saving to MySQL...' : 'Save School Settings',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
