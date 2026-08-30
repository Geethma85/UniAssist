import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart' show AppColors;
import '../widgets/app_bottom_nav.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String? _error;

  String _name = '';
  String _email = '';
  String _accountRole = '';
  String _joinedDate = '';

  // TODO: no field for this in Firestore yet — not collected at registration.
  static const String _university = 'Central University';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Not signed in';
        _loading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      setState(() {
        _name = data['name'] as String? ?? 'Unknown';
        _email = data['email'] as String? ?? user.email ?? '—';
        _accountRole = _formatRole(data['role'] as String? ?? 'student');
        _joinedDate = _formatJoinedDate(data['createdAt']);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load profile. Please try again.';
        _loading = false;
      });
    }
  }

  String _formatRole(String role) {
    if (role.isEmpty) return role;
    return role[0].toUpperCase() + role.substring(1);
  }

  String _formatJoinedDate(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final date = createdAt.toDate();
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      return '${months[date.month - 1]} ${date.year}';
    }
    return '—';
  }

  Future<void> _handleLogout(BuildContext context) async {
    await AuthService().logout();

    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              _buildAvatar(),
                              const SizedBox(height: 16),
                              Text(
                                _name,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _email,
                                style: TextStyle(fontSize: 15, color: AppColors.onSurfaceVariant),
                              ),
                              const SizedBox(height: 12),
                              _buildVerifiedBadge(),
                              const SizedBox(height: 28),
                              _buildSectionLabel('ACCOUNT DETAILS'),
                              const SizedBox(height: 12),
                              _buildAccountDetailsCard(context),
                              const SizedBox(height: 24),
                              _buildLogoutButton(context),
                            ],
                          ),
                        ),
            ),
            const AppBottomNav(currentTab: AppTab.profile),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/profile_placeholder.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppColors.surfaceContainerLow,
          child: Icon(Icons.person, size: 48, color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            'Verified Student',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildAccountDetailsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          _buildActionRow(
            context: context,
            icon: Icons.edit_outlined,
            iconBg: AppColors.primary.withOpacity(0.12),
            iconColor: AppColors.primary,
            title: 'Edit Profile',
            trailing: Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
            onTap: () {
              Navigator.of(context).pushNamed('/edit-profile');
            },
          ),
          _divider(),
          _buildInfoRow(
            icon: Icons.badge_outlined,
            iconBg: AppColors.primary.withOpacity(0.12),
            iconColor: AppColors.primary,
            title: 'Account Role',
            value: _accountRole,
          ),
          _divider(),
          _buildInfoRow(
            icon: Icons.calendar_today_outlined,
            iconBg: const Color(0xFF00524B).withOpacity(0.12),
            iconColor: const Color(0xFF00524B),
            title: 'Joined Date',
            value: _joinedDate,
          ),
          _divider(),
          _buildInfoRow(
            icon: Icons.account_balance_outlined,
            iconBg: AppColors.surfaceContainerLow,
            iconColor: AppColors.onSurfaceVariant,
            title: 'University',
            value: _university,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, color: AppColors.outlineVariant.withOpacity(0.3));
  }

  Widget _buildActionRow({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            _iconBadge(icon, iconBg, iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          _iconBadge(icon, iconBg, iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _iconBadge(IconData icon, Color bg, Color iconColor) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: iconColor),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () => _handleLogout(context),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFBA1A1A)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout, size: 18, color: Color(0xFFBA1A1A)),
            SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFFBA1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}