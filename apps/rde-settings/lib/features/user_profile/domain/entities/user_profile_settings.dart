class UserProfileSettings {
  final String username;
  final String avatarPath;
  final String passwordCrypt;

  const UserProfileSettings({
    required this.username,
    required this.avatarPath,
    required this.passwordCrypt,
  });

  UserProfileSettings copyWith({
    String? username,
    String? avatarPath,
    String? passwordCrypt,
  }) {
    return UserProfileSettings(
      username: username ?? this.username,
      avatarPath: avatarPath ?? this.avatarPath,
      passwordCrypt: passwordCrypt ?? this.passwordCrypt,
    );
  }
}
