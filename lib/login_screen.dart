import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_page.dart';
import 'donor_dashboard_page.dart';
import 'receiver_home_page.dart';
import 'volunteer_dashboard_page.dart';
import 'ngo_dashboard_page.dart';
import 'admin_dashboard_page.dart';
import 'core/app_config.dart';
import 'core/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String selectedRole = "Donor";
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isTablet = constraints.maxWidth > 600;

        return SafeArea(
          child: Scaffold(
            backgroundColor: AppTheme.surface,
            body: Center(
              child: SizedBox(
                width: isTablet ? 500 : double.infinity,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 30 : 20),
                    child: Column(
                      children: [
                        SizedBox(
                          height: constraints.maxHeight * 0.28,
                          width: double.infinity,
                          child: Image.asset(
                            "assets/login.jpg",
                            fit: BoxFit.cover,
                            color: Colors.white.withOpacity(0.55),
                            colorBlendMode: BlendMode.modulate,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          AppConfig.appName,
                          style: TextStyle(
                            fontSize: isTablet ? 36 : 30,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppConfig.tagline,
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 15,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildDropdown(),
                        const SizedBox(height: 15),
                        _inputField("Email Address", Icons.email_outlined, emailCtrl),
                        const SizedBox(height: 15),
                        _inputField("Password", Icons.lock_outline, passCtrl, isPassword: true),
                        const SizedBox(height: 25),
                        _buildLoginButton(),
                        const SizedBox(height: 15),
                        _buildSignupText(),
                        const SizedBox(height: 12),
                        Text(
                          'App v1.0.1',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xffF4F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedRole,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                isExpanded: true,
                items: [
                  _dropdownItem("Donor", Icons.groups_rounded),
                  _dropdownItem("Receiver", Icons.person),
                  _dropdownItem("Volunteer", Icons.volunteer_activism),
                  _dropdownItem("NGO", Icons.apartment),
                  _dropdownItem("Admin", Icons.admin_panel_settings_rounded),
                ],
                onChanged: (value) => setState(() => selectedRole = value!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DropdownMenuItem<String> _dropdownItem(String title, IconData icon) {
    return DropdownMenuItem(
      value: title,
      child: Row(
        children: [
          Icon(icon, color: Colors.green),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _inputField(String label, IconData icon, TextEditingController controller,
      {bool isPassword = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xffF4F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xff7D8FAB)),
          prefixIcon: Icon(icon, color: Colors.green),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: isLoading ? null : _loginUser,
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
          "Login",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSignupText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignupPage()),
            );
          },
          child: const Text(
            "Create Account",
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Future<void> _loginUser() async {
    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("All fields are required");
      return;
    }

    setState(() => isLoading = true);

    try {
      final userCred =
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      final userId = userCred.user!.uid;

      final docSnap =
      await FirebaseFirestore.instance.collection("users").doc(userId).get();
      final data = docSnap.data();

      if (data == null) {
        _showSnackBar("User record not found");
        return;
      }

      final role = data["role"]?.toString();
      if (role == null) {
        _showSnackBar("User role missing");
        return;
      }

      // Backfill createdAt for existing users who don't have it yet
      if (data['createdAt'] == null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'createdAt': FieldValue.serverTimestamp()})
            .catchError((_) {}); // Non-fatal, continue login
      }

      // ── Suspended User Check ──
      if (data['disabled'] == true) {
        await FirebaseAuth.instance.signOut();
        _showSnackBar("Your account has been suspended by the Admin.");
        return;
      }

      // ── Maintenance Mode Check ──
      if (role != 'Admin') {
        try {
          final settingsSnap = await FirebaseFirestore.instance
              .collection('adminSettings')
              .doc('config')
              .get();
          if (settingsSnap.exists) {
            final isMaintenance = settingsSnap.data()?['maintenanceMode'] ?? false;
            if (isMaintenance) {
              await FirebaseAuth.instance.signOut();
              _showSnackBar("App is currently in Maintenance Mode. Please try again later.");
              return;
            }
          }
        } catch (_) {}
      }

      if (role != selectedRole) {
        _showSnackBar("Incorrect role selected! Your role is: $role");
        return;
      }

      if (!mounted) return;

      // Role-based navigation
      if (role == "Receiver") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ReceiverHomePage(userId: userId)),
        );
      } else if (role == "Donor") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DonorDashboardPage(userId: userId)),
        );
      } else if (role == "Volunteer") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => VolunteerDashboardPage(userId: userId)),
        );
      } else if (role == "NGO") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => NGODashboardPage(userId: userId)),
        );
      } else if (role == "Admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminDashboardPage(userId: userId)),
        );
      } else {
        _showSnackBar("Dashboard for $role is not added yet.");
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? "Login failed");
    } catch (e) {
      debugPrint("Login ERROR: $e");
      _showSnackBar("Unexpected error. Please try again.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

