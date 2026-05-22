import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/primary_button.dart';
import '../domain/group_provider.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Name your space',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will be the shared dashboard for you and your accountability partner.',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g., Us vs The Gym',
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                text: 'Create Group',
                icon: Icons.check,
                isLoading: ref.watch(groupProvider).isLoading,
                onPressed: () async {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  
                  await ref.read(groupProvider.notifier).createGroup(name);
                  
                  if (mounted && ref.read(groupProvider).hasValue) {
                    final groups = ref.read(groupProvider).value!;
                    if (groups.isNotEmpty) {
                      final newGroupId = groups.last['_id'];
                      context.go('/group/$newGroupId');
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
