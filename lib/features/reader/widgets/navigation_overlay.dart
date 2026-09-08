import 'dart:async';

import 'package:flutter/material.dart';

/// Visual tap zone overlay shown when the reader first opens.
///
/// Displays labeled zones (PREV / MENU / NEXT) in the configured
/// navigation layout, inspired by mangayomi's navigation overlay.
/// Fades out on tap or automatically after 3 seconds.
class NavigationOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final int
  navigationLayout; // 0=default, 1=L-shaped, 2=kindle, 3=edge, 4=right&left

  const NavigationOverlay({
    super.key,
    required this.onDismiss,
    this.navigationLayout = 0,
  });

  static const _prevColor = Color(0xCCFF7733);
  static const _menuColor = Color(0xCC95818D);
  static const _nextColor = Color(0xCC84E296);
  static const _autoDismissDelay = Duration(seconds: 3);
  static const _fadeDuration = Duration(milliseconds: 450);

  @override
  State<NavigationOverlay> createState() => _NavigationOverlayState();
}

class _NavigationOverlayState extends State<NavigationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  Timer? _autoHide;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: NavigationOverlay._fadeDuration,
      value: 1,
    );
    _autoHide = Timer(NavigationOverlay._autoDismissDelay, _fadeOutAndDismiss);
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _fade.dispose();
    super.dispose();
  }

  Future<void> _fadeOutAndDismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _autoHide?.cancel();
    await _fade.animateTo(0, curve: Curves.easeOut);
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        onTap: _fadeOutAndDismiss,
        child: Container(
          color: Colors.black38,
          child: Stack(
            children: [
              switch (widget.navigationLayout) {
                4 => _buildRightLeft(),
                _ => _buildDefault(),
              },
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Tap anywhere to dismiss',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
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

  Widget _buildDefault() {
    return Stack(
      children: [
        Row(
          children: [
            Expanded(child: _zone(NavigationOverlay._prevColor, 'PREV')),
            Expanded(child: _zone(NavigationOverlay._menuColor, 'MENU')),
            Expanded(child: _zone(NavigationOverlay._nextColor, 'NEXT')),
          ],
        ),
        Column(
          children: [
            Expanded(flex: 2, child: _zone(NavigationOverlay._prevColor, 'PREV')),
            const Expanded(flex: 5, child: SizedBox.shrink()),
            Expanded(flex: 2, child: _zone(NavigationOverlay._nextColor, 'NEXT')),
          ],
        ),
      ],
    );
  }

  Widget _buildRightLeft() {
    return Row(
      children: [
        Expanded(child: _zone(NavigationOverlay._prevColor, 'PREV')),
        Expanded(child: _zone(NavigationOverlay._nextColor, 'NEXT')),
      ],
    );
  }

  Widget _zone(Color color, String label) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black26, width: 0.5),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            shadows: [
              Shadow(
                blurRadius: 6,
                color: Colors.black54,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
