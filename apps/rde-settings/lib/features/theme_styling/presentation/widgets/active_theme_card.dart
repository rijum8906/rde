import 'package:flutter/material.dart';
import 'package:core/theme.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_catalog.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/appearance.dart';

/// Card showing the currently active theme: its identity, description,
/// the light/dark switch, and its author/license footer.
///
/// Layout mirrors the Bluetooth/Wi-Fi cards: a rounded badge on the left,
/// a title + subtitle stack, and the card-level actions grouped below.
class ActiveThemeCard extends StatelessWidget {
  const ActiveThemeCard({super.key, required this.state});

  final ThemeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final catalog = state.catalog!;
    final info = state.activeTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IdentityRow(catalog: catalog, info: info),
            if (info != null && info.description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                info.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Divider(height: 32),
            Text(
              'Appearance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Switches every themed application on the desktop, and this '
              'settings app with it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppearanceOption(
                    label: 'Light',
                    icon: Icons.light_mode,
                    mode: AppearanceMode.light,
                    selected: catalog.mode == AppearanceMode.light,
                    enabled: !state.isBusy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppearanceOption(
                    label: 'Dark',
                    icon: Icons.dark_mode,
                    mode: AppearanceMode.dark,
                    selected: catalog.mode == AppearanceMode.dark,
                    enabled: !state.isBusy,
                  ),
                ),
              ],
            ),
            if (info != null &&
                (info.author != null || info.license != null)) ...[
              const Divider(height: 32),
              _MetaRow(info: info),
            ],
          ],
        ),
      ),
    );
  }
}

/// Left badge + title stack + "Active" pill.
///
/// Uses the same 56×56 rounded square as `_AdapterBadge` and `_WifiBadge`
/// so the three surfaces share a visual anchor. The palette glyph is the
/// theme's own badge (the "theme" concept), not a specific role icon.
class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.catalog, required this.info});

  final ThemeCatalog catalog;
  final ThemeManifest? info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 56×56 rounded square, filled with a primary → secondary gradient.
        // The gradient depicts "this is a palette": it shows the two hero
        // roles at once. If the secondary is too close in hue to primary
        // (which happens with some seeds), swap `secondary` for `tertiary`
        // on the second stop — tertiary is usually complementary.
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colorScheme.primary, colorScheme.secondary],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.palette_outlined,
            size: 28,
            // onPrimary is tuned for a primary background; the gradient's
            // left half is primary-dominant, so this is the safest choice
            // for legibility. If your seed produces a very light primary,
            // switch to onPrimaryContainer.
            color: colorScheme.onPrimary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      info?.displayName ?? catalog.currentTheme,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ActivePill(),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${catalog.currentTheme} • org.rde.Theme '
                '${catalog.snapshot.version}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small "Active" pill next to the title. Same shape as the "Connected"
/// pill in `BluetoothDeviceTile`, so the two pages read the same.
class _ActivePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 12, color: colorScheme.onPrimary),
          const SizedBox(width: 4),
          Text(
            'Active',
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer chips: author and license, each on its own outlined pill.
/// Replaces the bare `Row` of `bodySmall` text so the footer reads as a
/// metadata strip rather than a trailing line of prose.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.info});

  final ThemeManifest info;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (info.author != null)
          _MetaChip(icon: Icons.person_outline, text: info.author!),
        if (info.license != null)
          _MetaChip(icon: Icons.description_outlined, text: info.license!),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
