import 'package:flutter/foundation.dart';

import '../data/mailbox/mailbox_repository.dart';
import '../domain/mail_message_detail.dart';
import 'connectivity_feedback.dart';

class MailboxDetailState {
  const MailboxDetailState({
    required this.isLoading,
    required this.message,
    required this.errorMessage,
  });

  const MailboxDetailState.initial()
      : isLoading = false,
        message = null,
        errorMessage = null;

  final bool isLoading;
  final MailMessageDetail? message;
  final String? errorMessage;

  bool get hasContent => message != null;

  MailboxDetailState copyWith({
    bool? isLoading,
    MailMessageDetail? message,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MailboxDetailState(
      isLoading: isLoading ?? this.isLoading,
      message: message ?? this.message,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class MailboxDetailController extends ValueNotifier<MailboxDetailState> {
  MailboxDetailController({required MailboxRepository repository})
      : _repository = repository,
        super(const MailboxDetailState.initial());

  final MailboxRepository _repository;

  Future<void> load({
    required int id,
    required String authToken,
  }) async {
    value = value.copyWith(isLoading: true, clearError: true);
    try {
      final message = await _repository.fetchMessageDetail(
        id: id,
        authToken: authToken,
      );
      value = value.copyWith(
        isLoading: false,
        message: message,
        clearError: true,
      );
    } catch (error) {
      value = value.copyWith(
        isLoading: false,
        errorMessage: isConnectivityIssue(error)
            ? connectivityIssueMessage
            : 'Detalji poruke trenutno nisu dostupni. Pokusajte ponovno.',
      );
    }
  }
}
