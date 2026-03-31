class UserSession {
  const UserSession({
    required this.token,
    required this.fullName,
    required this.email,
  });

  final String token;
  final String fullName;
  final String email;
}
