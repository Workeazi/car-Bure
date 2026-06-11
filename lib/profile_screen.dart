import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';

class ProfileScreen extends StatelessWidget {
  final String loginId;
  final String accessPermissions;
  final List<String> permittedColumns;
  final String role;

  const ProfileScreen({
    super.key,
    required this.loginId,
    required this.accessPermissions,
    required this.permittedColumns,
    this.role = 'Member',
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(top: 80.0, bottom: 130.0, left: 24.0, right: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Profile',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A202C),
                          letterSpacing: -1.5,
                          height: 1.1,
                        ),
                      ).animate().fade(duration: 800.ms, curve: Curves.easeOutExpo).slideX(begin: -0.1, duration: 800.ms, curve: Curves.easeOutExpo),
                      const SizedBox(height: 12),
                      const Text(
                        'Manage your account details and permissions.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF718096),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ).animate().fade(duration: 800.ms, delay: 100.ms).slideX(begin: -0.1, duration: 800.ms, curve: Curves.easeOutExpo),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showSupportDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF667EEA).withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667EEA).withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.headset_mic_rounded,
                          color: Color(0xFF667EEA),
                          size: 20,
                        )
                            .animate(onPlay: (controller) => controller.repeat())
                            .shimmer(duration: 2000.ms, delay: 1000.ms)
                            .shake(hz: 4, curve: Curves.easeInOutCubic, duration: 2000.ms),
                        const SizedBox(width: 8),
                        const Text(
                          'Support',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF667EEA),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fade(duration: 800.ms, delay: 200.ms).slideX(begin: 0.2, curve: Curves.easeOutExpo),
              ],
            ),
            const SizedBox(height: 40),

            // Profile Card
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF667EEA).withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 20)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.person_rounded, size: 48, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    loginId,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2D3748),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    role.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF764BA2),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Access: $accessPermissions',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF667EEA),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fade(duration: 800.ms, delay: 200.ms).slideY(begin: 0.1, duration: 800.ms, curve: Curves.easeOutExpo),

            const SizedBox(height: 32),

            // Columns Access Card
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF667EEA).withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 20)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.view_column_rounded, color: Color(0xFF718096), size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Visible Columns',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D3748),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: permittedColumns.map((col) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Text(
                          col,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A5568),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ).animate().fade(duration: 800.ms, delay: 300.ms).slideY(begin: 0.1, duration: 800.ms, curve: Curves.easeOutExpo),

            const SizedBox(height: 48),

            // Logout Button
            Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.red.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 15)),
                ],
              ),
              child: ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFC8181), Color(0xFFE53E3E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, size: 28, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'Log Out',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().fade(duration: 800.ms, delay: 400.ms).slideY(begin: 0.2, curve: Curves.easeOutBack),
          ],
        ),
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Support',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: 400.ms,
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: Opacity(
            opacity: anim1.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSupportCard(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSupportCard(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 650),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 50,
            spreadRadius: 10,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Powered By Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Powered by Workeazi',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Customer Support',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A202C), letterSpacing: -0.5),
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 450;
              final content = [
                // Left Column
                Expanded(
                  flex: isSmall ? 0 : 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.insights_rounded, color: Colors.green.shade600, size: 32),
                          const SizedBox(width: 8),
                          const Text(
                            'WORKEAZI',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Color(0xFF1A202C)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Helping businesses with software, automation and support.',
                        style: TextStyle(fontSize: 16, color: Color(0xFF718096), height: 1.6, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (!isSmall)
                  Container(
                    width: 1,
                    height: 180,
                    color: Colors.grey.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                  ),
                if (isSmall) const SizedBox(height: 32),
                // Right Column
                Expanded(
                  flex: isSmall ? 0 : 3,
                  child: Column(
                    children: [
                      _buildContactTile(
                        icon: Icons.phone_in_talk_rounded,
                        title: 'Call Support',
                        subtitle: '+91 9363100658',
                        color: const Color(0xFFF0F4FF),
                        iconColor: const Color(0xFF4285F4),
                        delay: 200,
                      ),
                      const SizedBox(height: 16),
                      _buildContactTile(
                        icon: Icons.chat_bubble_rounded,
                        title: 'WhatsApp Support',
                        subtitle: '+91 9363100658',
                        color: const Color(0xFFE6F8EB),
                        iconColor: const Color(0xFF34A853),
                        delay: 300,
                      ),
                      const SizedBox(height: 16),
                      _buildContactTile(
                        icon: Icons.email_rounded,
                        title: 'Email Support',
                        subtitle: 'info@workeazi.com',
                        color: const Color(0xFFF8F0FC),
                        iconColor: const Color(0xFF9333EA),
                        delay: 400,
                      ),
                    ],
                  ),
                ),
              ];
              
              if (isSmall) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: content);
              } else {
                return Row(crossAxisAlignment: CrossAxisAlignment.center, children: content);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile({required IconData icon, required String title, required String subtitle, required Color color, required Color iconColor, required int delay}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 15, color: Color(0xFF1A202C), fontWeight: FontWeight.w800)),
              ],
            ),
          )
        ],
      ),
    ).animate().fade(delay: delay.ms, duration: 400.ms).slideX(begin: 0.1, duration: 400.ms, curve: Curves.easeOutQuad);
  }
}
