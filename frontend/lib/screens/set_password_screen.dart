import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _friendlyError(String code) {
    return switch (code) {
      'popup-closed-by-user' || 'cancelled-popup-request' =>
        'Confirmation was cancelled. Your password was not set.',
      'user-mismatch' =>
        'Choose the Google account you are currently using in UniAssist.',
      'popup-blocked' => 'Allow popups for UniAssist and try again.',
      'weak-password' ||
      'password-does-not-meet-requirements' => 'Choose a stronger password.',
      'provider-already-linked' =>
        'This account already has a password. Reopen Edit Profile '
            'to change it.',
      'credential-already-in-use' || 'email-already-in-use' =>
        'That sign-in method belongs to another account. '
            'No accounts were merged.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      'requires-recent-login' || 'user-token-expired' || 'invalid-user-token' =>
        'Please sign out, sign in again with Google, and retry.',
      _ => 'Could not set your password. Please try again.',
    };
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _authService.setPasswordForGoogleAccount(_passwordController.text);

      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error.code));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not set your password. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Set UniAssist password')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add a UniAssist password for '
                      '${_authService.currentUser?.email ?? 'your account'}. '
                      'You can then sign in with Google or email/password. '
                      'This does not change your Google password.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'After selecting Save, confirm the same Google '
                      'account you are currently signed in with.',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_saving,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'New UniAssist password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Use at least 6 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _confirmController,
                      enabled: !_saving,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save password'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
