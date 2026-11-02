import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/display/domain/entities/brightness_level.dart';
import 'package:rde_settings/features/display/domain/repositories/brightness_repository.dart';
import 'package:rde_settings/features/display/presentation/bloc/brightness_bloc.dart';
import 'package:rde_settings/features/display/presentation/bloc/brightness_event.dart';
import 'package:rde_settings/features/display/presentation/bloc/brightness_state.dart';

/// In-memory `org.rde.Brightness` that records every write.
class _FakeBrightnessRepository implements BrightnessRepository {
  _FakeBrightnessRepository({this.percent = 40});

  int percent;
  bool failReads = false;
  bool failWrites = false;

  final List<int> setValues = [];
  final List<int> increases = [];
  final List<int> decreases = [];

  BrightnessLevel get _level => BrightnessLevel(
    percent: percent,
    raw: percent,
    max: 100,
    version: 'test',
  );

  @override
  Future<Either<Failure, BrightnessLevel>> read() async {
    return failReads ? Left(Failure('service unavailable')) : Right(_level);
  }

  @override
  Future<Either<Failure, void>> setPercent(int value) async {
    setValues.add(value);
    if (failWrites) {
      return Left(Failure('service rejected the write'));
    }
    percent = value.clamp(0, 100).toInt();
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> increase(int step) async {
    increases.add(step);
    if (failWrites) {
      return Left(Failure('service rejected the write'));
    }
    percent = (percent + step).clamp(0, 100).toInt();
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> decrease(int step) async {
    decreases.add(step);
    if (failWrites) {
      return Left(Failure('service rejected the write'));
    }
    percent = (percent - step).clamp(0, 100).toInt();
    return const Right(null);
  }

  @override
  Stream<void> watchChanges() => const Stream<void>.empty();
}

void main() {
  test('init reads the level the service reports', () async {
    final repository = _FakeBrightnessRepository(percent: 55);
    final bloc = BrightnessBloc(repository: repository);

    bloc.add(const BrightnessInitEvent());
    final loaded = await bloc.stream.firstWhere(
      (state) => state.status == BrightnessStatus.success,
    );

    expect(loaded.level!.percent, 55);
    expect(loaded.level!.raw, 55);
    expect(loaded.level!.max, 100);
    expect(loaded.canChange, isTrue);

    await bloc.close();
  });

  test('a failed read leaves the service unavailable', () async {
    final repository = _FakeBrightnessRepository()..failReads = true;
    final bloc = BrightnessBloc(repository: repository);

    bloc.add(const BrightnessInitEvent());
    final failed = await bloc.stream.firstWhere(
      (state) => state.status == BrightnessStatus.failure,
    );

    expect(failed.level, isNull);
    expect(failed.canChange, isFalse);
    expect(failed.errorMessage, contains('service unavailable'));

    await bloc.close();
  });

  test('setting a percentage writes and refreshes from the service', () async {
    final repository = _FakeBrightnessRepository();
    final bloc = BrightnessBloc(repository: repository);

    bloc.add(const BrightnessInitEvent());
    await bloc.stream.firstWhere(
      (state) => state.status == BrightnessStatus.success,
    );

    final applied = bloc.stream.firstWhere(
      (state) => state.level?.percent == 70 && !state.isBusy,
    );
    bloc.add(const BrightnessSetEvent(70));

    expect((await applied).level!.percent, 70);
    expect(repository.setValues, [70]);

    await bloc.close();
  });

  test('stepped changes use the service methods', () async {
    final repository = _FakeBrightnessRepository();
    final bloc = BrightnessBloc(repository: repository);

    bloc.add(const BrightnessInitEvent());
    await bloc.stream.firstWhere(
      (state) => state.status == BrightnessStatus.success,
    );

    final raised = bloc.stream.firstWhere(
      (state) => state.level?.percent == 50 && !state.isBusy,
    );
    bloc.add(const BrightnessIncreaseEvent(10));
    await raised;

    final lowered = bloc.stream.firstWhere(
      (state) => state.level?.percent == 30 && !state.isBusy,
    );
    bloc.add(const BrightnessDecreaseEvent(20));
    await lowered;

    expect(repository.increases, [10]);
    expect(repository.decreases, [20]);

    await bloc.close();
  });

  test(
    'a rejected write keeps the service level and reports the error',
    () async {
      final repository = _FakeBrightnessRepository()..failWrites = true;
      final bloc = BrightnessBloc(repository: repository);

      bloc.add(const BrightnessInitEvent());
      await bloc.stream.firstWhere(
        (state) => state.status == BrightnessStatus.success,
      );

      final failed = bloc.stream.firstWhere(
        (state) => state.errorMessage != null,
      );
      bloc.add(const BrightnessSetEvent(20));
      final state = await failed;

      expect(repository.setValues, [20]);
      expect(state.level!.percent, 40);
      expect(state.errorMessage, contains('rejected the write'));

      await bloc.close();
    },
  );
}
