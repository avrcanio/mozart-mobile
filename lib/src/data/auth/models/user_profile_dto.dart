import '../../../domain/user_session.dart';

class UserProfileDto {
  const UserProfileDto({
    required this.username,
    required this.email,
    required this.fullName,
  });

  final String username;
  final String email;
  final String fullName;

  factory UserProfileDto.fromJson(Map<String, dynamic> json) {
    final firstName = (json['first_name'] ?? '').toString().trim();
    final lastName = (json['last_name'] ?? '').toString().trim();
    final computedName = '$firstName $lastName'.trim();

    return UserProfileDto(
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: computedName.isEmpty
          ? (json['full_name'] ?? json['name'] ?? json['username'] ?? '')
              .toString()
          : computedName,
    );
  }

  UserSession toDomain(String token) {
    return UserSession(
      token: token,
      username: username,
      email: email,
      fullName: fullName.isEmpty ? username : fullName,
    );
  }
}
