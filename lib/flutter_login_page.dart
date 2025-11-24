import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart'; // صفحه بعد از لاگین
import 'services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRemember = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url = Uri.parse('https://api1.katawazexchange.com/api/auth/login');
    final body = {
      'UserName': _usernameController.text,
      'Password': _passwordController.text,
      'isRemember': _isRemember,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Login response: $data'); // Debug print
      
        // Check if we received a token
        String? token;
        if (data['token'] != null) {
          // Handle both string token and object token
          if (data['token'] is String) {
            token = data['token'];
          } else if (data['token'] is Map && data['token']['accessToken'] != null) {
            token = data['token']['accessToken'];
          } else if (data['token'] is Map && data['token']['access_token'] != null) {
            token = data['token']['access_token'];
          } else {
            token = data['token'].toString();
          }
        }
        
        if (token != null && token.isNotEmpty) {
          // Save the token using ApiService
          await ApiService.setAuthToken(token);
          
          // Save login response data first
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('login_response', jsonEncode(data));
          
          // Try to get user info using the token
          final userInfo = await ApiService.getUserInfo();
          
          String welcomeName = 'User';
          if (userInfo != null) {
            // Save complete user data if API call succeeds
            await prefs.setString('user_data', jsonEncode(userInfo));
            welcomeName = userInfo['firstName'] ?? 'User';
          } else if (data['currentUser'] != null) {
            // Use user data from login response if getUserInfo fails
            await prefs.setString('user_data', jsonEncode(data['currentUser']));
            welcomeName = data['currentUser']['firstName'] ?? 'User';
          }
          
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Welcome $welcomeName!'),
                backgroundColor: Colors.green,
              ),
            );
          }
          
          // Navigate to home page - always navigate if login successful
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'No authentication token received.';
          });
        }
      } else {
        // Handle different error codes
        final errorData = jsonDecode(response.body);
        setState(() {
          _errorMessage = errorData['message'] ?? 'Invalid username or password.';
        });
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains('type') && e.toString().contains('subtype')) {
          _errorMessage = 'Server response format error. Please try again.';
        } else {
          _errorMessage = 'Connection error. Please check your internet connection.';
        }
      });
      debugPrint('Login error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- لوگو در بالای صفحه ---
              Image.asset(
                'assets/logo.png', // مسیر لوگو (باید در pubspec.yaml هم ثبت شده باشد)
                height: 100,
              ),
              const SizedBox(height: 16),
              const Text(
                'Katawaz Exchange',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _isRemember,
                    onChanged: (val) =>
                        setState(() => _isRemember = val ?? false),
                  ),
                  const Text('Remember me'),
                ],
              ),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Login'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
