import 'dart:io';
import 'package:flutter/material.dart';
import 'subsampling_scale_image_view/subsampling_scale_image_view.dart';
import 'reader_settings_sheet.dart';

class MinSubsamplingImageImageView extends StatefulWidget {
  final String? imageUrl;
  final String? localPath;
  final ReaderSettings settings;
  final double? minScale;
  final bool cropBorders;
  final int rotationDegrees;
  final VoidCallback? onImageReady;
  final ValueChanged<String>? onImageError;
  final ValueChanged<LoadState>? onStatusChanged;

  const MinSubsamplingImageImageView({
    super.key,
    this.imageUrl,
    this.localPath,
    required this.settings,
    this.minScale,
    this.cropBorders = false,
    this.rotationDegrees = 0,
    this.onImageReady,
    this.onImageError,
    this.onStatusChanged,
  });

  @override
  State<MinSubsamplingImageImageView> createState() =>
      _MinSubsamplingImageImageViewState();
}

class _MinSubsamplingImageImageViewState
    extends State<MinSubsamplingImageImageView> {
  @override
  void didUpdateWidget(covariant MinSubsamplingImageImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.localPath != widget.localPath) {}
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object> source;
    if (widget.localPath != null) {
      source = FileImage(File(widget.localPath!));
    } else {
      source = NetworkImage(widget.imageUrl ?? '');
    }

    final effectiveMinScale =
        widget.minScale ?? (widget.cropBorders ? 1.0 : 0.8);

    return SubsamplingScaleImageView(
      image: source,
      resolvedFilePath: widget.localPath,
      minScale: effectiveMinScale,
      maxScale: 8.0,
      rotation: widget.rotationDegrees,
      cropBorders: widget.cropBorders,
      panEnabled: true,
      zoomEnabled: true,
      doubleTapZoomDuration: const Duration(milliseconds: 250),
      onReady: () {
        widget.onStatusChanged?.call(LoadState.completed);
        widget.onImageReady?.call();
      },
      onImageLoaded: (int width, int height) {
        widget.onStatusChanged?.call(LoadState.completed);
      },
      onError: (String error) {
        widget.onStatusChanged?.call(LoadState.failed);
        widget.onImageError?.call("Failed to load image");
      },
      loadStateChanged: (SubsamplingImageState state) {
        final loadState = state.loadState;
        widget.onStatusChanged?.call(loadState);
        return null;
      },
    );
  }
}
