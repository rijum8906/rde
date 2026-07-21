import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/about_rde/presentation/bloc/about_rde_bloc.dart';
import 'package:rde_settings/features/about_rde/presentation/bloc/about_rde_event.dart';
import 'package:rde_settings/features/about_rde/presentation/bloc/about_rde_state.dart';

class AboutRdePage extends StatelessWidget {
  const AboutRdePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AboutRdeBloc(),
      child: const AboutRdeView(),
    );
  }
}

class AboutRdeView extends StatelessWidget {
  const AboutRdeView({super.key});

  void _showLogsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('System Core Logs'),
          content: Container(
            width: 500,
            height: 300,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                '[INFO] 20:19:15 supervisor: daemon running healthy\n'
                '[INFO] 20:19:16 dbus-wifi: fetched NM device list [wlan0]\n'
                '[INFO] 20:19:16 brightness: loaded backplate value 65%\n'
                '[INFO] 20:19:17 volume: sync state to hardware device 70%\n'
                '[INFO] 20:20:00 ipc: unix socket server initialized\n'
                '[WARN] 20:20:05 wm-bindings: override sequence "Super+Space" captured\n'
                '[INFO] 20:21:00 daemon: health checks executed. All 4/4 services ok.',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 12,
                  color: Colors.green[400],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close Logs'),
            ),
          ],
        );
      },
    );
  }

  void _showUpdateSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 12),
              Text('System Up to Date'),
            ],
          ),
          content: Text(
            'Your Riju Desktop Environment is running the latest available release (v2.0.1 LTS).',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dismiss'),
            ),
          ],
        );
      },
    ).then((_) {
      // Clear status back to initial
      if (context.mounted) {
        context.read<AboutRdeBloc>().add(const ResetUpdateStatusEvent());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: BlocConsumer<AboutRdeBloc, AboutRdeState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == AboutStatus.success) {
            _showUpdateSuccessDialog(context);
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Title
                Text(
                  'About RDE',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'System information, kernel configurations, releases, and diagnostic logs',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),

                // Main Columns
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    return Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // System card (Left/Top)
                        Expanded(
                          flex: isWide ? 4 : 0,
                          child: Column(
                            children: [
                              _buildSystemMainCard(context, state),
                              const SizedBox(height: 24),
                              _buildUpdateActionsCard(context, state),
                            ],
                          ),
                        ),
                        if (isWide) const SizedBox(width: 32),
                        if (!isWide) const SizedBox(height: 32),

                        // Detail Specs (Right/Bottom)
                        Expanded(
                          flex: isWide ? 3 : 0,
                          child: _buildDetailsSpecsCard(context),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSystemMainCard(BuildContext context, AboutRdeState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            // Dynamic Rotating System Logo Badge
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) =>
                  context.read<AboutRdeBloc>().add(const RotateLogoEvent(0.25)),
              child: GestureDetector(
                onTap: () => context.read<AboutRdeBloc>().add(
                  const RotateLogoEvent(1.0),
                ),
                child: RepaintBoundary(
                  child: AnimatedRotation(
                    turns: state.logoRotation,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.tertiary],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.blur_on_rounded,
                          size: 56,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Riju Desktop Environment',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 2.0.1 (LTS Release)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'RDE is a lightweight, customizable desktop supervisor daemon and graphical shell ecosystem built for performance and user control.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateActionsCard(BuildContext context, AboutRdeState state) {
    final theme = Theme.of(context);
    final isChecking = state.status == AboutStatus.checking;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maintenance & Diagnostics',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isChecking
                        ? null
                        : () => context.read<AboutRdeBloc>().add(
                            const TriggerUpdateCheckEvent(),
                          ),
                    icon: isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.system_update_alt_rounded),
                    label: Text(
                      isChecking ? 'Checking Server...' : 'Check for Updates',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showLogsDialog(context),
                    icon: const Icon(Icons.terminal),
                    label: const Text('View Core Logs'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSpecsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specifications',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSpecRow(context, 'Kernel Version', 'Linux 6.2.0-37-generic'),
            const Divider(height: 24),
            _buildSpecRow(
              context,
              'CPU Architecture',
              'x86_64 (64-bit AMD/Intel)',
            ),
            const Divider(height: 24),
            _buildSpecRow(context, 'Supervisor Daemon', 'rde-daemon (Running)'),
            const Divider(height: 24),
            _buildSpecRow(
              context,
              'Display Server',
              'Wayland (Mutter backend)',
            ),
            const Divider(height: 24),
            _buildSpecRow(
              context,
              'Toolkit Version',
              'Flutter 3.16 (Dart 3.2)',
            ),
            const Divider(height: 24),
            _buildSpecRow(context, 'Memory Volume', '15.4 GiB Physical Memory'),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(BuildContext context, String title, String value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
