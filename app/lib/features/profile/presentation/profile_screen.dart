import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/theme_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  String? _currentName;
  String? _currentEmail;
  String? _profileImage; // base64 data URL or null
  bool _isLoading = true;
  bool _isSaving = false;
  bool _imageChanged = false;
  bool _nameChanged = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameController.addListener(() {
      setState(() =>
          _nameChanged = _nameController.text.trim() != (_currentName ?? ''));
    });
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await ApiClient.instance.get('/users/me');
      final data = response.data;
      setState(() {
        _currentName = data['name'] as String?;
        _currentEmail = data['email'] as String?;
        _profileImage = data['profileImage'] as String?;
        _nameController.text = _currentName ?? '';
        _isLoading = false;
      });
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentName = prefs.getString('user_name') ?? '';
        _nameController.text = _currentName ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final ext = result.files.first.extension?.toLowerCase() ?? 'jpg';
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final base64Str = base64Encode(bytes);
    setState(() {
      _profileImage = 'data:$mime;base64,$base64Str';
      _imageChanged = true;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final body = <String, dynamic>{'name': name};
      if (_imageChanged) body['profileImage'] = _profileImage ?? '';

      final response = await ApiClient.instance.put('/users/me', data: body);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', response.data['name']);

      setState(() {
        _currentName = response.data['name'];
        _imageChanged = false;
        _nameChanged = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Profile updated!',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
            backgroundColor: const Color(0xFF48BB78),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _buildAvatar(double radius) {
    if (_profileImage != null && _profileImage!.startsWith('data:')) {
      try {
        final base64Str = _profileImage!.split(',').last;
        final bytes = base64Decode(base64Str);
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }
    if (_profileImage != null &&
        _profileImage!.isNotEmpty &&
        !_profileImage!.startsWith('data:')) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(_profileImage!),
      );
    }
    final name = _currentName ?? _nameController.text;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white.withOpacity(0.25),
      child: Text(
        initial,
        style: TextStyle(
            fontSize: radius * 0.65,
            fontWeight: FontWeight.w800,
            color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasChanges = _imageChanged || _nameChanged;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Hero header ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cs.primary,
                          cs.primary.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                        child: Column(children: [
                          // Topbar
                          Row(children: [
                            const Text(
                              'Profile',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Spacer(),
                            // Theme toggle
                            GestureDetector(
                              onTap: () =>
                                  ref.read(themeProvider.notifier).toggle(),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isDark
                                      ? Icons.light_mode_rounded
                                      : Icons.dark_mode_rounded,
                                  size: 18,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ]),

                          const SizedBox(height: 28),

                          // Avatar + name
                          Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.4),
                                      width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipOval(child: _buildAvatar(50)),
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: cs.surface,
                                      border: Border.all(
                                          color: cs.primary.withOpacity(0.3),
                                          width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Icon(Icons.camera_alt_rounded,
                                        size: 16, color: cs.primary),
                                  ),
                                ),
                              ),
                            ],
                          )
                              .animate()
                              .scale(
                                begin: const Offset(0.8, 0.8),
                                curve: Curves.elasticOut,
                                duration: 600.ms,
                              ),

                          const SizedBox(height: 14),

                          Text(
                            _currentName ?? '',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          )
                              .animate(delay: 100.ms)
                              .fadeIn(duration: 400.ms),

                          if (_currentEmail != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _currentEmail!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.65),
                                fontWeight: FontWeight.w500,
                              ),
                            )
                                .animate(delay: 150.ms)
                                .fadeIn(duration: 400.ms),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ),

                // ── Form ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name section
                        _FieldLabel(label: 'Display Name'),
                        const SizedBox(height: 10),
                        _StyledTextField(
                          controller: _nameController,
                          hint: 'Your name',
                          icon: Icons.person_outline_rounded,
                        ),

                        if (_currentEmail != null) ...[
                          const SizedBox(height: 24),
                          _FieldLabel(label: 'Email'),
                          const SizedBox(height: 10),
                          _ReadonlyField(
                            value: _currentEmail!,
                            icon: Icons.email_outlined,
                          ),
                        ],

                        const SizedBox(height: 36),

                        // Save button
                        AnimatedOpacity(
                          opacity: hasChanges ? 1.0 : 0.55,
                          duration: const Duration(milliseconds: 200),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  (_isSaving || !hasChanges) ? null : _save,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18)),
                                elevation: hasChanges ? 4 : 0,
                                shadowColor: cs.primary.withOpacity(0.3),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white),
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          letterSpacing: -0.2),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // ── Danger zone ──────────────────────────────
                        _DangerSection(),
                      ],
                    ),
                  )
                      .animate(delay: 200.ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                ),
              ],
            ),
    );
  }
}

// ── Supporting Widgets ─────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: cs.onSurface.withOpacity(0.4),
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.4)),
        filled: true,
        fillColor: cs.surfaceVariant.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  final String value;
  final IconData icon;

  const _ReadonlyField({required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withOpacity(0.07)),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.3)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withOpacity(0.5),
            ),
          ),
        ),
        Icon(Icons.lock_outline_rounded,
            size: 14, color: cs.onSurface.withOpacity(0.2)),
      ]),
    );
  }
}

class _DangerSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCOUNT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: cs.onSurface.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Text('Sign Out?',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                content: const Text(
                    'You\'ll need to sign in again to access your rituals.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (context.mounted) context.go('/auth');
                    },
                    child: const Text('Sign Out',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            );
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withOpacity(0.15)),
            ),
            child: Row(children: [
              Icon(Icons.logout_rounded,
                  color: Colors.redAccent, size: 18),
              const SizedBox(width: 12),
              const Text(
                'Sign Out',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.redAccent.withOpacity(0.4), size: 18),
            ]),
          ),
        ),
      ],
    );
  }
}
