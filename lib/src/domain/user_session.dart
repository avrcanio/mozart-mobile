class UserSession {
  const UserSession({
    required this.token,
    required this.username,
    required this.fullName,
    required this.email,
  });

  final String token;
  final String username;
  final String fullName;
  final String email;

  bool get hasFullName => fullName.trim().isNotEmpty && fullName != username;

  String get displayName => hasFullName ? fullName : username;

  String get secondaryIdentity {
    if (hasFullName) {
      return username;
    }
    if (email.trim().isNotEmpty) {
      return email;
    }
    return 'Aktivna sesija';
  }
}
