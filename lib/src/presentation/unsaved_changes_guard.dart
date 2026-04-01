import 'package:flutter/material.dart';

Future<bool> showDiscardChangesDialog(
  BuildContext context, {
  String title = 'Odbaciti promjene?',
  String message =
      'Imate nespremljene promjene. Ako izadete sada, uneseni podaci ce biti izgubljeni.',
  String stayLabel = 'Nastavi uredjivati',
  String discardLabel = 'Odbaci promjene',
}) async {
  final shouldDiscard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(stayLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(discardLabel),
        ),
      ],
    ),
  );

  return shouldDiscard ?? false;
}
