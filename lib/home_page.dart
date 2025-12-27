import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'account-form.dart';
import 'customer-list-page.dart';
import 'transfer-cash.dart';
import 'chatroom_page.dart';
import 'chat_list_page.dart';
import 'settings_page.dart';
import 'add_transfer_page.dart';
import 'services/api_service.dart';
import 'flutter_login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _branchTitle = 'Katawaz Exchange';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    
    if (userDataString != null) {
      final userData = jsonDecode(userDataString);
      setState(() {
        _branchTitle = userData['branchTitle'] ?? 'Katawaz Exchange';
        _userName = userData['firstName'] ?? '';
      });
    }
  }

  void _listCustomers(BuildContext context) {
    // TODO: اینجا تابع نمایش لیست مشتریان
    //debugPrint('List Customers pressed');
    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CustomerListPage()),
      );
    
  }

  void _addCustomer(BuildContext context) {
    // ✅ انتقال به صفحه افزودن مشتری
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CustomerFormPage()),
    );
  }

  void _listTransactions(BuildContext context) {
    Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => TransactionListPage(),
    ),
  );
  }

  void _addTransaction(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTransferPage()),
    );
  }

  void _currentShift() {
    debugPrint('Current Shift pressed');
  }

  void _openChatroom(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatListPage()),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  void _logout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiService.removeAuthToken();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_branchTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          children: [
            _buildButton(Icons.people, 'List Customers', () => _listCustomers(context)),
            _buildButton(Icons.person_add, 'Add Customer', () => _addCustomer(context)),
            _buildButton(Icons.list_alt, 'List Transactions', ()=>  _listTransactions(context)),
            _buildButton(Icons.add_circle, 'Add Transfer', () => _addTransaction(context)),
            _buildButton(Icons.timer, 'Current Shift', _currentShift),
            _buildButton(Icons.chat, 'Chat Room', () => _openChatroom(context)),
            _buildButton(Icons.settings, 'Settings', () => _openSettings(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(IconData icon, String title, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
