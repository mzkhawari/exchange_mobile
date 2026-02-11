import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 Starting Standalone API Test');
  print('=' * 50);
  
  // First test connectivity
  //await ApiService.testConnectivity();
  
  print('\n${'=' * 50}');
  
  // Then run full API test suite
  //await ApiService.testAllApiEndpoints();
  
  print('\n✅ Standalone API Test Completed');
}