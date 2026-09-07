import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/user_profile.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens/app_colors.dart';
import '../../theme/tokens/app_motion.dart';
import '../../widgets/screen_chrome.dart';

/// Kenji-inspired first-run flow: name → genres → extension repos → done.
///
/// No recommendation engine — genres are stored for a future suggestions
/// feature. Repos are saved only; extensions are not installed here.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  final _nameCtrl = TextEditingController();
  final _repoNameCtrl = TextEditingController();
  final _repoUrlCtrl = TextEditingController();

  int _step = 0;
  final Set<String> _genres = {};
  final List<({String name, String url})> _pendingRepos = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _page.dispose();
    _nameCtrl.dispose();
    _repoNameCtrl.dispose();
    _repoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _skipAll() async {
    await ref.read(userProfileProvider.notifier).completeOnboarding(
      displayName: _nameCtrl.text,
      genres: _genres.toList(),
    );
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final mgr = ref.read(extensionManagerProvider);
      for (final repo in _pendingRepos) {
        await mgr.addRepo(name: repo.name, url: repo.url);
      }
      await ref.read(userProfileProvider.notifier).completeOnboarding(
        displayName: _nameCtrl.text,
        genres: _genres.toList(),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  void _next() {
    if (_step >= 2) {
      _finish();
      return;
    }
    setState(() => _step++);
    _page.animateToPage(
      _step,
      duration: AppMotion.page,
      curve: AppMotion.decelerate,
    );
  }

  void _addRepoLocal() {
    final name = _repoNameCtrl.text.trim();
    final url = _repoUrlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _error = null;
      _pendingRepos.add((
        name: name.isEmpty ? 'Repository' : name,
        url: url,
      ));
      _repoNameCtrl.clear();
      _repoUrlCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ScreenBackdrop(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5E0),
                      borderRadius: BorderRadius.circular(48),
                    ),
                    child: const Text(
                      '😎  Welcome to Koma!',
                      style: TextStyle(
                        color: Color(0xFF19191C),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy ? null : _skipAll,
                    child: Text(
                      'Skip',
                      style: TextStyle(color: c.textTertiary, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _NameStep(
                    controller: _nameCtrl,
                    onContinue: _next,
                  ),
                  _GenreStep(
                    selected: _genres,
                    onToggle: (label) {
                      setState(() {
                        if (!_genres.add(label)) _genres.remove(label);
                      });
                    },
                    onContinue: _next,
                  ),
                  _ReposStep(
                    nameCtrl: _repoNameCtrl,
                    urlCtrl: _repoUrlCtrl,
                    pending: _pendingRepos,
                    error: _error,
                    busy: _busy,
                    onAdd: _addRepoLocal,
                    onRemove: (i) => setState(() => _pendingRepos.removeAt(i)),
                    onComplete: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller, required this.onContinue});

  final TextEditingController controller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What should we call you?',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Used for greetings on your library. Stored only on this device.',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: c.textPrimary, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Your name',
              hintStyle: TextStyle(color: c.textTertiary),
              filled: true,
              fillColor: c.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => onContinue(),
          ),
          const Spacer(),
          _PillButton(label: 'Continue', onPressed: onContinue),
        ],
      ),
    );
  }
}

class _GenreStep extends StatelessWidget {
  const _GenreStep({
    required this.selected,
    required this.onToggle,
    required this.onContinue,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = selected.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What genre do you enjoy reading?',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We’ll remember these for later. Suggestions aren’t available yet.',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < OnboardingGenres.options.length; i++)
                    StaggeredFadeScale(
                      index: i,
                      child: _GenreChip(
                        emoji: OnboardingGenres.options[i].emoji,
                        label: OnboardingGenres.options[i].label,
                        selected: selected.contains(
                          OnboardingGenres.options[i].label,
                        ),
                        onTap: () =>
                            onToggle(OnboardingGenres.options[i].label),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _PillButton(
            label: 'Continue',
            onPressed: enabled ? onContinue : null,
            emphasized: enabled,
          ),
        ],
      ),
    );
  }
}

class _ReposStep extends StatelessWidget {
  const _ReposStep({
    required this.nameCtrl,
    required this.urlCtrl,
    required this.pending,
    required this.error,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
    required this.onComplete,
  });

  final TextEditingController nameCtrl;
  final TextEditingController urlCtrl;
  final List<({String name, String url})> pending;
  final String? error;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add an extension repository',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Repos list available sources. You can install extensions later '
            'from Plugins — nothing is installed in this step.',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Repository URL',
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameCtrl,
            style: TextStyle(color: c.textPrimary),
            decoration: InputDecoration(
              hintText: 'Name (optional)',
              hintStyle: TextStyle(color: c.textTertiary),
              filled: true,
              fillColor: c.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: urlCtrl,
            style: TextStyle(color: c.textPrimary),
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://…/index.pb or index.json',
              hintStyle: TextStyle(color: c.textTertiary),
              filled: true,
              fillColor: c.surfaceMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: busy ? null : onAdd,
              child: Text(
                'Add repo',
                style: TextStyle(
                  color: c.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (error != null) ...[
            Text(
              error!,
              style: TextStyle(color: AppColors.danger, fontSize: 13),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: ListView.separated(
              itemCount: pending.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = pending[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.borderStrong, width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_outlined, color: c.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.name,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              r.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: busy ? null : () => onRemove(i),
                        icon: Icon(Icons.close, color: c.textSecondary),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          _PillButton(
            label: busy ? 'Saving…' : 'Complete',
            onPressed: busy ? null : onComplete,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.accentMuted : c.bg,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? c.accent : c.borderStrong,
          width: 1.7,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? c.accent : c.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    final bg = !enabled
        ? c.surfaceMuted
        : emphasized
        ? c.accent
        : c.surfaceMuted;
    final fg = !enabled
        ? c.textTertiary
        : emphasized
        ? c.onAccent
        : c.textSecondary;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: c.surfaceMuted,
          disabledForegroundColor: c.textTertiary,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
