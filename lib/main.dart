import 'package:flutter/material.dart';
import 'flutter_login_page.dart'; // 👈 فایل صفحه لاگین خودت که من قبلاً برات نوشتم
import 'home_page.dart';
import 'services/api_service.dart';
import 'dart:io';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();    
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Katawaz Exchange',
      home: FutureBuilder<bool>(
        future: ApiService.isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          if (snapshot.data == true) {
            return const HomePage(); // User is logged in
          } else {
            return const LoginPage(); // Show login page
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
