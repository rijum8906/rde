import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/core/widgets/loading_indicator.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_bloc.dart';
import 'package:rde_settings/features/wifi/presentation/bloc/wifi_event.dart';

class WifiHeader extends StatelessWidget {
  const WifiHeader({super.key, required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isWifiEnabled = context.select<WifiBloc, bool>(
      (bloc) => bloc.state.isWifiEnabled,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wi-Fi Settings',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage wireless connections and networks',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (isWifiEnabled)
          IconButton.filledTonal(
            onPressed: isLoading
                ? null
                : () => context.read<WifiBloc>().add(const ScanNetworksEvent()),
            icon: isLoading
                ? const RdeLoadingIndicator(size: 18)
                : const Icon(Icons.refresh),
            tooltip: 'Rescan Networks',
          ),
      ],
    );
  }
}
