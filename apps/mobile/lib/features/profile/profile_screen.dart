import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/native/native_ui.dart';
import '../../core/ui/pz_controls.dart';
import '../games/game_model.dart';
import '../games/game_service.dart';
import '../discovery/discovery_widgets.dart';
import '../location/location_service.dart';
import 'profile_photo.dart';
import 'profile_photo_editor.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.name,
    required this.area,
    required this.navigationSpace,
    required this.profileRadius,
    required this.isSigningOut,
    required this.onEditPreferences,
    required this.onSignOut,
    this.photo,
    this.username = '',
    this.api,
    this.profileSummary,
    this.onLocationModeChanged,
    this.onSetHome,
  });

  final String name;
  final String username;
  final Area area;
  final double navigationSpace;
  final double profileRadius;
  final bool isSigningOut;
  final VoidCallback onEditPreferences;
  final VoidCallback onSignOut;
  final ProfilePhotoController? photo;
  final ApiClient? api;
  final Map<String, dynamic>? profileSummary;
  final ValueChanged<String>? onLocationModeChanged;
  final VoidCallback? onSetHome;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ({int played, int upcoming, int hosting})? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final api = widget.api;
    if (api == null) return;
    try {
      final data = await GameService(api).activity();
      final now = DateTime.now();
      bool live(Game g) => g.status != 'cancelled' && g.startTime.isAfter(now);
      final hosted = data['hosted'] ?? const <Game>[];
      final joined = data['joined'] ?? const <Game>[];
      final history = data['history'] ?? const <Game>[];
      if (!mounted) return;
      setState(() => _stats = (
            played: history.where((g) => g.status != 'cancelled').length,
            upcoming: hosted.where(live).length + joined.where(live).length,
            hosting: hosted.where(live).length,
          ));
    } catch (_) {
      // Stats are optional; the rest of the profile still works.
    }
  }

  String get _username {
    final fromWidget = widget.username.trim();
    final fromProfile =
        (widget.profileSummary?['username'] as String? ?? '').trim();
    final raw = fromWidget.isNotEmpty ? fromWidget : fromProfile;
    return raw.startsWith('@') ? raw.substring(1) : raw;
  }

  Future<void> _showMapCredits() async {
    final links = <(String, String)>[
      ('Geoapify', 'https://www.geoapify.com/'),
      ('OpenMapTiles', 'https://openmaptiles.org/'),
      ('OpenStreetMap contributors', 'https://www.openstreetmap.org/copyright'),
    ];
    await showPzSheet<void>(
      context,
      builder: (sheetContext) => SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 2),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Map data credits', style: AppTheme.title2))),
        const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Map tiles and geographic data',
                    style: TextStyle(fontSize: 14, color: AppTheme.muted)))),
        for (final link in links)
          ListTile(
            title: Text(link.$1),
            trailing: const Icon(PhosphorIconsRegular.arrowUpRight,
                size: 17, color: AppTheme.muted),
            onTap: () async {
              final uri = Uri.parse(link.$2);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        const SizedBox(height: 12),
      ])),
    );
  }

  Widget _card({required Widget child, EdgeInsets padding = EdgeInsets.zero}) =>
      PzCard(padding: padding, child: child);

  Widget _divider() => const Divider(
      height: 1, thickness: 1, indent: 16, endIndent: 16, color: pzLine);

  Widget _statDivider() =>
      Container(width: 1, height: 34, color: pzLine, margin: const EdgeInsets.symmetric(horizontal: 12));

  Widget _sportRow(String sport, List<String> roles, String? level) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: ShapeDecoration(
              color: AppTheme.lime.withValues(alpha: .12),
              shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(13)),
            ),
            child: Icon(SportSymbol.boldIconFor(sport), size: 19, color: AppTheme.lime),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sport, style: AppTheme.headline),
              const SizedBox(height: 2),
              Text(roles.isEmpty ? 'Add your role' : roles.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: roles.isEmpty ? AppTheme.muted : AppTheme.primaryText)),
            ]),
          ),
          if (level != null) PzStatusPill(level),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final summary = widget.profileSummary;
    final sports = (summary?['sports'] as List? ?? const []).whereType<String>().toList();
    final days = (summary?['availability'] as List? ?? const []).whereType<String>().toList();
    final bio = (summary?['bio'] as String? ?? '').trim();
    final rolesRaw = summary?['roles'];
    final levelsRaw = summary?['levels'];
    List<String> rolesFor(String sport) => rolesRaw is Map && rolesRaw[sport] is List
        ? (rolesRaw[sport] as List).whereType<String>().toList()
        : const [];
    String? levelFor(String sport) =>
        levelsRaw is Map && levelsRaw[sport] is String ? levelsRaw[sport] as String : null;
    final mode = (summary?['location_mode'] as String?) ?? 'live';
    final homeLabel = summary?['home_label'] as String?;
    final hasHome = summary?['home_location'] is Map;
    final usingHome = mode == 'home' && hasHome;
    final canEdit = widget.api != null;
    final handle = _username;
    final stats = _stats;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator.adaptive(
        color: AppTheme.lime,
        onRefresh: _loadStats,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.fromLTRB(20, 16, 20, widget.navigationSpace + 24),
          children: [
            Row(children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Profile', style: AppTheme.screenTitle(context)),
                ),
              ),
              if (canEdit)
                NativeGlassButton(
                  icon: PhosphorIconsBold.pencilSimple,
                  label: 'Edit profile',
                  iconSize: 17,
                  onTap: widget.onEditPreferences,
                ),
            ]),
            const SizedBox(height: 22),
            Row(children: [
              if (widget.photo != null)
                ProfilePhotoEditor(
                    controller: widget.photo!,
                    name: widget.name,
                    enabled: !widget.isSigningOut,
                    compact: true)
              else
                ProfileAvatar(name: widget.name, size: 88),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.title2),
                  if (handle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('@$handle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, color: AppTheme.muted)),
                  ],
                ]),
              ),
            ]),
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(bio, style: AppTheme.bodyText.copyWith(color: const Color(0xE6FFFFFF))),
            ],
            const SizedBox(height: 18),
            _card(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(children: [
                Expanded(child: PzStat(value: stats == null ? '–' : '${stats.played}', label: 'Played')),
                _statDivider(),
                Expanded(child: PzStat(value: stats == null ? '–' : '${stats.upcoming}', label: 'Upcoming')),
                _statDivider(),
                Expanded(child: PzStat(value: stats == null ? '–' : '${stats.hosting}', label: 'Hosting')),
              ]),
            ),
            const SizedBox(height: 28),
            PzSectionTitle('Sports and roles',
                trailing: canEdit
                    ? TextButton(
                        onPressed: widget.onEditPreferences,
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.lime,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(44, 32)),
                        child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w700)))
                    : null),
            const SizedBox(height: 10),
            _card(
              child: sports.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Add the sports you play to find your people.',
                          style: TextStyle(color: AppTheme.muted)))
                  : Column(children: [
                      for (var i = 0; i < sports.length; i++) ...[
                        if (i > 0) _divider(),
                        _sportRow(sports[i], rolesFor(sports[i]), levelFor(sports[i])),
                      ],
                      _divider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Row(children: [
                          const Icon(PhosphorIconsRegular.calendarBlank, size: 17, color: AppTheme.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                days.isEmpty
                                    ? 'Available any day'
                                    : 'Available ${days.map((d) => d.substring(0, 3)).join(', ')}',
                                style: const TextStyle(fontSize: 14)),
                          ),
                        ]),
                      ),
                    ]),
            ),
            const SizedBox(height: 28),
            const PzSectionTitle('Find games near'),
            const SizedBox(height: 10),
            _card(
              child: Column(children: [
                MergeSemantics(
                  child: PzPressable(
                    scale: .985,
                    haptic: false,
                    onTap: widget.onLocationModeChanged == null
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            widget.onLocationModeChanged!(usingHome ? 'live' : 'home');
                          },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 40,
                          height: 40,
                          decoration: ShapeDecoration(
                            color: usingHome
                                ? AppTheme.lime.withValues(alpha: .14)
                                : AppTheme.surfaceHighest,
                            shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(13)),
                          ),
                          child: Icon(PhosphorIconsFill.house,
                              size: 18,
                              color: usingHome ? AppTheme.lime : AppTheme.muted),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Default location', style: AppTheme.headline),
                            const SizedBox(height: 2),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                usingHome
                                    ? 'On · games near ${homeLabel ?? 'your saved place'}'
                                    : hasHome
                                        ? 'Off · using your live location'
                                        : 'Off · turn on to pick a place',
                                key: ValueKey(usingHome),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.footnote,
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          value: usingHome,
                          activeTrackColor: AppTheme.lime,
                          activeThumbColor: Colors.white,
                          onChanged: widget.onLocationModeChanged == null
                              ? null
                              : (on) {
                                  HapticFeedback.selectionClick();
                                  widget.onLocationModeChanged!(on ? 'home' : 'live');
                                },
                        ),
                      ]),
                    ),
                  ),
                ),
                if (hasHome && widget.onSetHome != null) ...[
                  _divider(),
                  PzPressable(
                    scale: .985,
                    onTap: widget.onSetHome,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                      child: Row(children: [
                        const Text('Location', style: AppTheme.subhead),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(homeLabel ?? 'Saved location',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: AppTheme.footnote),
                        ),
                        const SizedBox(width: 6),
                        const Icon(PhosphorIconsBold.caretRight, size: 13, color: AppTheme.muted),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 28),
            _card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.mapTrifold, color: AppTheme.primaryText),
                  title: const Text('Map data credits', style: AppTheme.bodyText),
                  trailing: const Icon(PhosphorIconsRegular.arrowUpRight, size: 16, color: AppTheme.muted),
                  onTap: _showMapCredits,
                ),
                _divider(),
                ListTile(
                  leading: Icon(PhosphorIconsRegular.signOut,
                      color: widget.isSigningOut ? AppTheme.muted : AppTheme.destructive),
                  title: Text(widget.isSigningOut ? 'Signing out…' : 'Sign out',
                      style: TextStyle(
                          fontSize: 15,
                          color: widget.isSigningOut ? AppTheme.muted : AppTheme.destructive)),
                  onTap: widget.isSigningOut ? null : widget.onSignOut,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
