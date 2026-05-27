import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
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
      // fallback to SharedPreferences
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

      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', response.data['name']);

      setState(() {
        _currentName = response.data['name'];
        _imageChanged = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Widget _buildAvatar(ColorScheme cs, double radius) {
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
    // Initials fallback
    final initial =
        (_currentName ?? _nameController.text).isNotEmpty
            ? (_currentName ?? _nameController.text)[0].toUpperCase()
            : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primary.withOpacity(0.2),
      child: Text(initial,
          style: TextStyle(
              fontSize: radius * 0.65,
              fontWeight: FontWeight.w700,
              color: cs.primary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go('/home'),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: cs.onSurface),
          ),
        ),
        title: const Text('Profile',
            style:
                TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                children: [
                  // ── Avatar ─────────────────────────────────────────
                  Center(
                    child: Stack(
                      children: [
                        _buildAvatar(cs, 52),
                        Positioned(
                          bottom: 0, right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.primary,
                                border: Border.all(
                                    color: cs.surface, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 15, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_currentEmail != null)
                    Center(
                      child: Text(_currentEmail!,
                          style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withOpacity(0.4))),
                    ),
                  const SizedBox(height: 32),

                  // ── Name field ─────────────────────────────────────
                  Text('Display Name',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: cs.onSurface.withOpacity(0.45))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Your name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Save button ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
