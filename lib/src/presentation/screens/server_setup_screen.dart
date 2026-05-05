import 'package:flutter/material.dart';

class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({
    required this.isLoading,
    required this.onSubmit,
    this.initialValue = '',
    this.errorMessage,
    this.title = 'Povezivanje sa serverom',
    this.description =
        'Unesite adresu Mozart servera prije prve prijave u aplikaciju.',
    this.submitLabel = 'Nastavi',
    super.key,
  });

  final bool isLoading;
  final String initialValue;
  final String? errorMessage;
  final String title;
  final String description;
  final String submitLabel;
  final ValueChanged<String> onSubmit;

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant ServerSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _urlController.text != widget.initialValue) {
      _urlController.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8F1E7), Color(0xFFE5CFBF), Color(0xFFD7E3DA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.title, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 12),
                        Text(
                          widget.description,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          key: const Key('server-url-field'),
                          controller: _urlController,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          onSubmitted: widget.isLoading
                              ? null
                              : (_) => widget.onSubmit(_urlController.text),
                          decoration: const InputDecoration(
                            labelText: 'Server URL',
                            hintText: 'https://mozart.sibenik1983.hr',
                          ),
                        ),
                        if (widget.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            widget.errorMessage!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const Key('server-url-submit'),
                            onPressed: widget.isLoading
                                ? null
                                : () => widget.onSubmit(_urlController.text),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                widget.isLoading
                                    ? 'Provjera...'
                                    : widget.submitLabel,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
