import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'account-form.dart';
import 'customer-list-page.dart';
import 'transfer-cash.dart';
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
    final actions = _buildDashboardActions(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Dashboard',
          style: GoogleFonts.vazirmatn(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal[700]!, Colors.blueGrey[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[100]!, Colors.teal[50]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 18),
            Text(
              'Quick Actions',
              style: GoogleFonts.vazirmatn(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.blueGrey[800],
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                return _buildActionCard(action);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final userLabel = _userName.isNotEmpty ? _userName : 'User';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.account_circle, color: Colors.teal[700], size: 36),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _branchTitle,
                  style: GoogleFonts.vazirmatn(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.blueGrey[800],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome, $userLabel',
                  style: GoogleFonts.vazirmatn(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey[500],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Live',
              style: GoogleFonts.vazirmatn(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.amber[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_DashboardAction> _buildDashboardActions(BuildContext context) {
    return [
      _DashboardAction(
        title: 'List Customers',
        subtitle: 'Browse all accounts',
        icon: Icons.people_alt_rounded,
        color: Colors.teal,
        onTap: () => _listCustomers(context),
      ),
      _DashboardAction(
        title: 'Add Customer',
        subtitle: 'Create a new profile',
        icon: Icons.person_add_alt_1,
        color: Colors.indigo,
        onTap: () => _addCustomer(context),
      ),
      _DashboardAction(
        title: 'List Transactions',
        subtitle: 'View recent activity',
        icon: Icons.receipt_long_rounded,
        color: Colors.orange,
        onTap: () => _listTransactions(context),
      ),
      _DashboardAction(
        title: 'Add Transfer',
        subtitle: 'New exchange order',
        icon: Icons.add_task,
        color: Colors.green,
        onTap: () => _addTransaction(context),
      ),
      _DashboardAction(
        title: 'Current Shift',
        subtitle: 'Shift status',
        icon: Icons.timer_outlined,
        color: Colors.blueGrey,
        onTap: _currentShift,
      ),
      _DashboardAction(
        title: 'Chat Room',
        subtitle: 'Team messages',
        icon: Icons.chat_bubble_outline,
        color: Colors.pink,
        onTap: () => _openChatroom(context),
      ),
      _DashboardAction(
        title: 'Settings',
        subtitle: 'Configure app',
        icon: Icons.settings_outlined,
        color: Colors.deepPurple,
        onTap: () => _openSettings(context),
      ),
    ];
  }

  Widget _buildActionCard(_DashboardAction action) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(action.icon, color: action.color, size: 26),
            ),
            const Spacer(),
            Text(
              action.title,
              style: GoogleFonts.vazirmatn(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.blueGrey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              action.subtitle,
              style: GoogleFonts.vazirmatn(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardAction {
  const _DashboardAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
