import 'package:core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:silky_scroll/silky_scroll.dart';
import 'package:rde_launcher/features/app_search/presentation/bloc/app_search_bloc.dart';
import 'package:rde_launcher/features/app_search/presentation/bloc/app_search_state.dart';
import 'package:rde_launcher/features/app_search/presentation/widgets/application_list_tile.dart';
import 'package:rde_launcher/features/app_search/presentation/widgets/category_filter_bar.dart';
import 'package:rde_launcher/features/app_search/presentation/widgets/launcher_footer.dart';
import 'package:rde_launcher/features/app_search/presentation/widgets/launcher_header.dart';
import 'package:rde_launcher/features/app_search/presentation/widgets/launcher_search_field.dart';
import 'package:rde_launcher/features/app_search/presentation/widgets/launcher_states.dart';
import 'package:rde_launcher/features/app_search/presentation/widgets/staggered_appear.dart';

/// # Launcher Page
///
/// Presents the centered launcher surface: search entry point, category
/// filters, keyboard-navigable application results, and launch feedback.
class LauncherPage extends StatefulWidget {
  /// Creates the launcher page.
  ///
  /// # Parameters
  /// - [onClose]: invoked by Escape when no search or category filter is
  ///   active, so the host can dismiss the launcher window.
  const LauncherPage({this.onClose, super.key});

  /// Invoked by Escape when no search or category filter is active.
  final VoidCallback? onClose;

  @override
  State<LauncherPage> createState() => _LauncherPageState();
}

class _LauncherPageState extends State<LauncherPage>
    with SingleTickerProviderStateMixin {
  static const double _itemExtent = 72;

  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchFocus = FocusNode(onKeyEvent: _handleSearchKey);
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    // Step 1: Reveal the whole surface once, so opening the launcher reads as
    // a window appearing rather than a fully painted frame.
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Handles launcher shortcuts before the text field consumes them.
  KeyEventResult _handleSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final bloc = context.read<AppSearchBloc>();
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        bloc.moveSelection(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        bloc.moveSelection(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        bloc.launch();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        // Step 1: Clear an active search first, then dismiss the launcher once
        // there is nothing left to clear.
        final hasFilters =
            _searchController.text.isNotEmpty || bloc.state.category.isNotEmpty;
        if (hasFilters) {
          _clearSearch();
        } else {
          widget.onClose?.call();
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<AppSearchBloc>().clearFilters();
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final motion = RdeThemeMotion.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    colors.primary.withValues(alpha: 0.05),
                    colors.surface,
                  ),
                  colors.surface,
                  Color.alphaBlend(
                    colors.tertiary.withValues(alpha: 0.04),
                    colors.surface,
                  ),
                ],
              ),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.14),
                  blurRadius: 38,
                  spreadRadius: -4,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                children: [
                  _AmbientGlow(colors: colors),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
                    child: BlocBuilder<AppSearchBloc, AppSearchState>(
                      builder: (context, state) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LauncherHeader(
                            applicationCount: state.applications.length,
                            isLoading: state.isLoading,
                            onRefresh: context.read<AppSearchBloc>().load,
                          ),
                          const SizedBox(height: 18),
                          LauncherSearchField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onChanged: context.read<AppSearchBloc>().search,
                          ),
                          const SizedBox(height: 12),

                          // Step 1: Category filters collapse away when the
                          // catalog has no recognizable categories.
                          AnimatedSize(
                            duration: motion.short,
                            curve: motion.standard,
                            alignment: Alignment.topCenter,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CategoryFilterBar(
                                  categories: state.availableCategories,
                                  selected: state.category,
                                  onSelected: context
                                      .read<AppSearchBloc>()
                                      .filterCategory,
                                ),
                                if (state.availableCategories.isNotEmpty)
                                  const SizedBox(height: 14),
                              ],
                            ),
                          ),

                          // Step 2: Result summary with an animated count.
                          _ResultSummary(state: state),
                          const SizedBox(height: 8),
                          Expanded(child: _buildResults(state)),
                          const SizedBox(height: 12),
                          LauncherFooter(
                            resultCount: state.results.length,
                            hasQuery:
                                state.query.isNotEmpty ||
                                state.category.isNotEmpty,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the loading, error, empty, or result-list body.
  Widget _buildResults(AppSearchState state) {
    if (state.isLoading && state.applications.isEmpty) {
      return const LauncherLoading();
    }
    if (state.error != null && state.results.isEmpty) {
      return LauncherMessage(
        icon: Icons.warning_amber_rounded,
        title: 'Applications unavailable',
        message: state.error!,
        actionLabel: 'Scan again',
        onAction: context.read<AppSearchBloc>().load,
      );
    }
    if (state.results.isEmpty) {
      final hasFilters = state.query.isNotEmpty || state.category.isNotEmpty;
      return LauncherMessage(
        icon: Icons.search_off_rounded,
        title: hasFilters ? 'No matches' : 'Nothing installed yet',
        message: hasFilters
            ? 'No application matches the current search and filter.'
            : 'No desktop applications were found in the XDG application menu.',
        actionLabel: hasFilters ? 'Clear filters' : 'Rescan',
        onAction: hasFilters
            ? _clearSearch
            : context.read<AppSearchBloc>().load,
      );
    }

    final selected = state.selectedApplication;

    // Step 1: SilkyScroll interpolates wheel input, so a single notch glides
    // to its target instead of jumping the row list.
    return SilkyScroll(
      silkyScrollDuration: const Duration(milliseconds: 320),
      animationCurve: Curves.easeOutCubic,
      builder: (context, controller, physics, pointerDeviceKind) {
        return ListView.builder(
          controller: controller,
          physics: physics,
          itemExtent: _itemExtent,
          padding: EdgeInsets.zero,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          itemCount: state.results.length,
          itemBuilder: (context, index) {
            final application = state.results[index];
            return StaggeredAppear(
              key: ValueKey(application.id),
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: ApplicationListTile(
                  application: application,
                  selected: index == state.selectedIndex,
                  launching:
                      state.isLaunching && selected?.id == application.id,
                  onHover: () => context.read<AppSearchBloc>().select(index),
                  onTap: () =>
                      context.read<AppSearchBloc>().launch(application),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Section label and animated match count above the result list.
class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.state});

  final AppSearchState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final label = state.category.isNotEmpty
        ? state.category.toUpperCase()
        : state.query.isNotEmpty
        ? 'SEARCH RESULTS'
        : 'ALL APPLICATIONS';

    return Row(
      children: [
        AnimatedSwitcher(
          duration: RdeThemeMotion.of(context).short,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Text(
            label,
            key: ValueKey(label),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: RdeThemeMotion.of(context).short,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Text(
            '${state.results.length}',
            key: ValueKey(state.results.length),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Soft layered color wash behind the launcher content.
class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _GlowCircle(
              size: 300,
              color: colors.primary.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _GlowCircle(
              size: 280,
              color: colors.tertiary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blurred radial color circle used by the ambient background.
class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
