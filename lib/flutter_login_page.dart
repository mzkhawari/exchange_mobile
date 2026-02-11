import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    final url = Uri.parse('https://209.42.25.31:7179/api/auth/login');
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
        String? refreshToken;
        if (data['token'] != null) {
          // Handle both string token and object token
          if (data['token'] is String) {
            token = data['token'];
          } else if (data['token'] is Map && data['token']['accessToken'] != null) {
            token = data['token']['accessToken'];
            refreshToken = data['token']['refreshToken']?.toString();
          } else if (data['token'] is Map && data['token']['access_token'] != null) {
            token = data['token']['access_token'];
            refreshToken = data['token']['refresh_token']?.toString();
          } else {
            token = data['token'].toString();
          }
        }

        refreshToken ??= data['refreshToken']?.toString();
        refreshToken ??= data['refresh_token']?.toString();
        
        if (token != null && token.isNotEmpty) {
          // Save the token using ApiService
          await ApiService.setAuthToken(token);

          if (refreshToken != null && refreshToken.isNotEmpty) {
            await ApiService.setRefreshToken(refreshToken);
          }
          
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
    InputDecoration inputDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF4F6FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2342),
              Color(0xFF1C5D8C),
              Color(0xFF13324D),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -40,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9EEF6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Image.asset(
                                'assets/logo.png',
                                height: 46,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Katawaz Exchange',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F2342),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to continue to your workspace.',
                            style: GoogleFonts.manrope(
                              fontSize: 14.5,
                              color: const Color(0xFF5E6C84),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 28),
                          TextField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            decoration: inputDecoration('Username', Icons.person_outline),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            decoration: inputDecoration('Password', Icons.lock_outline),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Checkbox(
                                value: _isRemember,
                                onChanged: (val) =>
                                    setState(() => _isRemember = val ?? false),
                                activeColor: const Color(0xFF1C5D8C),
                              ),
                              Text(
                                'Remember me',
                                style: GoogleFonts.manrope(
                                  fontSize: 13.5,
                                  color: const Color(0xFF2F3A4A),
                                ),
                              ),
                            ],
                          ),
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDECEC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.manrope(
                                  color: const Color(0xFFB42318),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1C5D8C),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Sign in',
                                      style: GoogleFonts.manrope(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
