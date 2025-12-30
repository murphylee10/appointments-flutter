import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../utils/backup_helper.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clinicNameController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _serviceDescriptionController = TextEditingController();
  final _defaultDurationController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _lastBackupDisplay = 'Never';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _clinicNameController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _unitPriceController.dispose();
    _serviceDescriptionController.dispose();
    _defaultDurationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper().getAllSettings();
    final lastBackup = await BackupHelper.getLastBackupDisplayString();
    setState(() {
      _clinicNameController.text = settings[SettingsKeys.clinicName] ?? '';
      _addressLine1Controller.text = settings[SettingsKeys.addressLine1] ?? '';
      _addressLine2Controller.text = settings[SettingsKeys.addressLine2] ?? '';
      _unitPriceController.text = settings[SettingsKeys.unitPrice] ?? '';
      _serviceDescriptionController.text = settings[SettingsKeys.serviceDescription] ?? '';
      _defaultDurationController.text = settings[SettingsKeys.defaultAppointmentDuration] ?? '40';
      _lastBackupDisplay = lastBackup;
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    await DatabaseHelper().saveAllSettings({
      SettingsKeys.clinicName: _clinicNameController.text,
      SettingsKeys.addressLine1: _addressLine1Controller.text,
      SettingsKeys.addressLine2: _addressLine2Controller.text,
      SettingsKeys.unitPrice: _unitPriceController.text,
      SettingsKeys.serviceDescription: _serviceDescriptionController.text,
      SettingsKeys.defaultAppointmentDuration: _defaultDurationController.text,
    });

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clinic Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clinic Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'This information appears on generated receipts',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _clinicNameController,
                        decoration: const InputDecoration(
                          labelText: 'Clinic Name',
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _addressLine1Controller,
                        decoration: const InputDecoration(
                          labelText: 'Address Line 1',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _addressLine2Controller,
                        decoration: const InputDecoration(
                          labelText: 'Address Line 2',
                          hintText: 'City, Province, Postal Code',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Pricing Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pricing',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Default pricing for appointments and receipts',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _unitPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Price per Visit',
                          prefixText: '\$ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final price = double.tryParse(v);
                          if (price == null || price < 0) {
                            return 'Enter a valid price';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _serviceDescriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Service Description',
                          hintText: 'e.g., Chiropractic adjustment',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Scheduling Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scheduling',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Default settings for appointment booking',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _defaultDurationController,
                        decoration: const InputDecoration(
                          labelText: 'Default Appointment Duration',
                          suffixText: 'minutes',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final duration = int.tryParse(v);
                          if (duration == null || duration < 5 || duration > 180) {
                            return 'Enter 5-180 minutes';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Data Backup Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data Backup',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Your data is automatically backed up when the app closes',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Last backup: $_lastBackupDisplay',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final success = await BackupHelper.exportBackup(context);
                                if (success) {
                                  final lastBackup = await BackupHelper.getLastBackupDisplayString();
                                  setState(() => _lastBackupDisplay = lastBackup);
                                }
                              },
                              icon: const Icon(Icons.save_alt, size: 18),
                              label: const Text('Export Backup'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await BackupHelper.importBackup(context);
                              },
                              icon: const Icon(Icons.restore, size: 18),
                              label: const Text('Restore'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveSettings,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
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
