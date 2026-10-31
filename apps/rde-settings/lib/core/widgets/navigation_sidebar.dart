import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rde_settings/core/widgets/silky_scroll_config.dart';
import 'package:silky_scroll/silky_scroll.dart';

class SidebarItem {
  final String title;
  final IconData icon;
  final String path;

  const SidebarItem({
    required this.title,
    required this.icon,
    required this.path,
  });
}

class SidebarSection {
  final String? title;
  final List<SidebarItem> items;

  const SidebarSection({this.title, required this.items});
}

class NavigationSidebar extends StatelessWidget {
  /// Width of the rail with its labels.
  static const double _expandedWidth = 280;

  /// Width of the icon-only rail.
  static const double _collapsedWidth = 88;

  /// Window width below which the rail shows icons only.
  ///
  /// The rail gives up its labels before the page has to squeeze, which keeps
  /// the two-column pages usable on a small window.
  static const double _collapseBreakpoint = 1000;

  final String currentPath;

  const NavigationSidebar({super.key, required this.currentPath});

  static const List<SidebarSection> _sections = [
    SidebarSection(
      items: [
        SidebarItem(
          title: 'Dashboard',
          icon: Icons.dashboard,
          path: '/dashboard',
        ),
      ],
    ),
    SidebarSection(
      title: 'Connectivity',
      items: [
        SidebarItem(title: 'Wi-Fi', icon: Icons.wifi, path: '/wifi'),
        SidebarItem(
          title: 'Bluetooth',
          icon: Icons.bluetooth,
          path: '/bluetooth',
        ),
        SidebarItem(
          title: 'Network Proxy',
          icon: Icons.vpn_lock,
          path: '/network_proxy',
        ),
      ],
    ),
    SidebarSection(
      title: 'Personalization',
      items: [
        SidebarItem(
          title: 'Theme & Styling',
          icon: Icons.palette,
          path: '/theme_styling',
        ),
        SidebarItem(
          title: 'Wallpaper',
          icon: Icons.wallpaper,
          path: '/wallpaper',
        ),
        SidebarItem(
          title: 'Typography',
          icon: Icons.font_download,
          path: '/typography',
        ),
        SidebarItem(
          title: 'Interface Assets',
          icon: Icons.extension,
          path: '/interface_assets',
        ),
      ],
    ),
    SidebarSection(
      title: 'Hardware & Inputs',
      items: [
        SidebarItem(title: 'Display', icon: Icons.monitor, path: '/display'),
        SidebarItem(
          title: 'Audio I/O',
          icon: Icons.volume_up,
          path: '/audio_io',
        ),
        SidebarItem(title: 'Keyboard', icon: Icons.keyboard, path: '/keyboard'),
        SidebarItem(title: 'Pointer', icon: Icons.mouse, path: '/pointer'),
        SidebarItem(
          title: 'Window Manager Bindings',
          icon: Icons.keyboard_command_key,
          path: '/wm_bindings',
        ),
      ],
    ),
    SidebarSection(
      title: 'Power & Performance',
      items: [
        SidebarItem(
          title: 'Battery Health',
          icon: Icons.battery_charging_full,
          path: '/battery_health',
        ),
        SidebarItem(
          title: 'Sleep States',
          icon: Icons.brightness_medium,
          path: '/sleep_states',
        ),
        SidebarItem(
          title: 'Hardware Triggers',
          icon: Icons.power,
          path: '/hardware_triggers',
        ),
      ],
    ),
    SidebarSection(
      title: 'Security & Accounts',
      items: [
        SidebarItem(
          title: 'Lock Screen',
          icon: Icons.lock,
          path: '/lock_screen',
        ),
        SidebarItem(
          title: 'User Profile',
          icon: Icons.person,
          path: '/user_profile',
        ),
        SidebarItem(
          title: 'System Privacy',
          icon: Icons.security,
          path: '/system_privacy',
        ),
      ],
    ),
    SidebarSection(
      title: 'Core System (Advanced)',
      items: [
        SidebarItem(title: 'About RDE', icon: Icons.info, path: '/about_rde'),
        SidebarItem(
          title: 'Environment',
          icon: Icons.settings_applications,
          path: '/environment',
        ),
        SidebarItem(title: 'Daemons', icon: Icons.dns, path: '/daemons'),
        SidebarItem(
          title: 'Engine Overrides',
          icon: Icons.developer_mode,
          path: '/engine_overrides',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Step 0: A narrow window collapses the rail to its icons, so the page
    // keeps the width it needs for its own layout.
    final collapsed = MediaQuery.sizeOf(context).width < _collapseBreakpoint;

    // Step 1: One surface color is used by both the rail and the fade that
    // covers its bottom edge, so the fade stays invisible over the background.
    final sidebarColor = theme.colorScheme.surfaceContainerLow;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: collapsed ? _collapsedWidth : _expandedWidth,
      decoration: BoxDecoration(
        color: sidebarColor,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarHeader(collapsed: collapsed),
          const Divider(),
          Expanded(
            // Step 2: The rail holds every destination plus a fade over its
            // bottom edge, which hints that more sections continue below.
            child: Stack(
              children: [
                SilkyListView.builder(
                  silkyConfig: appSilkyScroll,
                  itemCount: _sections.length,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  itemBuilder: (context, sectionIndex) {
                    final section = _sections[sectionIndex];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (section.title != null && !collapsed) ...[
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 24,
                              top: 18,
                              bottom: 6,
                            ),
                            child: Text(
                              section.title!.toUpperCase(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                                letterSpacing: 1.3,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                        ...section.items.map((item) {
                          final isSelected =
                              currentPath == item.path ||
                              (item.path == '/wifi' && currentPath == '/');

                          return _SidebarItemWidget(
                            item: item,
                            isSelected: isSelected,
                            collapsed: collapsed,
                            onTap: () {
                              if (!isSelected) {
                                context.go(item.path);
                              }
                            },
                          );
                        }),
                      ],
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            sidebarColor.withValues(alpha: 0),
                            sidebarColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatefulWidget {
  const _SidebarHeader({required this.collapsed});

  /// Whether the rail is collapsed to icons.
  final bool collapsed;

  @override
  State<_SidebarHeader> createState() => _SidebarHeaderState();
}

class _SidebarHeaderState extends State<_SidebarHeader> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Widget badge = RepaintBoundary(
      child: AnimatedRotation(
        turns: _isHovered ? 0.25 : 0.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isHovered
                ? colorScheme.primaryContainer
                : colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.settings_outlined,
            size: 24,
            color: _isHovered
                ? colorScheme.onPrimaryContainer
                : colorScheme.primary,
          ),
        ),
      ),
    );

    return Padding(
      padding: widget.collapsed
          ? const EdgeInsets.symmetric(vertical: 24)
          : const EdgeInsets.only(left: 24, top: 32, right: 24, bottom: 16),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        // The brand text does not fit an icon-only rail, so only the badge is
        // kept and the title is dropped.
        child: widget.collapsed
            ? Center(child: badge)
            : Row(
                children: [
                  badge,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Settings',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SidebarItemWidget extends StatefulWidget {
  final SidebarItem item;
  final bool isSelected;

  /// Whether the rail is collapsed to icons.
  final bool collapsed;
  final VoidCallback onTap;

  const _SidebarItemWidget({
    required this.item,
    required this.isSelected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  State<_SidebarItemWidget> createState() => _SidebarItemWidgetState();
}

class _SidebarItemWidgetState extends State<_SidebarItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Step 1: Selection is carried by the primary family, so the active
    // destination wears the accent the user chose instead of Material's
    // default secondary container.
    final Color textColor = widget.isSelected
        ? colorScheme.onPrimaryContainer
        : (_isHovered ? colorScheme.onSurface : colorScheme.onSurfaceVariant);

    final Color iconColor = widget.isSelected
        ? colorScheme.onPrimaryContainer
        : (_isHovered ? colorScheme.primary : colorScheme.onSurfaceVariant);

    // Step 2: Hovering an unselected destination lays an M3 state layer over the
    // rail: a translucent wash of the accent rather than a solid neutral fill.
    final Color backgroundColor = widget.isSelected
        ? colorScheme.primaryContainer
        : (_isHovered
              ? colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent);

    final double translationX = _isHovered && !widget.isSelected ? 4.0 : 0.0;

    final Widget icon = Icon(widget.item.icon, color: iconColor, size: 20);

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 2,
        horizontal: widget.collapsed ? 8 : 12,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: RepaintBoundary(
          child: AnimatedSlide(
            offset: Offset(
              translationX /
                  (widget.collapsed
                      ? NavigationSidebar._collapsedWidth
                      : NavigationSidebar._expandedWidth),
              0,
            ),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(28),
              hoverColor: Colors.transparent,
              splashColor: colorScheme.primary.withValues(alpha: 0.1),
              // Keyboard users tab through the rail, so focus has to be as
              // visible as hover on a pointer-driven desktop.
              focusColor: colorScheme.primary.withValues(alpha: 0.12),
              highlightColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: widget.collapsed
                    ? const EdgeInsets.symmetric(vertical: 12)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisAlignment: widget.collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    // Step 3: The active destination is marked with an accent
                    // rail on its leading edge, the navigation-rail idiom, so
                    // the marker sits where the eye already starts reading.
                    // The rail keeps its width while collapsed, which leaves
                    // the labels of selected and unselected rows aligned.
                    if (!widget.collapsed)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: 4,
                        height: widget.isSelected ? 18 : 0,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    AnimatedScale(
                      scale: widget.isSelected
                          ? 1.05
                          : (_isHovered ? 1.02 : 1.0),
                      duration: const Duration(milliseconds: 200),
                      // An icon-only rail has no label, so the title moves into
                      // a tooltip instead of being lost.
                      child: widget.collapsed
                          ? Tooltip(message: widget.item.title, child: icon)
                          : icon,
                    ),
                    if (!widget.collapsed) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.bodyMedium!.copyWith(
                            fontWeight: widget.isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: textColor,
                          ),
                          child: Text(
                            widget.item.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
