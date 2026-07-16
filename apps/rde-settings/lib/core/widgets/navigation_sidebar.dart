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

  const SidebarSection({
    this.title,
    required this.items,
  });
}

class NavigationSidebar extends StatelessWidget {
  final String currentPath;

  const NavigationSidebar({
    super.key,
    required this.currentPath,
  });

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
        SidebarItem(
          title: 'Wi-Fi',
          icon: Icons.wifi,
          path: '/wifi',
        ),
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
        SidebarItem(
          title: 'Display',
          icon: Icons.monitor,
          path: '/display',
        ),
        SidebarItem(
          title: 'Audio I/O',
          icon: Icons.volume_up,
          path: '/audio_io',
        ),
        SidebarItem(
          title: 'Keyboard',
          icon: Icons.keyboard,
          path: '/keyboard',
        ),
        SidebarItem(
          title: 'Pointer',
          icon: Icons.mouse,
          path: '/pointer',
        ),
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
        SidebarItem(
          title: 'About RDE',
          icon: Icons.info,
          path: '/about_rde',
        ),
        SidebarItem(
          title: 'Environment',
          icon: Icons.settings_applications,
          path: '/environment',
        ),
        SidebarItem(
          title: 'Daemons',
          icon: Icons.dns,
          path: '/daemons',
        ),
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[50],
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 40, right: 24, bottom: 20),
            child: Row(
              children: [
                Icon(
                  Icons.settings,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Settings',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _sections.length,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              itemBuilder: (context, sectionIndex) {
                final section = _sections[sectionIndex];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (section.title != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                        child: Text(
                          section.title!.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                    ...section.items.map((item) {
                      final isSelected = currentPath == item.path ||
                          (item.path == '/wifi' && currentPath == '/');

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: InkWell(
                          onTap: () {
                            if (!isSelected) {
                              context.go(item.path);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      color: isSelected
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
