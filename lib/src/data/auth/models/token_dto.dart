class TokenDto {
  const TokenDto({required this.token});

  final String token;

  factory TokenDto.fromJson(Map<String, dynamic> json) {
    final token = (json['token'] ?? json['auth_token'] ?? '').toString();
    if (token.isEmpty) {
      throw const FormatException('Token response is missing a token field.');
    }
    return TokenDto(token: token);
  }
}
