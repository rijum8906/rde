import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/display/domain/entities/brightness_level.dart';
import 'package:rde_settings/features/display/domain/repositories/brightness_repository.dart';
import 'package:rde_settings/features/display/presentation/bloc/brightness_bloc.dart';
import 'package:rde_settings/features/display/presentation/bloc/brightness_event.dart';
import 'package:rde_settings/features/display/presentation/widgets/brightness_card.dart';

/// In-memory `org.rde.Brightness` for the card tests.
class _FakeBrightnessRepository implements BrightnessRepository {
  int percent = 55;
  bool failReads = false;

  final List<int> increases = [];

  @override
  Future<Either<Failure, BrightnessLevel>> read() async {
    if (failReads) {
      return Left(Failure('service unavailable'));
    }

    return Right(
      BrightnessLevel(
        percent: percent,
        raw: percent,
        max: 100,
        version: 'test',
      ),
    );
  }

  @override
  Future<Either<Failure, void>> setPercent(int value) async {
    percent = value.clamp(0, 100).toInt();
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> increase(int step) async {
    increases.add(step);
    percent = (percent + step).clamp(0, 100).toInt();
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> decrease(int step) async {
    percent = (percent - step).clamp(0, 100).toInt();
    return const Right(null);
  }

  @override
  Stream<void> watchChanges() => const Stream<void>.empty();
}

Future<void> _pumpCard(
  WidgetTester tester,
  _FakeBrightnessRepository repository,
) async {
  final bloc = BrightnessBloc(repository: repository);

  // Closing a bloc awaits stream teardown, which never completes under the
  // fake clock a test body runs in, so it is left to the teardown phase.
  addTearDown(bloc.close);

  await tester.pumpWidget(
    BlocProvider.value(
      value: bloc,
      child: const MaterialApp(home: Scaffold(body: BrightnessCard())),
    ),
  );
  bloc.add(const BrightnessInitEvent());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the level the service reports', (tester) async {
    final repository = _FakeBrightnessRepository();
    await _pumpCard(tester, repository);

    expect(find.text('Brightness'), findsOneWidget);
    expect(find.text('55%'), findsOneWidget);
    expect(find.text('Raw 55 of 100'), findsOneWidget);
    expect(find.byTooltip('Dim'), findsOneWidget);
    expect(find.byTooltip('Brighten'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the step buttons write through the service', (tester) async {
    final repository = _FakeBrightnessRepository();
    await _pumpCard(tester, repository);

    await tester.tap(find.byTooltip('Brighten'));
    await tester.pumpAndSettle();

    expect(repository.increases, [10]);
    expect(find.text('65%'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('explains when the service is not running', (tester) async {
    final repository = _FakeBrightnessRepository()..failReads = true;
    await _pumpCard(tester, repository);

    expect(find.text('The brightness service is not running.'), findsOneWidget);
    expect(find.byTooltip('Brighten'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
