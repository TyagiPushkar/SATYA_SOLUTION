import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_sizebox.dart';
import '../../../core/widgets/app_text.dart';
import '../../auth/provider/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }

  String _capitalize(String? text) {
    if (text == null || text.isEmpty) return 'N/A';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.asData?.value;

    final userName = (user?.name != null && user!.name!.isNotEmpty)
        ? user.name!
        : 'N/A';
    final userDesignation =
        (user?.designations != null && user!.designations!.isNotEmpty)
            ? user.designations!
            : 'N/A';
    final userDepartment =
        (user?.department != null && user!.department!.isNotEmpty)
            ? user.department!
            : 'N/A';
    final userGender = _capitalize(user?.gender);
    final userEmail = (user?.email != null && user!.email!.isNotEmpty)
        ? user.email!
        : 'N/A';
    final userMobile = (user?.mobile != null && user!.mobile!.isNotEmpty)
        ? user.mobile!
        : 'N/A';
    final userWorkShift =
        (user?.workShift != null && user!.workShift!.isNotEmpty)
            ? user.workShift!
            : 'N/A';
    final userAddress = (user?.address != null && user!.address!.isNotEmpty)
        ? user.address!
        : 'N/A';
    final userDoj = _formatDate(user?.dateOfJoining);

    const purpleColor = Color(0xFF7C3AED);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Header Stack with curved bottom
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Header Gradient Container
                ClipPath(
                  clipper: HeaderArcClipper(),
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, Color(0xFF6D28D9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),

                // Overlapping Avatar
                Positioned(
                  bottom: -45,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.grey.shade100,
                      backgroundImage:
                          (user?.image != null && user!.image!.isNotEmpty)
                              ? ResizeImage(NetworkImage(user.image!), width: 300, height: 300)
                              : null,
                      child: (user?.image == null || user!.image!.isEmpty)
                          ? ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                              ).createShader(bounds),
                              child: const Icon(
                                Icons.person,
                                size: 56,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),

            const AppSizeBox.h(55),

            // User Name & Designation Header text
            AppText(
              userName,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
            if (userDesignation != 'N/A') ...[
              const AppSizeBox.h(4),
              AppText(
                userDesignation,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ],

            const AppSizeBox.h(24),

            // Profile Details Container
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildProfileRow(
                      icon: Icons.person_outline,
                      label: 'Full Name',
                      value: userName,
                      iconColor: purpleColor,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileRow(
                      icon: Icons.badge_outlined,
                      label: 'Designation',
                      value: userDesignation,
                      iconColor: purpleColor,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileRow(
                      icon: Icons.business_outlined,
                      label: 'Department',
                      value: userDepartment,
                      iconColor: purpleColor,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileRow(
                      icon: Icons.wc_outlined,
                      label: 'Gender',
                      value: userGender,
                      iconColor: purpleColor,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileRow(
                      icon: Icons.email_outlined,
                      label: 'Email Address',
                      value: userEmail,
                      iconColor: purpleColor,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileRow(
                      icon: Icons.phone_android_outlined,
                      label: 'Mobile Number',
                      value: userMobile,
                      iconColor: purpleColor,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileRow(
                      icon: Icons.access_time_outlined,
                      label: 'Work Shift',
                      value: userWorkShift,
                      iconColor: purpleColor,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date of Joining',
                      value: userDoj,
                      iconColor: purpleColor,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileRow(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: userAddress,
                      iconColor: purpleColor,
                    ),
                  ],
                ),
              ),
            ),

            const AppSizeBox.h(30),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: AppColors.primary,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x407C3AED),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () => _showLogoutDialog(context, ref),
                    child: const Center(
                      child: AppText(
                        'Logout',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const AppSizeBox.h(40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const AppSizeBox.w(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  label,
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w400,
                ),
                const AppSizeBox.h(2),
                AppText(
                  value,
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w500,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('Logout', fontWeight: FontWeight.bold),
        content: const AppText('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const AppText('Cancel', color: Colors.grey),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(loginProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const AppText('Logout', color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}


class HeaderArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);

    final controlPoint = Offset(size.width / 2, size.height + 20);
    final endPoint = Offset(size.width, size.height - 50);

    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      endPoint.dx,
      endPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
