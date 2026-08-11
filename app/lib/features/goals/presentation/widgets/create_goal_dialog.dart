import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/goal_provider.dart';
import '../../../groups/domain/group_provider.dart';

const _presetEmojis = [
  '💪', '🏃', '📚', '🧘', '💧', '🍎', '🌙', '☕',
  '🎯', '📝', '🎨', '🏊', '🚴', '🥗', '😴', '🧠',
  '🎵', '🌿', '❤️', '✨',
];

class CreateGoalDialog extends ConsumerStatefulWidget {
  final String groupId;
  const CreateGoalDialog({super.key, required this.groupId});

  @override
  ConsumerState<CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends ConsumerState<CreateGoalDialog> {
  final _nameController = TextEditingController();
  String _selectedEmoji = '🎯';
  double _weeklyMinimum = 3;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ApiClient.instance.post('/goals/group/${widget.groupId}', data: {
        'name': name,
        'icon': _selectedEmoji,
        'weeklyMinimum': _weeklyMinimum.toInt(),
      });
      ref.read(goalsProvider.notifier).fetchGoals(widget.groupId);
      ref.invalidate(groupProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create ritual: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Title ───────────────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('New Ritual',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.close_rounded, size: 18, color: cs.onSurface),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Emoji grid ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _presetEmojis.map((e) {
                final isSelected = e == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primary.withOpacity(0.15)
                          : cs.surface.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? cs.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 20))),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Name field ──────────────────────────────────────────────
          TextField(
            controller: _nameController,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Ritual name  e.g. Hit the gym',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Text(_selectedEmoji,
                    style: const TextStyle(fontSize: 20)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
            ),
          ),
          const SizedBox(height: 20),

          // ── Frequency slider ────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Frequency',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.6))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_weeklyMinimum.toInt()}× / week',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: cs.primary),
              ),
            ),
          ]),
          SliderTheme(
            data: SliderThemeData(
              thumbColor: cs.primary,
              activeTrackColor: cs.primary,
              inactiveTrackColor: cs.primary.withOpacity(0.15),
              overlayColor: cs.primary.withOpacity(0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 4,
            ),
            child: Slider(
              value: _weeklyMinimum,
              min: 1, max: 7, divisions: 6,
              onChanged: (v) => setState(() => _weeklyMinimum = v),
            ),
          ),
          const SizedBox(height: 16),

          // ── Submit ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create Ritual',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}
