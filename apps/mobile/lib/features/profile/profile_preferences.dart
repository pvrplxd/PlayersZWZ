import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../app/app_theme.dart';
import '../../core/ui/pz_controls.dart';
import '../discovery/discovery_widgets.dart';
import '../games/sport_formats.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class ProfilePreferencesScreen extends StatefulWidget {
  const ProfilePreferencesScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ProfilePreferencesScreen> createState() =>
      _ProfilePreferencesScreenState();
}

class _ProfilePreferencesScreenState extends State<ProfilePreferencesScreen> {
  static const _sports = <String>[
    'Basketball',
    'Badminton',
    'Football',
    'Skating',
    'Cricket',
    'Tennis'
  ];
  static const _days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  final _bio = TextEditingController();
  final _selectedSports = <String>{};
  final _selectedDays = <String>{};
  double _radius = 10;
  final _roles = <String, Set<String>>{};
  final _levels = <String, String>{};
  String? _expanded;
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await widget.api.get('/api/v1/me/profile');
      final profile = result is Map ? result['profile'] : null;
      if (profile is! Map) {
        throw const ApiException(0, 'INVALID_RESPONSE', 'Invalid profile.');
      }
      if (!mounted) return;
      setState(() {
        _selectedSports
          ..clear()
          ..addAll((profile['sports'] as List? ?? const [])
              .whereType<String>()
              .where(_sports.contains));
        _selectedDays
          ..clear()
          ..addAll((profile['availability'] as List? ?? const [])
              .whereType<String>()
              .where(_days.contains));
        final radius = profile['radius_km'];
        _radius = radius is num ? radius.clamp(1, 50).toDouble() : 10;
        _bio.text = profile['bio'] is String ? profile['bio'] as String : '';
        _roles.clear();
        final roles = profile['roles'];
        if (roles is Map) {
          for (final entry in roles.entries) {
            if (entry.key is String && entry.value is List) {
              _roles[entry.key as String] =
                  (entry.value as List).whereType<String>().toSet();
            }
          }
        }
        _levels.clear();
        final levels = profile['levels'];
        if (levels is Map) {
          for (final entry in levels.entries) {
            if (entry.key is String && entry.value is String) {
              _levels[entry.key as String] = entry.value as String;
            }
          }
        }
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
          _message = 'Could not load your profile. Pull down or tap Retry.';
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _selectedSports.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await widget.api.patch('/api/v1/me/profile', body: {
        'sports': _sports.where(_selectedSports.contains).toList(),
        'availability': _days.where(_selectedDays.contains).toList(),
        'radius_km': _radius.round(),
        'bio': _bio.text,
        'roles': {
          for (final sport in _selectedSports)
            sport: [
              for (final role in sportRoles[sport] ?? const <String>[])
                if (_roles[sport]?.contains(role) ?? false) role
            ],
        },
        'levels': {
          for (final sport in _selectedSports)
            if (_levels[sport] != null) sport: _levels[sport]!,
        },
      });
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Could not save your profile. Your edits are kept; please retry.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool get _isIOS => Theme.of(context).platform == TargetPlatform.iOS;

  void _toggle(Set<String> set, String value) {
    if (_saving) return;
    setState(() => set.contains(value) ? set.remove(value) : set.add(value));
  }

  Widget _section(String title, Widget child,
          {String? helper, bool optional = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PzSectionTitle(title, optional: optional),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(helper, style: AppTheme.footnote),
          ],
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _dayPicker() => Row(children: [
        for (var i = 0; i < _days.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              button: true,
              selected: _selectedDays.contains(_days[i]),
              label: _days[i],
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _toggle(_selectedDays, _days[i]);
                },
                child: Center(
                  heightFactor: 1,
                  child: AnimatedContainer(
                    width: 40,
                    height: 40,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selectedDays.contains(_days[i])
                          ? AppTheme.lime
                          : AppTheme.surfaceRaised,
                      border: Border.all(color: const Color(0x0FFFFFFF), width: .5),
                    ),
                    alignment: Alignment.center,
                    child: Text(_days[i].substring(0, 2),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedDays.contains(_days[i])
                                ? Colors.black
                                : AppTheme.primaryText)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ]);

  String _summary(String sport) {
    final roles = [
      for (final role in sportRoles[sport] ?? const <String>[])
        if (_roles[sport]?.contains(role) ?? false) role
    ];
    final level = _levels[sport];
    if (roles.isEmpty && level == null) return 'Tap to add your role and level';
    return [...roles, if (level != null) level].join(' · ');
  }

  void _tapSport(String sport) {
    if (_saving) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedSports.contains(sport)) {
        _selectedSports.add(sport);
        _levels.putIfAbsent(sport, () => 'Intermediate');
        _expanded = sport;
      } else {
        _expanded = _expanded == sport ? null : sport;
      }
    });
  }

  void _toggleSport(String sport) {
    if (_saving) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedSports.remove(sport)) {
        if (_expanded == sport) _expanded = null;
      } else {
        _selectedSports.add(sport);
        _levels.putIfAbsent(sport, () => 'Intermediate');
        _expanded = sport;
      }
    });
  }

  /// A sport row that is multi-selectable and expands in place for details.
  Widget _sportCard(String sport) {
    final selected = _selectedSports.contains(sport);
    final open = selected && _expanded == sport;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 560);
    return AnimatedContainer(
      duration: duration,
      curve: pzSpring,
      decoration: ShapeDecoration(
        color: open ? const Color(0xFF18181B) : AppTheme.surfaceRaised,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(open ? 24 : 20),
          side: BorderSide(
              color: open
                  ? AppTheme.lime.withValues(alpha: .35)
                  : const Color(0x0FFFFFFF),
              width: open ? 1 : .5),
        ),
      ),
      child: Column(children: [
        Semantics(
          button: true,
          selected: selected,
          expanded: open,
          label: '$sport. ${selected ? _summary(sport) : 'Not selected'}',
          excludeSemantics: true,
          child: PzPressable(
            scale: .985,
            haptic: false,
            onTap: () => _tapSport(sport),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(children: [
                AnimatedContainer(
                  duration: duration,
                  curve: pzSpring,
                  width: open ? 50 : 44,
                  height: open ? 50 : 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppTheme.lime : AppTheme.surfaceHighest,
                  ),
                  child: Icon(SportSymbol.boldIconFor(sport),
                      size: 20,
                      color: selected ? Colors.black : AppTheme.primaryText),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sport, style: AppTheme.headline),
                        AnimatedSize(
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topLeft,
                          child: selected
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(_summary(sport),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.footnote),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ]),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggleSport(sport),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: PzCheckMark(selected: selected),
                  ),
                ),
              ]),
            ),
          ),
        ),
        AnimatedSize(
          duration: duration,
          curve: pzSpring,
          alignment: Alignment.topCenter,
          child: !open
              ? const SizedBox(width: double.infinity)
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: reduce ? Duration.zero : const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                        offset: Offset(0, -10 * (1 - t)), child: child),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Roles', style: AppTheme.caption),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final role
                                in sportRoles[sport] ?? const <String>[])
                              PzChoicePill(
                                label: role,
                                compact: true,
                                fill: AppTheme.surfaceHighest,
                                selected: _roles[sport]?.contains(role) ?? false,
                                onTap: _saving
                                    ? null
                                    : () => setState(() {
                                          final set = _roles.putIfAbsent(
                                              sport, () => {});
                                          set.contains(role)
                                              ? set.remove(role)
                                              : set.add(role);
                                        }),
                              ),
                          ]),
                          const SizedBox(height: 16),
                          const Text('Level', style: AppTheme.caption),
                          const SizedBox(height: 8),
                          PzSegmented(
                            options: skillLevels,
                            height: 38,
                            track: AppTheme.surfaceHighest,
                            selectedIndex: skillLevels
                                .indexOf(_levels[sport] ?? 'Intermediate'),
                            onChanged: _saving
                                ? null
                                : (i) =>
                                    setState(() => _levels[sport] = skillLevels[i]),
                          ),
                        ]),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _aboutField() => PzCard(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: TextField(
          controller: _bio,
          enabled: !_saving,
          maxLength: 280,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 15, height: 1.4),
          decoration: const InputDecoration(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: 'Positions you play, level, when you’re free…',
            contentPadding: EdgeInsets.only(top: 12),
          ),
        ),
      );

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: SizedBox(
          height: 48,
          child: Stack(alignment: Alignment.center, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PzCircleButton(
                icon: _isIOS
                    ? PhosphorIconsBold.caretLeft
                    : PhosphorIconsBold.arrowLeft,
                label: 'Back',
                onPressed:
                    _saving ? null : () => Navigator.of(context).maybePop(),
              ),
            ),
            const Text('Edit profile', style: AppTheme.headline),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final canSave = _selectedSports.isNotEmpty && !_saving;
    final children = <Widget>[
      const Text('Your player card', style: AppTheme.title1),
      const SizedBox(height: 6),
      Text('This is what hosts and players see.',
          style: AppTheme.bodyText.copyWith(color: AppTheme.muted)),
      const SizedBox(height: 28),
      _section('About you', _aboutField(), optional: true),
      _section(
          'Sports',
          Column(children: [
            for (final sport in _sports)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _sportCard(sport),
              ),
          ]),
          helper: _selectedSports.isEmpty
              ? 'Pick at least one sport.'
              : 'Tap a sport to set your role and level. Hosts see this.'),
      const SizedBox(height: 20),
      _section('Available days', _dayPicker(),
          helper: _selectedDays.isEmpty
              ? 'None selected means any day.'
              : '${_selectedDays.length} of 7 days'),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Semantics(
            liveRegion: true,
            child: Row(children: [
              const Icon(PhosphorIconsFill.warningCircle,
                  size: 16, color: AppTheme.destructive),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_message!,
                      style: const TextStyle(
                          color: AppTheme.destructive, fontSize: 13))),
              if (_loadFailed)
                TextButton(onPressed: _load, child: const Text('Retry')),
            ]),
          ),
        ),
    ];
    final list = _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.lime))
        : ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: children,
          );
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Column(children: [
          _topBar(),
          Expanded(child: list),
          if (!_loading)
            Container(
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: pzLine))),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: FilledButton(
                onPressed: canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.lime,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppTheme.surfaceHighest,
                  disabledForegroundColor: AppTheme.muted,
                  minimumSize: const Size.fromHeight(56),
                  shape: const StadiumBorder(),
                ),
                child: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
            ),
        ]),
      ),
    );
  }
}
