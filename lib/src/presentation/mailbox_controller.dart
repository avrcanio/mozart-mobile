import 'package:flutter/foundation.dart';

import '../data/mailbox/mailbox_repository.dart';
import '../domain/mail_message.dart';
import 'connectivity_feedback.dart';

class MailboxState {
  const MailboxState({
    required this.isLoading,
    required this.messages,
    required this.errorMessage,
  });

  const MailboxState.initial()
      : isLoading = false,
        messages = const <MailMessage>[],
        errorMessage = null;

  final bool isLoading;
  final List<MailMessage> messages;
  final String? errorMessage;

  bool get hasContent => messages.isNotEmpty;

  MailboxState copyWith({
    bool? isLoading,
    List<MailMessage>? messages,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MailboxState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class MailboxController extends ValueNotifier<MailboxState> {
  MailboxController({required MailboxRepository repository})
      : _repository = repository,
        super(const MailboxState.initial());

  final MailboxRepository _repository;

  Future<void> load(String authToken) async {
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      final messages = await _repository.fetchMessages(authToken: authToken);
      value = value.copyWith(
        isLoading: false,
        messages: messages,
        clearError: true,
      );
    } catch (error) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: isConnectivityIssue(error)
            ? connectivityIssueMessage
            : 'Poruke trenutno nisu dostupne. Pokusajte ponovno za nekoliko trenutaka.',
      );
    }
  }
}
