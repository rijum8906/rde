enum AboutStatus { initial, checking, success }

class AboutRdeState {
  final AboutStatus status;
  final double logoRotation;

  const AboutRdeState({required this.status, required this.logoRotation});

  factory AboutRdeState.initial() {
    return const AboutRdeState(status: AboutStatus.initial, logoRotation: 0.0);
  }

  AboutRdeState copyWith({AboutStatus? status, double? logoRotation}) {
    return AboutRdeState(
      status: status ?? this.status,
      logoRotation: logoRotation ?? this.logoRotation,
    );
  }
}
