import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:core/core.dart';
import 'package:rde_settings/features/display/domain/entities/brightness_level.dart';
import 'package:rde_settings/features/display/domain/repositories/brightness_repository.dart';
import 'package:rde_settings/features/display/presentation/bloc/brightness_event.dart';
import 'package:rde_settings/features/display/presentation/bloc/brightness_state.dart';

/// Keeps the display page and the dashboard quick actions in step with the
/// `org.rde.Brightness` service.
///
/// A write is shown immediately: the slider moves to the requested level as
/// soon as the write succeeds, without reading the service back. A rejected
/// write restores the previous level and reports the failure. A drag still
/// commits once it settles, because writing every pixel of a drag would flood
/// the service.
///
/// Signals from the service mean another client changed the brightness - media
/// keys, the shell's OSD - so the card reloads for those as well.
class BrightnessBloc extends Bloc<BrightnessEvent, BrightnessState> {
  BrightnessBloc({
    required this._repository,
    this.commitDelay = const Duration(milliseconds: 180),
  }) : super(const BrightnessState.initial()) {
    on<BrightnessInitEvent>(_onInit);
    on<BrightnessSliderChangedEvent>(_onSliderChanged);
    on<BrightnessSetEvent>(_onSet);
    on<BrightnessIncreaseEvent>(
      (event, emit) => _onStep(event.step, true, emit),
    );
    on<BrightnessDecreaseEvent>(
      (event, emit) => _onStep(event.step, false, emit),
    );
    on<BrightnessServiceChangedEvent>(_onServiceChanged);

    _changes = _repository.watchChanges().listen(
      (_) => add(const BrightnessServiceChangedEvent()),
      onError: (Object _) {
        // A service that quits mid-watch surfaces here; the next read
        // reconciles and reports the missing service.
      },
    );
  }

  /// How long a drag may settle before the value is written.
  final Duration commitDelay;

  final BrightnessRepository _repository;

  /// Live updates pushed by the service while a card is open.
  late final StreamSubscription<void> _changes;

  /// Collapses a burst of service signals into a single read.
  Timer? _changeDebounce;

  /// Commits the value a drag left behind.
  Timer? _commit;

  @override
  Future<void> close() async {
    _changeDebounce?.cancel();
    _commit?.cancel();
    await _changes.cancel();
    return super.close();
  }

  Future<void> _onInit(
    BrightnessInitEvent event,
    Emitter<BrightnessState> emit,
  ) async {
    emit(state.copyWith(status: BrightnessStatus.loading, errorMessage: null));

    final result = await _repository.read();
    switch (result) {
      case Left(value: final failure):
        emit(
          state.copyWith(
            status: BrightnessStatus.failure,
            errorMessage: failure.message,
          ),
        );

      case Right(value: final level):
        emit(
          state.copyWith(
            status: BrightnessStatus.success,
            level: level,
            errorMessage: null,
          ),
        );
    }
  }

  /// Moves the slider and schedules the write.
  ///
  /// The state changes right away so the thumb tracks the pointer; the service
  /// is written once the drag has been still for [commitDelay].
  void _onSliderChanged(
    BrightnessSliderChangedEvent event,
    Emitter<BrightnessState> emit,
  ) {
    final level = state.level;
    if (level == null) {
      return;
    }

    final percent = event.percent.clamp(0, 100).toInt();
    emit(
      state.copyWith(level: _withPercent(level, percent), errorMessage: null),
    );

    _commit?.cancel();
    _commit = Timer(commitDelay, () => add(BrightnessSetEvent(percent)));
  }

  Future<void> _onSet(
    BrightnessSetEvent event,
    Emitter<BrightnessState> emit,
  ) async {
    final level = state.level;
    if (level == null) {
      return;
    }

    _commit?.cancel();

    final percent = event.percent.clamp(0, 100).toInt();
    emit(
      state.copyWith(level: _withPercent(level, percent), errorMessage: null),
    );

    // A successful write is the new level: no read-back and no waiting for the
    // republished property. A rejection snaps the slider back.
    final failure = _failureOf(await _repository.setPercent(percent));
    if (failure != null) {
      emit(state.copyWith(level: level, errorMessage: failure.message));
    }
  }

  /// Applies an `IncreaseBrightness` / `DecreaseBrightness` call.
  Future<void> _onStep(
    int step,
    bool increase,
    Emitter<BrightnessState> emit,
  ) async {
    final level = state.level;
    if (level == null || state.isBusy) {
      return;
    }

    // Move the level now; the service applies the same clamp.
    final percent = increase
        ? (level.percent + step).clamp(0, 100).toInt()
        : (level.percent - step).clamp(0, 100).toInt();
    emit(
      state.copyWith(
        isBusy: true,
        level: _withPercent(level, percent),
        errorMessage: null,
      ),
    );

    final failure = increase
        ? _failureOf(await _repository.increase(step))
        : _failureOf(await _repository.decrease(step));
    if (failure != null) {
      emit(
        state.copyWith(
          isBusy: false,
          level: level,
          errorMessage: failure.message,
        ),
      );
      return;
    }

    emit(state.copyWith(isBusy: false));
  }

  /// Reloads after another client changed the brightness.
  ///
  /// A drag in progress is left alone: the user's finger is the more recent
  /// intent, and its commit reads the service back anyway.
  Future<void> _onServiceChanged(
    BrightnessServiceChangedEvent event,
    Emitter<BrightnessState> emit,
  ) async {
    if (_commit?.isActive ?? false) {
      return;
    }

    _changeDebounce?.cancel();
    final completer = Completer<void>();
    _changeDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await completer.future;
    if (state.isBusy) {
      return;
    }

    await _refresh(emit);
  }

  /// Reads the brightness back from the service.
  ///
  /// A failed read keeps the level the card already shows and only reports the
  /// error, because a service that is restarting should not blank the card.
  Future<void> _refresh(Emitter<BrightnessState> emit) async {
    final result = await _repository.read();
    switch (result) {
      case Left(value: final failure):
        emit(state.copyWith(isBusy: false, errorMessage: failure.message));

      case Right(value: final level):
        emit(
          state.copyWith(
            status: BrightnessStatus.success,
            level: level,
            isBusy: false,
            errorMessage: null,
          ),
        );
    }
  }

  /// Returns [level] moved to [percent], carrying the raw value with it.
  ///
  /// The service divides the scale the same way, so the card can show the raw
  /// value without waiting for the republished property.
  BrightnessLevel _withPercent(BrightnessLevel level, int percent) {
    if (!level.hasRange) {
      return level.copyWith(percent: percent);
    }

    final raw = (percent * level.max) ~/ 100;
    return level.copyWith(percent: percent, raw: raw);
  }

  /// Extracts the failure of a void result, or `null` on success.
  Failure? _failureOf(Either<Failure, void> result) {
    return result.fold((failure) => failure, (_) => null);
  }
}
