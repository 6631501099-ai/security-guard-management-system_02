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
    }

    setState(() => loading = false);
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
              image: DecorationImage(
                image: NetworkImage(
                  "https://images.unsplash.com/photo-1519501025264-65ba15a82390",
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),

          Container(color: Colors.black.withOpacity(0.6)),

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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.security, size: 80, color: Colors.red),

                      const SizedBox(height: 20),

                      const Text(
                        "Security Guard System",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 30),

                      TextField(
                        controller: email,
                        decoration: InputDecoration(
                          hintText: "Email",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: "Password",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: loading ? null : login,
                          child: loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "LOGIN",
                                  style: TextStyle(fontSize: 18),
                                ),
                        ),
                      ),

                      const SizedBox(height: 10),

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
