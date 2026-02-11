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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Check both login status and redirect flag
  Future<Map<String, bool>> _checkAuthStatus() async {
    await ApiService.validateRefreshTokenOnStartup();
    final isLoggedIn = await ApiService.isLoggedIn();
    final shouldRedirect = await ApiService.shouldRedirectToLogin();
    
    return {
      'isLoggedIn': isLoggedIn,
      'shouldRedirect': shouldRedirect,
    };
  }

  @override
  Widget build(BuildContext context) {
    ApiService.onUnauthorized ??= () {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Katawaz Exchange',
      navigatorKey: navigatorKey,
      home: FutureBuilder<Map<String, bool>>(
        future: _checkAuthStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          final authData = snapshot.data ?? {'isLoggedIn': false, 'shouldRedirect': false};
          final isLoggedIn = authData['isLoggedIn'] ?? false;
          final shouldRedirect = authData['shouldRedirect'] ?? false;
          
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
