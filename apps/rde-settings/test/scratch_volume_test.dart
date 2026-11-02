import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/audio_io/domain/entities/master_volume.dart';
import 'package:rde_settings/features/audio_io/domain/repositories/master_volume_repository.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_bloc.dart';
import 'package:rde_settings/features/audio_io/presentation/bloc/volume_event.dart';

class _Volume implements MasterVolumeRepository {
  @override
  Future<Either<Failure, MasterVolume>> read() async => const Right(
    MasterVolume(
      volume: 42,
      muted: false,
      step: 5,
      minVolume: 0,
      maxVolume: 100,
    ),
  );

  @override
  Future<Either<Failure, void>> setVolume(int value) async => const Right(null);

  @override
  Future<Either<Failure, void>> setMicrophoneVolume(int value) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> setMuted(bool muted) async => const Right(null);

  @override
  Stream<void> watchChanges() => const Stream<void>.empty();
}

void main() {
  group('volume widget', () {
    late VolumeBloc bloc;
    setUp(() => bloc = VolumeBloc(repository: _Volume()));

    testWidgets('setUp-created bloc loads', (tester) async {
      await tester.pumpWidget(
        BlocProvider.value(
          value: bloc,
          child: const MaterialApp(home: Scaffold(body: Text('x'))),
        ),
      );
      bloc.add(const VolumeInitEvent());
      await tester.pumpAndSettle();
      print(
        'setUp bloc: status=${bloc.state.status} '
        'master=${bloc.state.master?.volume}',
      );
    });
  });

  testWidgets('in-test bloc loads', (tester) async {
    final bloc = VolumeBloc(repository: _Volume());
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: const MaterialApp(home: Scaffold(body: Text('x'))),
      ),
    );
    bloc.add(const VolumeInitEvent());
    await tester.pumpAndSettle();
    print(
      'in-test bloc: status=${bloc.state.status} '
      'master=${bloc.state.master?.volume}',
    );
  });
}
