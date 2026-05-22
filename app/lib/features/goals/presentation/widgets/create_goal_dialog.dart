import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/goal_provider.dart';
import '../../../groups/domain/group_provider.dart';

class CreateGoalDialog extends ConsumerStatefulWidget {
  final String groupId;

  const CreateGoalDialog({
    super.key,
    required this.groupId,
  });

  @override
  ConsumerState<CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends ConsumerState<CreateGoalDialog> {
  final _nameController = TextEditingController();
  final _iconController = TextEditingController(text: '🎯');
  double _weeklyMinimum = 3;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final icon = _iconController.text.trim();

    if (name.isEmpty || icon.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiClient.instance.post('/goals/group/${widget.groupId}', data: {
        'name': name,
        'icon': icon,
        'weeklyMinimum': _weeklyMinimum.toInt(),
      });
      
      // Refresh the goals list and groupProvider for dashboard count
      ref.read(goalsProvider.notifier).fetchGoals(widget.groupId);
      ref.invalidate(groupProvider);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create goal: $e')),
        );
      }
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
              'New Goal',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _iconController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Read a book',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Target: ${_weeklyMinimum.toInt()} days/week',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Slider(
              value: _weeklyMinimum,
              min: 1,
              max: 7,
              divisions: 6,
              onChanged: (val) {
                setState(() {
                  _weeklyMinimum = val;
                });
              },
            ),
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
                  : const Text('Create Goal'),
            ),
          ],
        ),
      ),
    );
  }
}
