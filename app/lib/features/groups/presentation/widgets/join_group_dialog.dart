import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/group_provider.dart';

class JoinGroupDialog extends ConsumerStatefulWidget {
  const JoinGroupDialog({super.key});

  @override
  ConsumerState<JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends ConsumerState<JoinGroupDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Code must be exactly 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final groupId = await ref.read(groupProvider.notifier).joinGroup(code);
      if (!mounted) return;

      // Always close the dialog first
      Navigator.of(context).pop();

      // Navigate to the group
      context.push('/group/$groupId');

      // Show friendly snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Taking you to the group! 🎉'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().toLowerCase();
      setState(() {
        _isLoading = false;
        _error = errStr.contains('not found') || errStr.contains('invalid')
            ? 'No group found with that code. Please double-check.'
            : 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Join Group',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-character invite code from your partner.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                hintText: 'XXXXXX',
                counterText: '',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: _error != null
                      ? BorderSide(color: Theme.of(context).colorScheme.error, width: 2)
                      : BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: _error != null
                      ? BorderSide(color: Theme.of(context).colorScheme.error, width: 2)
                      : BorderSide.none,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}
