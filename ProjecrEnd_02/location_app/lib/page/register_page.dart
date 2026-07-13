import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

////////////////////////////////////////////////////////////
/// REGISTER PAGE
////////////////////////////////////////////////////////////

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  Future<void> register() async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.text.trim(),
            password: password.text.trim(),
          );

      await FirebaseFirestore.instance
          .collection("users")
          .doc(credential.user!.uid)
          .set({
            "name": name.text.trim(),
            "email": email.text.trim(),
            "role": "guard",
            "status": "offline",
          });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("สมัครสมาชิกไม่สำเร็จ")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: "ชื่อ"),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: "Email"),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: register,
                child: const Text("REGISTER"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
