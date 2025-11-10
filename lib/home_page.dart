import 'package:flutter/material.dart';
import 'account-form.dart'; // ✅ اینو اضافه کن
import 'customer-list-page.dart'; // ✅ اینو اضافه کن
import 'transfer-cash.dart'; // ✅ اینو اضافه کن

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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

  void _addTransaction() {
    debugPrint('Add Transaction pressed');
  }

  void _currentShift() {
    debugPrint('Current Shift pressed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Katawaz Exchange - Home'),
        centerTitle: true,
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
            _buildButton(Icons.add_circle, 'Add Transaction', _addTransaction),
            _buildButton(Icons.timer, 'Current Shift', _currentShift),
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
