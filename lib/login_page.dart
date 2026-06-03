import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;
import 'home_screen.dart';
import 'admin_features/admin_homePage.dart';
import 'services/google_sheets_service.dart';
import 'widgets/aesthetic_loader.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String title, String message, [String? details]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(color: Colors.white70)),
            if (details != null) ...[
              const SizedBox(height: 12),
              Text(
                details,
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            child: const Text('OK', style: TextStyle(color: Color(0xFF8B5CF6))),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  String _getValue(Map<dynamic, dynamic> user, List<String> keys) {
    for (final searchKey in keys) {
      for (final k in user.keys) {
        final keyStr = k.toString().trim().toLowerCase();
        if (keyStr == searchKey.trim().toLowerCase()) {
          return (user[k] ?? '').toString().trim();
        }
      }
    }
    return '';
  }

  Future<void> _login() async {
    final loginId = _emailController.text.trim();
    final password = _passwordController.text;

    if (loginId.isEmpty || password.isEmpty) {
      _showErrorDialog(
        'Missing Fields',
        'Please enter your Email/Employee ID and password.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await GoogleSheetsService.fetchSheet2Data();
      if (data != null) {
        bool userFound = false;
        bool passwordMatched = false;
        String userPermissions = '';
        String userAccessPermissions = '';
        String userRole = '';
        String assignedSheet = '';
        String matchedEmployeeId = '';

        for (final user in data) {
          final cellEmployeeId = _getValue(user, ['Employee ID', 'EmployeeID']);
          final cellEmail = _getValue(user, ['Email ID', 'Email', 'EmailID']);
          final cellPassword = _getValue(user, ['Password']);

          if (cellEmployeeId == loginId || cellEmail == loginId) {
            userFound = true;
            if (cellPassword == password) {
              passwordMatched = true;
              matchedEmployeeId = cellEmployeeId;
              userPermissions = _getValue(user, ['Permissions', 'fields']);
              userAccessPermissions = _getValue(user, ['Access Permissions', 'access_permissions', 'access permissions']);
              userRole = _getValue(user, ['Role', 'Designation']);
              assignedSheet = _getValue(user, ['Sheets', 'Sheet', 'I']);
            }
            break;
          }
        }

        if (!userFound) {
          _showErrorDialog('Login Failed', 'User does not exist.');
        } else if (!passwordMatched) {
          _showErrorDialog('Login Failed', 'Incorrect password.');
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('loginId', loginId);
          await prefs.setString('permissions', userPermissions);
          await prefs.setString('accessPermissions', userAccessPermissions);
          await prefs.setString('role', userRole);
          await prefs.setString('assignedSheet', assignedSheet);
          await prefs.setString('employeeId', matchedEmployeeId);

          if (mounted) {
            if (matchedEmployeeId.toUpperCase() == 'ADMIN001') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminHomePage()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomeScreen(
                    loginId: loginId,
                    permissions: userPermissions,
                    accessPermissions: userAccessPermissions,
                    role: userRole,
                    assignedSheet: assignedSheet,
                  ),
                ),
              );
            }
          }
        }
      } else {
        _showErrorDialog(
          'Network Error',
          'Failed to fetch user data from backend.',
        );
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        _showErrorDialog(
          'Connection Error',
          'No internet connection. Please verify your Wi-Fi or mobile data and try again.',
        );
      } else {
        _showErrorDialog(
          'Error',
          'An unexpected error occurred.',
          e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final loginId = _emailController.text.trim();

    if (loginId.isEmpty) {
      _showErrorDialog(
        'Input Required',
        'Please enter your Email or Employee ID to request a password reset.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final data = await GoogleSheetsService.fetchSheet2Data();
      if (data != null) {
        bool userFound = false;

        for (final user in data) {
          final cellEmployeeId = (user['Employee ID'] ?? '').trim();
          final cellEmail = (user['Email ID'] ?? '').trim();

          if (cellEmployeeId == loginId || cellEmail == loginId) {
            userFound = true;
            break;
          }
        }

        if (!userFound) {
          _showErrorDialog(
            'User Not Found',
            'No account exists with this Email or Employee ID.',
          );
        } else {
          final updateUrl = Uri.parse('YOUR_GOOGLE_APPS_SCRIPT_WEB_APP_URL');

          if (updateUrl.toString() == 'YOUR_GOOGLE_APPS_SCRIPT_WEB_APP_URL') {
            _showErrorDialog(
              'Backend Required',
              'Please deploy the Google Apps Script and replace the URL in login_page.dart.',
            );
            return;
          }

          final updateResponse = await http.post(
            updateUrl,
            body: {'email': loginId, 'action': 'requesting_password_reset'},
          );

          if (updateResponse.statusCode == 200 ||
              updateResponse.statusCode == 302) {
            _showErrorDialog(
              'Success',
              'Password reset request sent to the admin',
            );
          } else {
            _showErrorDialog('Error', 'Failed to update the Google Sheet.');
          }
        }
      } else {
        _showErrorDialog(
          'Network Error',
          'Failed to verify email. Could not fetch data from backend.',
        );
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        _showErrorDialog(
          'Connection Error',
          'No internet connection. Please verify your Wi-Fi or mobile data and try again.',
        );
      } else {
        _showErrorDialog(
          'Error',
          'An unexpected error occurred.',
          e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isVisible,
        style: const TextStyle(
          color: Color(0xFF2D3748),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF667EEA).withValues(alpha: 0.8),
            size: 22,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: onVisibilityChanged,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Using the same beautiful animated background from the home screen
          const AnimatedGradientBackground(),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child:
                    ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: SizedBox(
                            child: Container(
                              padding: const EdgeInsets.all(32.0),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  width: 1.5,
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.9),
                                    Colors.white.withValues(alpha: 0.5),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF667EEA,
                                    ).withValues(alpha: 0.15),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Logo
                                  Center(
                                    child: Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF667EEA,
                                            ).withValues(alpha: 0.15),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Image.asset('assets/logo.png'),
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Welcome Text
                                  const Text(
                                    'Welcome Back',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF2D3748),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Sign in to continue',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 40),

                                  // Fields
                                  _buildTextField(
                                    controller: _emailController,
                                    label: 'Email or Employee ID',
                                    icon: Icons.email_outlined,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    icon: Icons.lock_outline_rounded,
                                    isPassword: true,
                                    isVisible: _isPasswordVisible,
                                    onVisibilityChanged: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // Forgot Password
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _forgotPassword,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: Color(0xFF667EEA),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Login Button
                                  Container(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: const Color(0xFF667EEA),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF667EEA,
                                          ).withValues(alpha: 0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const AestheticLoader(size: 24, color: Colors.white)
                                          : const Text(
                                              'Sign In',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 800.ms, curve: Curves.easeOutCubic)
                        .slideY(
                          begin: 0.1,
                          duration: 800.ms,
                          curve: Curves.easeOutCubic,
                        )
                        .scaleXY(
                          begin: 0.95,
                          duration: 800.ms,
                          curve: Curves.easeOutCubic,
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
