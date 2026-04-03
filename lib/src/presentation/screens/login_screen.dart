import 'package:flutter/material.dart';

import '../session_scope.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.state,
    this.currentServerUrl,
    this.onChangeServer,
    super.key,
  });

  final SessionState state;
  final String? currentServerUrl;
  final VoidCallback? onChangeServer;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = SessionScope.of(context);
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 44,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      'a615db41-8bb6-4618-b76c-2789193b99dc.png',
                                      key: const Key('login-brand-mark'),
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      'Ordino',
                                      style: theme.textTheme.displaySmall,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Pristupite narudžbama, porukama i dnevnim zadacima na jednom mjestu.',
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 28),
                              TextField(
                                controller: _usernameController,
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Korisničko ime',
                                  hintText: 'Unesite korisničko ime',
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Lozinka',
                                  hintText: 'Unesite lozinku',
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
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: widget.state.isLoading
                                      ? null
                                      : () {
                                          controller.login(
                                            username: _usernameController.text,
                                            password: _passwordController.text,
                                          );
                                        },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    child: Text(
                                      widget.state.isLoading
                                          ? 'Povezivanje...'
                                          : 'Prijava',
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.onChangeServer != null) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    key: const Key('login-change-server'),
                                    onPressed: widget.state.isLoading
                                        ? null
                                        : widget.onChangeServer,
                                    child: const Text('Promijeni server'),
                                  ),
                                ),
                                if (widget.currentServerUrl != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.currentServerUrl!,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ],
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
