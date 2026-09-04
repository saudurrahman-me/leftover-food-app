import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'donor_dashboard_page.dart';
import 'receiver_home_page.dart';
import 'volunteer_dashboard_page.dart';
import 'ngo_dashboard_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  String selectedRole = "Donor";
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  // NGO-specific extra fields
  final ngoContactCtrl = TextEditingController();
  final ngoLocationCtrl = TextEditingController();
  final ngoDetailsCtrl = TextEditingController();
  final adminKeyCtrl = TextEditingController();
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    double screenWidth = size.width;
    double screenHeight = size.height;

    return Scaffold(
      backgroundColor: const Color(0xffF8F8F8),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: screenHeight * 0.28,
              child: Image.asset(
                "assets/login.jpg",
                fit: BoxFit.cover,
                color: Colors.white.withValues(alpha: 0.55),
                colorBlendMode: BlendMode.modulate,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
                vertical: screenHeight * 0.03,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "FoodShare",
                          style: TextStyle(
                            fontSize: screenWidth * 0.075,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xff1F2C37),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Sharing Is Caring",
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    "I am a...",
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xff1F2C37),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      roleBtn("Donor", screenWidth),
                      roleBtn("Receiver", screenWidth),
                      roleBtn("Volunteer", screenWidth),
                      roleBtn("NGO", screenWidth),
                    ],
                  ),
                  const SizedBox(height: 25),
                  matchedTextField("Full Name", Icons.person_outline, nameCtrl, screenWidth),
                  matchedTextField("Email Address", Icons.email_outlined, emailCtrl, screenWidth),
                  matchedTextField("Password", Icons.lock_outline, passCtrl, screenWidth, isPassword: true),
                  matchedTextField("Confirm Password", Icons.lock_outline, confirmCtrl, screenWidth, isPassword: true),
                  // NGO extra fields (only shown when NGO role is selected)
                  if (selectedRole == 'NGO') ...[
                    matchedTextField("Contact Number", Icons.phone_outlined, ngoContactCtrl, screenWidth),
                    matchedTextField("Organization Location", Icons.location_on_outlined, ngoLocationCtrl, screenWidth),
                    matchedTextField("Organization Details", Icons.info_outline, ngoDetailsCtrl, screenWidth),
                  ],
                  // Admin extra fields removed
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: screenHeight * 0.065,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isLoading ? null : _signupUser,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                        "Sign Up",
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        "Go Back",
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget roleBtn(String role, double screenWidth) {
    bool isSelected = selectedRole == role;
    return SizedBox(
      width: (screenWidth / 2) - 40,
      child: GestureDetector(
        onTap: () => setState(() => selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Center(
            child: Text(
              role,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget matchedTextField(
      String label, IconData icon, TextEditingController ctrl, double screenWidth,
      {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xffF4F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: ctrl,
          obscureText: isPassword,
          decoration: InputDecoration(
            border: InputBorder.none,
            labelText: label,
            labelStyle: TextStyle(
              color: const Color(0xff7D8FAB),
              fontSize: screenWidth * 0.04,
            ),
            prefixIcon: Icon(icon, color: Colors.green),
          ),
        ),
      ),
    );
  }

  Future<void> _signupUser() async {
    String name = nameCtrl.text.trim();
    String email = emailCtrl.text.trim();
    String password = passCtrl.text.trim();
    String confirm = confirmCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnackBar("Please fill all fields");
      return;
    }
    if (password != confirm) {
      _showSnackBar("Passwords do not match");
      return;
    }



    setState(() => isLoading = true);

    try {
      UserCredential userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // ✅ Save user data in Firestore with createdAt timestamp
      final Map<String, dynamic> userData = {
        "name": name,
        "email": email,
        "role": selectedRole,
        "familiesHelped": 0,
        "createdAt": FieldValue.serverTimestamp(),
      };

      // Store NGO-specific fields if registering as NGO
      if (selectedRole == 'NGO') {
        userData['contactNumber'] = ngoContactCtrl.text.trim();
        userData['organizationLocation'] = ngoLocationCtrl.text.trim();
        userData['organizationDetails'] = ngoDetailsCtrl.text.trim();
      }

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userCred.user!.uid)
          .set(userData);

      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        // ✅ Role-based navigation including Volunteer
        if (selectedRole == "Receiver") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ReceiverHomePage(userId: userCred.user!.uid)),
          );
        } else if (selectedRole == "Donor") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DonorDashboardPage(userId: userCred.user!.uid)),
          );
        } else if (selectedRole == "Volunteer") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => VolunteerDashboardPage(userId: userCred.user!.uid)),
          );
        } else if (selectedRole == "NGO") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => NGODashboardPage(userId: userCred.user!.uid)),
          );
        } else {
          _showSnackBar("Dashboard for this role is not implemented yet.");
        }
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? "Signup failed");
    } catch (e) {
      debugPrint("Signup ERROR: $e");
      _showSnackBar("An unexpected error occurred.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

