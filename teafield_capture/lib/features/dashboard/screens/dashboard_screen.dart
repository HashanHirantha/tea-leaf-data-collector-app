import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_date_utils.dart';
import '../dashboard_view_model.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<void> _navigateAndRefresh(String route) async {
    await context.push(route);
    if (mounted) {
      await ref.read(dashboardViewModelProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_rounded),
            SizedBox(width: 8),
            Text('TeaField Capture'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh counts',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(dashboardViewModelProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(dashboardViewModelProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.pendingCloudDeletions > 0)
              Card(
                color: colorScheme.errorContainer,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    Icons.cloud_off,
                    color: colorScheme.onErrorContainer,
                  ),
                  title: Text(
                    '${state.pendingCloudDeletions} Drive archive deletion(s) pending',
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Tap to retry cloud deletion when online.',
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _navigateAndRefresh('/data-management'),
                ),
              ),
            _PrimaryCaptureCard(
              onNewSample: () => _navigateAndRefresh('/new-sample'),
              onJoinByQr: () => _navigateAndRefresh('/join-sample'),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width >= 600 ? 3 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                _ActionTile(
                  icon: Icons.collections_bookmark_outlined,
                  title: 'Saved Samples',
                  subtitle: state.incompleteSamples > 0
                      ? '${state.incompleteSamples} incomplete'
                      : '${state.totalPhotos} photos',
                  badgeCount: state.totalSamples,
                  onTap: () => _navigateAndRefresh('/samples'),
                ),
                _ActionTile(
                  icon: Icons.archive_outlined,
                  title: 'Export Data',
                  subtitle: 'ZIP & CSV research files',
                  onTap: () => _navigateAndRefresh('/export'),
                ),
                _ActionTile(
                  icon: Icons.file_download_outlined,
                  title: 'Import Package',
                  subtitle: 'Merge two-phone ZIPs',
                  onTap: () => _navigateAndRefresh('/import'),
                ),
                _ActionTile(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Google Drive Backup',
                  subtitle: 'Manual upload only',
                  onTap: () => _navigateAndRefresh('/drive-backup'),
                ),
                _ActionTile(
                  icon: Icons.delete_outline,
                  title: 'Trash & Storage',
                  subtitle: 'Restore or purge records',
                  onTap: () => _navigateAndRefresh('/data-management'),
                ),
                _ActionTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'Project, estates, labels',
                  onTap: () => _navigateAndRefresh('/settings'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collection Status (Offline Ready)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 10),
                    _StatusRow(label: 'Project Code', value: state.projectCode),
                    _StatusRow(
                      label: 'Collector Code',
                      value: state.collectorCode.isEmpty
                          ? 'Not set (configure in Settings)'
                          : state.collectorCode,
                    ),
                    _StatusRow(
                      label: 'Active Leaf Samples',
                      value: '${state.totalSamples} (${state.totalPhotos} photos)',
                    ),
                    _StatusRow(
                      label: 'Last Drive Backup',
                      value: state.lastBackupDateUtc == null
                          ? 'Never uploaded'
                          : AppDateUtils.formatDisplayDateTime(
                              state.lastBackupDateUtc,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryCaptureCard extends StatelessWidget {
  final VoidCallback onNewSample;
  final VoidCallback onJoinByQr;

  const _PrimaryCaptureCard({
    required this.onNewSample,
    required this.onJoinByQr,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.primaryContainer,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.eco,
                  size: 32,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Field Leaf Capture',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Photograph upper & lower surfaces as one paired sample',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onNewSample,
              icon: const Icon(Icons.add_a_photo),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('New Leaf Sample'),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onJoinByQr,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Join Existing Sample (Scan QR)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int? badgeCount;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 28, color: colorScheme.primary),
                  if (badgeCount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
