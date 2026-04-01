import 'package:characters/characters.dart';

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

  String get initials {
    final source = hasFullName ? fullName : username;
    final parts = source
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    final first = parts.first.characters.first.toUpperCase();
    final last = parts.last.characters.first.toUpperCase();
    return '$first$last';
  }
}
