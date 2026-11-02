import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:rde_settings/core/widgets/silky_scroll_config.dart';
import 'package:rde_settings/features/display/data/datasources/dbus/brightness_proxy.dart';
import 'package:rde_settings/features/display/data/repositories/brightness_repository_impl.dart';
import 'package:rde_settings/features/display/presentation/bloc/brightness_bloc.dart';
import 'package:rde_settings/features/display/presentation/bloc/brightness_event.dart';
import 'package:rde_settings/features/display/presentation/widgets/brightness_card.dart';

/// Display settings, backed by `org.rde.Brightness`.
class DisplayPage extends StatelessWidget {
  const DisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = BrightnessRepositoryImpl(BrightnessProxy());

    return BlocProvider(
      create: (_) =>
          BrightnessBloc(repository: repository)
            ..add(const BrightnessInitEvent()),
      child: const _DisplayView(),
    );
  }
}

class _DisplayView extends StatelessWidget {
  const _DisplayView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SilkySingleChildScrollView(
        silkyConfig: appSilkyScroll,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _DisplayHeader(),
            SizedBox(height: 28),
            BrightnessCard(),
            SizedBox(height: 24),
            _PendingDisplaySettings(),
          ],
        ),
      ),
    );
  }
}

class _DisplayHeader extends StatelessWidget {
  const _DisplayHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Display',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Adjust screen brightness, resolution, refresh rate, and night light',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Placeholder for the display controls that have no service yet.
class _PendingDisplaySettings extends StatelessWidget {
  const _PendingDisplaySettings();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resolution & night light',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Resolution, refresh rate, and night light will be configured '
              'here once the display service exposes them.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
