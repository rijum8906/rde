import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// ...bloc/state/event imports...
import 'package:rde_settings/core/utils/seed_mode.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_bloc.dart';
import 'package:rde_settings/features/theme_styling/presentation/bloc/theme_state.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/active_theme_card.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/dynamic_tree_card.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/installed_themes_card.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/preview_card.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/theme_error_banner.dart';
import 'package:rde_settings/features/theme_styling/presentation/widgets/theme_styling_header.dart';
import '../widgets/theme_unavailable_body.dart';

class ThemeStylingView extends StatefulWidget {
  const ThemeStylingView({super.key});
  @override
  State<ThemeStylingView> createState() => _ThemeStylingViewState();
}

class _ThemeStylingViewState extends State<ThemeStylingView> {
  SeedMode _seedMode = SeedMode.dynamic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, state) {
          if (!state.hasCatalog) {
            return ThemeUnavailableBody(state: state);
          }
          return _buildContent(context, state);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeState state) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ThemeStylingHeader(state: state),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 20),
            ThemeErrorBanner(message: state.errorMessage!),
          ],
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 850;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isWide ? 4 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ActiveThemeCard(state: state),
                        const SizedBox(height: 28),
                        DynamicThemeCard(
                          state: state,
                          seedMode: _seedMode,
                          onSeedModeChanged: (m) =>
                              setState(() => _seedMode = m),
                        ),
                        const SizedBox(height: 28),
                        InstalledThemesCard(state: state),
                      ],
                    ),
                  ),
                  if (isWide) const SizedBox(width: 32),
                  if (!isWide) const SizedBox(height: 32),
                  Expanded(
                    flex: isWide ? 3 : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Preview',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        PreviewCard(state: state),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
