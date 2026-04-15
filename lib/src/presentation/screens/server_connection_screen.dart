import 'package:flutter/material.dart';

import '../session_scope.dart';

class ServerConnectionScreen extends StatefulWidget {
  const ServerConnectionScreen({required this.state, super.key});

  final SessionState state;

  @override
  State<ServerConnectionScreen> createState() => _ServerConnectionScreenState();
}

class _ServerConnectionScreenState extends State<ServerConnectionScreen> {
  static const _defaultApiUrl = 'https://mozart.sibenik1983.hr/';

  late final TextEditingController _apiUrlController;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController(
      text: widget.state.apiBaseUrl.trim().isEmpty
          ? _defaultApiUrl
          : widget.state.apiBaseUrl,
    );
  }

  @override
  void didUpdateWidget(covariant ServerConnectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final desiredValue = widget.state.apiBaseUrl.trim().isEmpty
        ? _defaultApiUrl
        : widget.state.apiBaseUrl;
    if (desiredValue != _apiUrlController.text) {
      _apiUrlController.text = desiredValue;
    }
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = SessionScope.of(context);
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyLarge;
    final eyebrowStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 44, 28, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 68,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 470),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.asset(
                                        'a615db41-8bb6-4618-b76c-2789193b99dc.png',
                                        key: const Key('server-brand-mark'),
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Povezivanje sa serverom',
                                            style: eyebrowStyle,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Ordino',
                                            style: theme.textTheme.displaySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Unesite adresu Mozart servera prije prijave u aplikaciju. Nakon spremanja otvorit ce se standardni ekran za prijavu.',
                                  style: bodyStyle,
                                ),
                                const SizedBox(height: 24),
                                TextField(
                                  controller: _apiUrlController,
                                  autocorrect: false,
                                  keyboardType: TextInputType.url,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    labelText: 'URL servisa',
                                    hintText: _defaultApiUrl,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Primjer: $_defaultApiUrl',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                                  ),
                                ),
                                if (widget.state.errorMessage != null) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    widget.state.errorMessage!,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 56),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(72),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                    ),
                                    onPressed: widget.state.isLoading
                                        ? null
                                        : () {
                                            controller.saveServer(
                                              _apiUrlController.text,
                                            );
                                          },
                                    child: Text(
                                      widget.state.isLoading
                                          ? 'Povezivanje...'
                                          : 'Nastavi',
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
              );
            },
          ),
        ),
      ),
    );
  }
}
