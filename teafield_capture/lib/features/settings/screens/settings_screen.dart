import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/disease_classes.dart';
import '../settings_view_model.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _collectorController = TextEditingController();
  final TextEditingController _serverClientIdController =
      TextEditingController();

  String _imageQuality = 'high';
  bool _allowSingleSideComplete = false;
  bool _seeded = false;

  @override
  void dispose() {
    _projectController.dispose();
    _collectorController.dispose();
    _serverClientIdController.dispose();
    super.dispose();
  }

  void _seedOnce(SettingsState state) {
    if (_seeded || state.isLoading) return;
    _projectController.text = state.projectCode;
    _collectorController.text = state.collectorCode;
    _serverClientIdController.text = state.googleServerClientId;
    _imageQuality = state.imageQuality;
    _allowSingleSideComplete = state.allowSingleSideComplete;
    _seeded = true;
  }

  Future<void> _save() async {
    await ref.read(settingsViewModelProvider.notifier).saveSettings(
          projectCode: _projectController.text,
          collectorCode: _collectorController.text,
          imageQuality: _imageQuality,
          allowSingleSideComplete: _allowSingleSideComplete,
          googleServerClientId: _serverClientIdController.text,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  Future<void> _promptAddItem({
    required String title,
    required Future<void> Function(String) onAdd,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add $title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: title,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.isNotEmpty) {
      await onAdd(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsViewModelProvider);
    final notifier = ref.read(settingsViewModelProvider.notifier);

    _seedOnce(state);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Project & Collector Identity',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _projectController,
                  decoration: const InputDecoration(
                    labelText: 'Project Code',
                    helperText: 'Used for QR pairing and ZIP import matching',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _collectorController,
                  decoration: const InputDecoration(
                    labelText: 'Default Collector Code',
                    hintText: 'e.g., COL-01',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Image & Protocol Policy',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _imageQuality,
                  decoration: const InputDecoration(
                    labelText: 'Camera capture resolution',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'high',
                      child: Text('High (recommended for disease spots)'),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('Medium (smaller file size)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _imageQuality = val);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Supervisor option: allow single-side complete samples',
                  ),
                  subtitle: const Text(
                    'Keep OFF for standard dual-surface dataset protocol',
                  ),
                  value: _allowSingleSideComplete,
                  onChanged: (val) =>
                      setState(() => _allowSingleSideComplete = val),
                ),
                const SizedBox(height: 12),

                Text(
                  'Google Drive OAuth Configuration',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _serverClientIdController,
                  decoration: const InputDecoration(
                    labelText: 'Google Web Client ID (optional)',
                    hintText: 'xxxx.apps.googleusercontent.com',
                    helperText:
                        'Required by google_sign_in 7.x on Android Credential Manager',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                FilledButton.icon(
                  onPressed: state.isSaving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Settings'),
                ),
                const SizedBox(height: 20),

                // ── Presets ─────────────────────────────────────────
                _PresetExpansionCard(
                  title: 'Estate / Plantation Presets (${state.estates.length})',
                  items: state.estates,
                  onAdd: () => _promptAddItem(
                    title: 'Estate',
                    onAdd: notifier.addEstate,
                  ),
                  onDelete: notifier.removeEstate,
                ),
                const SizedBox(height: 8),
                _PresetExpansionCard(
                  title: 'Region Presets (${state.regions.length})',
                  items: state.regions,
                  onAdd: () => _promptAddItem(
                    title: 'Region',
                    onAdd: notifier.addRegion,
                  ),
                  onDelete: notifier.removeRegion,
                ),
                const SizedBox(height: 8),
                _PresetExpansionCard(
                  title: 'District Presets (${state.districts.length})',
                  items: state.districts,
                  onAdd: () => _promptAddItem(
                    title: 'District',
                    onAdd: notifier.addDistrict,
                  ),
                  onDelete: notifier.removeDistrict,
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  title: const Text('Configured Provisional Disease Classes'),
                  children: DiseaseClass.defaultFieldLabels
                      .map(
                        (dc) => ListTile(
                          dense: true,
                          title: Text(dc.displayName),
                          subtitle: Text('key: ${dc.databaseKey}'),
                        ),
                      )
                      .toList(),
                ),
                const Divider(height: 28),

                // ── Navigation to Data Management, Trash, Drive ─────
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Google Drive Backup'),
                  subtitle: Text(
                    state.driveAccountEmail ?? 'Not connected',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/drive-backup'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Trash'),
                  subtitle: const Text('Restore or permanently delete items'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/trash'),
                ),
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('Data Management'),
                  subtitle: const Text(
                    'Storage stats, cloud deletions, reset project data',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/data-management'),
                ),
                const Divider(height: 28),

                // ── Privacy & Device Metadata ───────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Privacy & Research Provenance',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text('App Version: ${state.appVersion}'),
                        Text('App Device UUID: ${state.deviceId}'),
                        const SizedBox(height: 6),
                        const Text(
                          '• Original leaf photographs are stored in app-private storage and never overwritten.\n'
                          '• GPS is captured foreground-only while collecting a sample.\n'
                          '• No IMEI, serial number, or contacts are read.\n'
                          '• Backups upload to My Drive only when explicitly initiated.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PresetExpansionCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final VoidCallback onAdd;
  final Future<void> Function(String) onDelete;

  const _PresetExpansionCard({
    required this.title,
    required this.items,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(title),
        children: [
          ...items.map(
            (item) => ListTile(
              dense: true,
              title: Text(item),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => onDelete(item),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Preset'),
            ),
          ),
        ],
      ),
    );
  }
}
