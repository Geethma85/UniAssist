import 'package:flutter/material.dart';
import 'login_screen.dart' show AppColors;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // TODO: pre-fill these from the signed-in user's real AuthService/Firestore data
  final _usernameController = TextEditingController(text: 'alex_student24');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  static const String _universityEmail = 'alex.j@university.edu';

  bool _isSaving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // TODO: wire to real update calls once AuthService exists:
    //   - username -> Firestore users/{uid}.set({'displayName': ...}, merge: true)
    //   - password -> FirebaseAuth updatePassword(), which requires a
    //     recent sign-in. If it throws 'requires-recent-login', prompt the
    //     user to re-enter their current password and reauthenticate first.
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Changes saved (placeholder — not yet wired to Firebase)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Update your academic identity and account details.',
                        style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      Center(child: _buildAvatarPicker()),
                      const SizedBox(height: 28),
                      _buildCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              'UniAssist',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 48), // balances the back button for true centering
        ],
      ),
    );
  }

  Widget _buildAvatarPicker() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            // TODO: swap for the real profile photo once storage is wired
            'assets/images/profile_placeholder.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.surfaceContainerLow,
              child: Icon(Icons.person, size: 48, color: AppColors.onSurfaceVariant),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: () {
              // TODO: implement image picker + Firebase Storage upload.
              // This needs the image_picker package plus a Storage bucket
              // rule allowing users to write only to their own uid path —
              // worth scoping as its own small step, similar to auth.
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 3),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Username'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _usernameController,
            decoration: _fieldDecoration(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Username is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildLabel('University Email'),
              const SizedBox(width: 6),
              Icon(Icons.verified, size: 16, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: _universityEmail,
            enabled: false, // locked: identity-verifying field, not self-editable
            decoration: _fieldDecoration().copyWith(
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Managed by your institution.',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          _buildLabel('Password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: _fieldDecoration(hint: 'Leave blank to keep current password'),
            validator: (value) {
              if (value != null && value.isNotEmpty && value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildLabel('Confirm Password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: _fieldDecoration(),
            validator: (value) {
              if (_passwordController.text.isNotEmpty && value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
    );
  }

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant.withOpacity(0.7)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: AppColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: AppColors.outlineVariant),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}