import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../core/utils/app_date_utils.dart';
import '../../../data/models/leaf_photo.dart';
import '../../../data/models/leaf_sample.dart';

/// Reusable card widget displaying one leaf surface slot (upper or lower).
class PhotoSlotCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final LeafSide leafSide;
  final LeafPhoto? photo;
  final VoidCallback onCapture;
  final VoidCallback onRetake;
  final VoidCallback? onViewFull;

  const PhotoSlotCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leafSide,
    required this.photo,
    required this.onCapture,
    required this.onRetake,
    this.onViewFull,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentPhoto = photo;
    final hasFile =
        currentPhoto != null && File(currentPhoto.filePath).existsSync();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: currentPhoto != null
              ? colorScheme.primary
              : colorScheme.outlineVariant,
          width: currentPhoto != null ? 1.5 : 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 220),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    leafSide == LeafSide.upper
                        ? Icons.wb_sunny_outlined
                        : Icons.flip_to_back_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          subtitle,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (currentPhoto != null)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF2E7D32),
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (currentPhoto == null)
                _EmptySlotBody(
                  buttonLabel: leafSide == LeafSide.upper
                      ? 'Take upper photo'
                      : 'Take lower photo',
                  onCapture: onCapture,
                )
              else ...[
                GestureDetector(
                  onTap: onViewFull,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: hasFile
                        ? Image.file(
                            File(currentPhoto.filePath),
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            height: 150,
                            color: colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image_outlined, size: 36),
                                  SizedBox(height: 4),
                                  Text('Photo file missing on disk'),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Captured: ${AppDateUtils.formatDisplayDateTime(currentPhoto.capturedAtUtc)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Device: ${currentPhoto.deviceModel ?? 'unknown'}'
                  '${currentPhoto.widthPx != null ? ' • ${currentPhoto.widthPx}×${currentPhoto.heightPx}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onRetake,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Retake'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySlotBody extends StatelessWidget {
  final String buttonLabel;
  final VoidCallback onCapture;

  const _EmptySlotBody({
    required this.buttonLabel,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant,
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: 36,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: onCapture,
              icon: const Icon(Icons.camera_alt),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
