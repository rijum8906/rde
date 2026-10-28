import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rde_settings/features/audio_io/data/datasources/dbus/mpris_proxy.dart';
import 'package:rde_settings/features/audio_io/data/repositories/now_playing_repository_impl.dart';
import 'package:rde_settings/features/audio_io/domain/use_cases/read_now_playing.dart';
import 'package:rde_settings/features/audio_io/domain/use_cases/skip_track.dart';
import 'package:rde_settings/features/audio_io/domain/use_cases/toggle_play_pause.dart';
import 'package:rde_settings/features/audio_io/domain/use_cases/watch_now_playing.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/now_playing_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/now_playing_event.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/now_playing_state.dart';
import 'package:rde_settings/features/audio_io/presentation/widgets/now_playing_slider.dart';

class AudioIoPage extends StatelessWidget {
  const AudioIoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final proxy = MprisProxy();
    final repository = NowPlayingRepositoryImpl(proxy);

    return BlocProvider(
      create: (_) => NowPlayingBloc(
        read: ReadNowPlayingUseCase(repository),
        watch: WatchNowPlayingUseCase(repository),
        togglePlayPause: TogglePlayPauseUseCase(repository),
        skipTrack: SkipTrackUseCase(repository),
      )..add(const NowPlayingInitEvent()),
      child: const AudioIoView(),
    );
  }
}

class AudioIoView extends StatelessWidget {
  const AudioIoView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<NowPlayingBloc, NowPlayingState>(
        builder: (context, state) {
          final bloc = context.read<NowPlayingBloc>();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AudioIoHeader(),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: state.errorMessage!),
                ],
                const SizedBox(height: 28),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: NowPlayingSlider(
                      players: state.players,
                      activeIndex: state.activeIndex,
                      isBusy: state.isBusy,
                      onSelect: (busName) =>
                          bloc.add(SelectPlayerEvent(busName)),
                      onTogglePlayPause: () =>
                          bloc.add(const TogglePlayPauseEvent()),
                      onSkipNext: () => bloc.add(
                        const NowPlayingSkipTrackEvent(SkipDirection.next),
                      ),
                      onSkipPrevious: () => bloc.add(
                        const NowPlayingSkipTrackEvent(SkipDirection.previous),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Audio I/O configuration will be implemented here.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AudioIoHeader extends StatelessWidget {
  const _AudioIoHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Audio I/O',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage audio input/output devices, volume, and effects',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
