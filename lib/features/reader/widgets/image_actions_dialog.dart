import 'package:flutter/material.dart';

class ImageActionsDialog extends StatelessWidget {
  final String? imageUrl;
  final String? localPath;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final VoidCallback? onCopyUrl;
  final VoidCallback? onSetAsWallpaper;
  final VoidCallback? onInfo;

  const ImageActionsDialog({
    super.key,
    this.imageUrl,
    this.localPath,
    this.onSave,
    this.onShare,
    this.onCopyUrl,
    this.onSetAsWallpaper,
    this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          if (localPath != null || imageUrl != null) ...[
            _ActionTile(
              icon: Icons.download_rounded,
              label: 'Save to gallery',
              onTap: () {
                Navigator.pop(context);
                onSave?.call();
              },
            ),
            _ActionTile(
              icon: Icons.share_rounded,
              label: 'Share',
              onTap: () {
                Navigator.pop(context);
                onShare?.call();
              },
            ),
          ],
          if (imageUrl != null) ...[
            _ActionTile(
              icon: Icons.link_rounded,
              label: 'Copy link',
              onTap: () {
                Navigator.pop(context);
                onCopyUrl?.call();
              },
            ),
          ],
          if (localPath != null) ...[
            _ActionTile(
              icon: Icons.wallpaper_rounded,
              label: 'Set as wallpaper',
              onTap: () {
                Navigator.pop(context);
                onSetAsWallpaper?.call();
              },
            ),
          ],
          _ActionTile(
            icon: Icons.info_outline_rounded,
            label: 'Details',
            onTap: () {
              Navigator.pop(context);
              onInfo?.call();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static Future<void> show(
    BuildContext context, {
    String? imageUrl,
    String? localPath,
    VoidCallback? onSave,
    VoidCallback? onShare,
    VoidCallback? onCopyUrl,
    VoidCallback? onSetAsWallpaper,
    VoidCallback? onInfo,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ImageActionsDialog(
        imageUrl: imageUrl,
        localPath: localPath,
        onSave: onSave,
        onShare: onShare,
        onCopyUrl: onCopyUrl,
        onSetAsWallpaper: onSetAsWallpaper,
        onInfo: onInfo,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.primary),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: c.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
