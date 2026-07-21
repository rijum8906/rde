import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerLow
            : colorScheme.surfaceContainerLowest,
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
          const _SidebarHeader(),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _sections.length,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              itemBuilder: (context, sectionIndex) {
                final section = _sections[sectionIndex];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (section.title != null) ...[
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
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatefulWidget {
  const _SidebarHeader();

  @override
  State<_SidebarHeader> createState() => _SidebarHeaderState();
}

class _SidebarHeaderState extends State<_SidebarHeader> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 32, right: 24, bottom: 16),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Row(
          children: [
            RepaintBoundary(
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
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
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
            ),
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
  final VoidCallback onTap;

  const _SidebarItemWidget({
    required this.item,
    required this.isSelected,
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

    final Color textColor = widget.isSelected
        ? colorScheme.onSecondaryContainer
        : (_isHovered ? colorScheme.onSurface : colorScheme.onSurfaceVariant);

    final Color iconColor = widget.isSelected
        ? colorScheme.onSecondaryContainer
        : (_isHovered ? colorScheme.primary : colorScheme.onSurfaceVariant);

    final Color backgroundColor = widget.isSelected
        ? colorScheme.secondaryContainer
        : (_isHovered
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
              : Colors.transparent);

    final double translationX = _isHovered && !widget.isSelected ? 4.0 : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: RepaintBoundary(
          child: AnimatedSlide(
            offset: Offset(translationX / 280, 0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(28),
              hoverColor: Colors.transparent,
              splashColor: colorScheme.primary.withValues(alpha: 0.1),
              highlightColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: [
                    AnimatedScale(
                      scale: widget.isSelected
                          ? 1.05
                          : (_isHovered ? 1.02 : 1.0),
                      duration: const Duration(milliseconds: 200),
                      child: Icon(widget.item.icon, color: iconColor, size: 20),
                    ),
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
                    if (widget.isSelected)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
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
