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
}
