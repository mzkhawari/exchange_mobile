import 'package:flutter/material.dart';
import 'flutter_login_page.dart'; // 👈 فایل صفحه لاگین خودت که من قبلاً برات نوشتم
import 'home_page.dart';
import 'services/api_service.dart';
import 'dart:io';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Allow all certificates in debug mode, be more selective in release
        if (host == 'localhost' || host == '127.0.0.1') {
          return true; // Always allow localhost
        }
        return true; // Allow all for now, but you can make this more restrictive
      };
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  
  // Log current API configuration
  ApiService.logCurrentConfig();
      
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<Map<String, dynamic>> _authFuture;
  static const Color _brandDeep = Color(0xFF0F2342);
  static const Color _brandMid = Color(0xFF1C5D8C);
  static const Color _brandDark = Color(0xFF13324D);

  @override
  void initState() {
    super.initState();
    _authFuture = _checkAuthStatus();
  }

  // Check both login status and redirect flag
  Future<Map<String, dynamic>> _checkAuthStatus() async {
    try {
      await ApiService.validateRefreshTokenOnStartup();
      final isLoggedIn = await ApiService.isLoggedIn();
      final shouldRedirect = await ApiService.shouldRedirectToLogin();

      return {
        'isLoggedIn': isLoggedIn,
        'shouldRedirect': shouldRedirect,
        'error': null,
      };
    } catch (e) {
      return {
        'isLoggedIn': false,
        'shouldRedirect': false,
        'error': 'Startup check failed. Please try again.',
      };
    }
  }

  void _retryAuthCheck() {
    setState(() {
      _authFuture = _checkAuthStatus();
    });
  }

  Widget _buildStatusScreen({
    required String title,
    required String message,
    required Widget action,
    bool showLoader = false,
  }) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_brandDeep, _brandMid, _brandDark],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showLoader) ...[
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: _brandMid,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _brandDeep,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF5E6C84),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  action,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ApiService.onUnauthorized ??= () {
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator == null) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Katawaz Exchange',
      navigatorKey: MyApp.navigatorKey,
      home: FutureBuilder<Map<String, dynamic>>(
        future: _authFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildStatusScreen(
              title: 'Preparing your workspace',
              message: 'Checking session and loading essentials.',
              showLoader: true,
              action: const SizedBox.shrink(),
            );
          }

          if (snapshot.hasError) {
            return _buildStatusScreen(
              title: 'Startup failed',
              message: 'We could not start the app. Please try again.',
              action: ElevatedButton(
                onPressed: _retryAuthCheck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandMid,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            );
          }

          final authData = snapshot.data ??
              {
                'isLoggedIn': false,
                'shouldRedirect': false,
                'error': null,
              };
          final error = authData['error'] as String?;
          if (error != null) {
            return _buildStatusScreen(
              title: 'Startup check failed',
              message: error,
              action: ElevatedButton(
                onPressed: _retryAuthCheck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandMid,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            );
          }

          final isLoggedIn = authData['isLoggedIn'] as bool? ?? false;
          final shouldRedirect = authData['shouldRedirect'] as bool? ?? false;

          // If there's a redirect flag or user is not logged in, show login page
          if (shouldRedirect || !isLoggedIn) {
            if (shouldRedirect) {
              // Show a message about session expiry
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Session expired. Please login again.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
              });
            }
            return const LoginPage();
          } else {
            return const HomePage();
          }
        },
      ),
    );
  }
}





// import 'package:flutter/material.dart';
// import 'package:webview_flutter/webview_flutter.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Katawaz Exchange',
//       theme: ThemeData(primarySwatch: Colors.deepPurple),
//       home: const WebViewPage(),
//     );
//   }
// }

// class WebViewPage extends StatefulWidget {
//   const WebViewPage({super.key});
//   @override 
//   State<WebViewPage> createState() => _WebViewPageState();
// }

// class _WebViewPageState extends State<WebViewPage> {
//   late final WebViewController _controller;
//   final String _url = 'https://katawazexchange.com/#/auth/sign-in';
//   double _progress = 0;

//   @override
//   void initState() {
//     super.initState();
//     _controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onProgress: (progress) => setState(() => _progress = progress / 100.0),
//           onPageStarted: (_) => setState(() => _progress = 0.05),
//           onPageFinished: (_) => setState(() => _progress = 0),
//         ),
//       )
//       ..loadRequest(Uri.parse(_url));
//   }

//   Future<bool> _onWillPop() async {
//     if (await _controller.canGoBack()) {
//       _controller.goBack();
//       return false;
//     }
//     return true;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: _onWillPop,
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Katawaz Sign-in'),
//           bottom: PreferredSize(
//             preferredSize: const Size.fromHeight(3.0),
//             child: _progress > 0
//                 ? LinearProgressIndicator(value: _progress, minHeight: 3)
//                 : const SizedBox(height: 3),
//           ),
//         ),
//         body: WebViewWidget(controller: _controller),
//       ),
//     );
//   }
// }
