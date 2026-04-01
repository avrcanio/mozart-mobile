import 'package:flutter/foundation.dart';

import '../data/mailbox/mailbox_repository.dart';
import '../domain/mail_message.dart';
import 'connectivity_feedback.dart';

class MailboxState {
  const MailboxState({
    required this.isLoading,
    required this.isLoadingMore,
    required this.messages,
    required this.currentPage,
    required this.totalCount,
    required this.loadMoreErrorMessage,
    required this.errorMessage,
  });

  const MailboxState.initial()
      : isLoading = false,
        isLoadingMore = false,
        messages = const <MailMessage>[],
        currentPage = 0,
        totalCount = 0,
        loadMoreErrorMessage = null,
        errorMessage = null;

  final bool isLoading;
  final bool isLoadingMore;
  final List<MailMessage> messages;
  final int currentPage;
  final int totalCount;
  final String? loadMoreErrorMessage;
  final String? errorMessage;

  bool get hasContent => messages.isNotEmpty;
  bool get hasMorePages => messages.length < totalCount;

  MailboxState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<MailMessage>? messages,
    int? currentPage,
    int? totalCount,
    String? loadMoreErrorMessage,
    String? errorMessage,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) {
    return MailboxState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      messages: messages ?? this.messages,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      loadMoreErrorMessage: clearLoadMoreError
          ? null
          : (loadMoreErrorMessage ?? this.loadMoreErrorMessage),
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
    value = value.copyWith(
      isLoading: true,
      clearError: true,
      clearLoadMoreError: true,
    );
    try {
      final page = await _repository.fetchMessagesPage(authToken: authToken);
      value = value.copyWith(
        isLoading: false,
        messages: page.messages,
        currentPage: 1,
        totalCount: page.count,
        clearError: true,
        clearLoadMoreError: true,
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

  Future<void> loadMore(String authToken) async {
    if (value.isLoading || value.isLoadingMore || !value.hasMorePages) {
      return;
    }

    value = value.copyWith(
      isLoadingMore: true,
      clearLoadMoreError: true,
    );
    try {
      final nextPage = value.currentPage + 1;
      final page = await _repository.fetchMessagesPage(
        authToken: authToken,
        page: nextPage,
      );
      value = value.copyWith(
        isLoadingMore: false,
        messages: <MailMessage>[
          ...value.messages,
          ...page.messages,
        ],
        currentPage: nextPage,
        totalCount: page.count,
        clearLoadMoreError: true,
      );
    } catch (error) {
      value = value.copyWith(
        isLoadingMore: false,
        loadMoreErrorMessage: isConnectivityIssue(error)
            ? connectivityIssueMessage
            : 'Dodatne poruke trenutno nisu dostupne. Pokusajte ponovno.',
      );
    }
  }
}
