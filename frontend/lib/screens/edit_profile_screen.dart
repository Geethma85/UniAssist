import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart' show AppColors;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _canChangePassword = false;
  String? _loadError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final profile = await _authService.loadCurrentProfile();
      if (!mounted) return;

      setState(() {
        _nameController.text = profile['name'] as String? ?? '';
        _emailController.text = profile['email'] as String? ?? '';
        _canChangePassword = _authService.canChangePassword;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load your profile. Please try again.';
        _loading = false;
      });
    }
  }

  void _clearPasswords() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  String _authError(String code) {
    return switch (code) {
      'wrong-password' ||
      'invalid-credential' ||
      'invalid-login-credentials' => 'Your current password is incorrect.',
      'weak-password' || 'password-does-not-meet-requirements' =>
        'Choose a stronger new password.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      'requires-recent-login' ||
      'user-token-expired' ||
      'invalid-user-token' => 'Please sign out, sign in again, and retry.',
      'not-signed-in' => 'Please sign in again.',
      _ => 'Could not update your password. Please try again.',
    };
  }

  Future<void> _handleSave() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    final newPassword = _newPasswordController.text;
    final currentPassword = _currentPasswordController.text;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    bool passwordChanged = false;

    try {
      if (_canChangePassword && newPassword.isNotEmpty) {
        await _authService.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        passwordChanged = true;
        if (mounted) _clearPasswords();
      }

      await _authService.saveProfileName(name);

      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _saveError = _authError(error.code));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saveError = passwordChanged
            ? 'Your password was changed, but your name could not be '
                  'saved. Keep the password fields blank and retry saving.'
            : 'Could not save your profile. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    bool password = false,
    bool readOnly = false,
    String? helper,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        readOnly: readOnly,
        obscureText: password,
        autocorrect: !password,
        enableSuggestions: !password,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Edit Profile'),
          backgroundColor: AppColors.background,
          leading: BackButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!),
                    TextButton(
                      onPressed: _loadProfile,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _field(
                        label: 'Name',
                        controller: _nameController,
                        validator: (value) {
                          final name = value?.trim() ?? '';
                          if (name.isEmpty) return 'Enter your name.';
                          if (name.length > 80) {
                            return 'Use no more than 80 characters.';
                          }
                          return null;
                        },
                      ),
                      _field(
                        label: 'Email',
                        controller: _emailController,
                        readOnly: true,
                        helper: 'Your sign-in email.',
                      ),
                      if (_canChangePassword) ...[
                        const Text(
                          'Change password (optional)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _field(
                          label: 'Current password',
                          controller: _currentPasswordController,
                          password: true,
                          validator: (value) {
                            if (_newPasswordController.text.isNotEmpty &&
                                (value == null || value.isEmpty)) {
                              return 'Enter your current password.';
                            }
                            return null;
                          },
                        ),
                        _field(
                          label: 'New password',
                          controller: _newPasswordController,
                          password: true,
                          helper: 'Leave blank to keep your password.',
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                value.length < 6) {
                              return 'Use at least 6 characters.';
                            }
                            return null;
                          },
                        ),
                        _field(
                          label: 'Confirm new password',
                          controller: _confirmPasswordController,
                          password: true,
                          validator: (value) {
                            if ((value ?? '') != _newPasswordController.text) {
                              return 'Passwords do not match.';
                            }
                            return null;
                          },
                        ),
                      ] else ...[
                        const Text(
                          'You signed in with Google. Manage your '
                          'Google password through your Google Account.',
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (_saveError != null) ...[
                        Text(
                          _saveError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      FilledButton(
                        onPressed: _saving ? null : _handleSave,
                        child: Text(_saving ? 'Saving…' : 'Save Changes'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
