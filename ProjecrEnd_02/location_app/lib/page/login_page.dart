import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_page.dart';

////////////////////////////////////////////////////////////
/// LOGIN PAGE
////////////////////////////////////////////////////////////

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool obscurePassword = true;
  bool loading = false;

  Future<void> login() async {
    try {
      setState(() => loading = true);

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Login ไม่สำเร็จ")));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ////////////////////////////////////////////////////////////
          /// BACKGROUND
          ////////////////////////////////////////////////////////////
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xff630000),
                  Color(0xff4B0000),
                  Color(0xff320000),
                ],
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x22D4AF37),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x44D4AF37),
                    blurRadius: 120,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x11D4AF37),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x44D4AF37),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 35,
            top: 180,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xffD4AF37),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0xffD4AF37), blurRadius: 15),
                ],
              ),
            ),
          ),

          Positioned(
            right: 40,
            top: 420,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xffD4AF37),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0xffD4AF37), blurRadius: 20),
                ],
              ),
            ),
          ),

          Positioned(
            right: 55,
            bottom: 180,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xffD4AF37),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0xffD4AF37), blurRadius: 10),
                ],
              ),
            ),
          ),

          ////////////////////////////////////////////////////////////
          /// CONTENT
          ////////////////////////////////////////////////////////////
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.06),

                    border: Border.all(color: Colors.white12),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset("assets/icon02.png", height: 70),

                      const SizedBox(height: 20),

                      const Text(
                        "ลงชื่อเข้าใช้งาน",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        "กรอกข้อมูลเพื่อลงชื่อเข้าใช้งาน",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),

                      const SizedBox(height: 30),

                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Email",
                          hintStyle: const TextStyle(color: Colors.white54),

                          prefixIcon: const Icon(
                            Icons.email,
                            color: Color(0xffD4AF37),
                          ),

                          filled: true,
                          fillColor: Colors.white.withOpacity(.05),

                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),

                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Color(0xffD4AF37),
                            ),
                          ),

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      const SizedBox(height: 20),

                      TextField(
                        controller: password,
                        obscureText: obscurePassword,
                        style: const TextStyle(color: Colors.white),

                        decoration: InputDecoration(
                          hintText: "Password",
                          hintStyle: const TextStyle(color: Colors.white54),

                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Color(0xffD4AF37),
                          ),

                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),

                          filled: true,
                          fillColor: Colors.white.withOpacity(.05),

                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),

                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Color(0xffD4AF37),
                            ),
                          ),

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xffD4AF37),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: loading ? null : login,
                          child: loading
                              ? const CircularProgressIndicator(
                                  color: Colors.black,
                                )
                              : const Text(
                                  "เข้าสู่ระบบ",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        "กรอกข้อมูลเพื่อลงชื่อเข้าใช้งาน",
                        style: TextStyle(color: Colors.white70),
                      ),

                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Text("Create Account"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
