import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_page.dart';
import 'services/api_service.dart';

class AddTransferPage extends StatefulWidget {
  const AddTransferPage({super.key});

  @override
  State<AddTransferPage> createState() => _AddTransferPageState();
}

class _AddTransferPageState extends State<AddTransferPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Controllers
  final _amountCtrl = TextEditingController();
  final _payableCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController();
  final _buyRateCtrl = TextEditingController();
  final _sellRateCtrl = TextEditingController();
  final _senderFirstNameCtrl = TextEditingController();
  final _senderLastNameCtrl = TextEditingController();
  final _senderAccountNumberCtrl = TextEditingController();
  final _senderMobileCtrl = TextEditingController();
  final _recipientFirstNameCtrl = TextEditingController();
  final _recipientLastNameCtrl = TextEditingController();
  final _recipientEmailCtrl = TextEditingController();
  final _recipientMobileCtrl = TextEditingController();
  
  // Dropdown values
  int? _transactionPurposeId;
  int? _receiverBranchId;
  int? _purchaseCurrencyId;
  int? _salesCurrencyId;
  int? _commissionUnitId;
  int? _treasuryId;
  int? _senderId;
  
  bool _isPayableFromAllBranches = false;
  
  // Data from settings
  List<Map<String, dynamic>> _transferTypes = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _currencies = [];
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _customers = [];
  
  @override
  void initState() {
    super.initState();
    _loadSettingsData();
    _loadCustomers();
    
    // Add listeners for automatic calculation
    _amountCtrl.addListener(_calculatePayable);
    _buyRateCtrl.addListener(_calculatePayable);
    _sellRateCtrl.addListener(_calculatePayable);
  }
  
  @override
  void dispose() {
    _amountCtrl.dispose();
    _payableCtrl.dispose();
    _commissionCtrl.dispose();
    _buyRateCtrl.dispose();
    _sellRateCtrl.dispose();
    _senderFirstNameCtrl.dispose();
    _senderLastNameCtrl.dispose();
    _senderAccountNumberCtrl.dispose();
    _senderMobileCtrl.dispose();
    _recipientFirstNameCtrl.dispose();
    _recipientLastNameCtrl.dispose();
    _recipientEmailCtrl.dispose();
    _recipientMobileCtrl.dispose();
    super.dispose();
  }
  
  Future<void> _loadSettingsData() async {
    final transferTypes = await SettingsDataHelper.getTransferTypes();
    final branches = await SettingsDataHelper.getBranches();
    final currencies = await SettingsDataHelper.getCurrencies();
    final paymentMethods = await SettingsDataHelper.getPaymentMethods();
    
    setState(() {
      _transferTypes = transferTypes;
      _branches = branches;
      _currencies = currencies;
      _paymentMethods = paymentMethods;
    });
  }
  
  Future<void> _loadCustomers() async {
    final customers = await ApiService.getAccounts();
    setState(() {
      _customers = customers;
    });
  }
  
  void _calculatePayable() {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final buyRate = double.tryParse(_buyRateCtrl.text) ?? 0;
    final sellRate = double.tryParse(_sellRateCtrl.text) ?? 0;
    
    if (amount > 0 && sellRate > 0) {
      // Calculate payable amount based on sell rate
      final payable = amount * sellRate;
      _payableCtrl.text = payable.toStringAsFixed(2);
    } else if (amount > 0 && buyRate > 0) {
      // Calculate payable amount based on buy rate
      final payable = amount * buyRate;
      _payableCtrl.text = payable.toStringAsFixed(2);
    }
  }
  
  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        // Prepare transfer data
        final transferData = {
          'transactionPurposeId': _transactionPurposeId,
          'receiverBranchId': _receiverBranchId,
          'isPayableFromAllBranches': _isPayableFromAllBranches,
          'purchaseCurrencyId': _purchaseCurrencyId,
          'salesCurrencyId': _salesCurrencyId,
          'amount': double.tryParse(_amountCtrl.text) ?? 0,
          'payable': double.tryParse(_payableCtrl.text) ?? 0,
          'commission': double.tryParse(_commissionCtrl.text) ?? 0,
          'buyRate': double.tryParse(_buyRateCtrl.text) ?? 0,
          'sellRate': double.tryParse(_sellRateCtrl.text) ?? 0,
          'commissionUnitId': _commissionUnitId,
          'treasuryId': _treasuryId,
          'senderId': _senderId,
          'senderFirstName': _senderFirstNameCtrl.text,
          'senderLastName': _senderLastNameCtrl.text,
          'senderAccountNumber': _senderAccountNumberCtrl.text,
          'senderMobile': _senderMobileCtrl.text,
          'recipientFirstName': _recipientFirstNameCtrl.text,
          'recipientLastName': _recipientLastNameCtrl.text,
          'recipientEmail': _recipientEmailCtrl.text,
          'recipientMobile': _recipientMobileCtrl.text,
        };
        
        // Remove null values
        transferData.removeWhere((key, value) => value == null || value == '');
        
        // Submit to API
        final response = await ApiService.postTransferCash(transferData);
        
        if (response != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Transfer submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to submit transfer'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        title: const Text('Add Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Transaction Purpose
            _buildSectionCard(
              'Transaction Details',
              Icons.swap_horiz,
              Colors.blue,
              [
                _buildDropdown(
                  'Transaction Purpose *',
                  _transactionPurposeId,
                  _transferTypes,
                  (val) => setState(() => _transactionPurposeId = val),
                  validator: (val) => val == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  'Select Receiver',
                  _receiverBranchId,
                  _branches,
                  (val) => setState(() => _receiverBranchId = val),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Payable from all Branches in Province'),
                  value: _isPayableFromAllBranches,
                  onChanged: (val) => setState(() => _isPayableFromAllBranches = val ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Currency & Amount
            _buildSectionCard(
              'Currency & Amount',
              Icons.attach_money,
              Colors.orange,
              [
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        'Purchase Currency *',
                        _purchaseCurrencyId,
                        _currencies,
                        (val) => setState(() => _purchaseCurrencyId = val),
                        validator: (val) => val == null ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        'Sales Currency *',
                        _salesCurrencyId,
                        _currencies,
                        (val) => setState(() => _salesCurrencyId = val),
                        validator: (val) => val == null ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Buy Rate',
                        _buyRateCtrl,
                        TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        'Sell Rate',
                        _sellRateCtrl,
                        TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Amount *',
                        _amountCtrl,
                        TextInputType.number,
                        validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        'Payable (Auto-calculated)',
                        _payableCtrl,
                        TextInputType.number,
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Commission *',
                        _commissionCtrl,
                        TextInputType.number,
                        validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        'Commission Unit *',
                        _commissionUnitId,
                        _currencies,
                        (val) => setState(() => _commissionUnitId = val),
                        validator: (val) => val == null ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  'Treasury Selection *',
                  _treasuryId,
                  _paymentMethods,
                  (val) => setState(() => _treasuryId = val),
                  validator: (val) => val == null ? 'Required' : null,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Sender Details
            _buildSectionCard(
              'Sender (Customer Search)',
              Icons.person_search,
              Colors.green,
              [
                _buildCustomerDropdown(
                  'Sender (Customer Search) *',
                  _senderId,
                  _customers,
                  (val) {
                    setState(() {
                      _senderId = val;
                      // Auto-fill sender details from selected customer
                      if (val != null) {
                        final customer = _customers.firstWhere(
                          (c) => c['id'] == val,
                          orElse: () => {},
                        );
                        _senderFirstNameCtrl.text = customer['firstName']?.toString() ?? '';
                        _senderLastNameCtrl.text = customer['lastName']?.toString() ?? '';
                        _senderAccountNumberCtrl.text = customer['accountNumber']?.toString() ?? '';
                        _senderMobileCtrl.text = customer['mobile']?.toString() ?? '';
                      }
                    });
                  },
                  validator: (val) => val == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'First Name',
                        _senderFirstNameCtrl,
                        TextInputType.text,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        'Account Number',
                        _senderAccountNumberCtrl,
                        TextInputType.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'last Name',
                        _senderLastNameCtrl,
                        TextInputType.text,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        'Mobile',
                        _senderMobileCtrl,
                        TextInputType.phone,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Recipient Details
            _buildSectionCard(
              'Recipient Details',
              Icons.person_outline,
              Colors.purple,
              [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'First Name *',
                        _recipientFirstNameCtrl,
                        TextInputType.text,
                        validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        'last Name',
                        _recipientLastNameCtrl,
                        TextInputType.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'Email',
                        _recipientEmailCtrl,
                        TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        'Mobile',
                        _recipientMobileCtrl,
                        TextInputType.phone,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Attachments
            _buildSectionCard(
              'Attachments',
              Icons.attach_file,
              Colors.teal,
              [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.grey[600]),
                        const SizedBox(height: 8),
                        Text(
                          'Upload Attachments',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Submit Transfer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionCard(String title, IconData icon, MaterialColor color, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color[600]!, color[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextField(
    String label,
    TextEditingController controller,
    TextInputType keyboardType, {
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey[100] : null,
      ),
      validator: validator,
    );
  }
  
  Widget _buildDropdown(
    String label,
    int? value,
    List<Map<String, dynamic>> items,
    Function(int?) onChanged, {
    String? Function(int?)? validator,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: items.map((item) {
        return DropdownMenuItem<int>(
          value: item['id'] as int,
          child: Text(item['title']?.toString() ?? item['name']?.toString() ?? 'N/A'),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
  
  Widget _buildCustomerDropdown(
    String label,
    int? value,
    List<Map<String, dynamic>> items,
    Function(int?) onChanged, {
    String? Function(int?)? validator,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      isExpanded: true,
      items: items.map((item) {
        final firstName = item['firstName']?.toString() ?? '';
        final lastName = item['lastName']?.toString() ?? '';
        final mobile = item['mobile']?.toString() ?? '';
        final accountNumber = item['accountNumber']?.toString() ?? '';
        final displayText = '$firstName $lastName${mobile.isNotEmpty ? ' - $mobile' : ''}${accountNumber.isNotEmpty ? ' (Acc: $accountNumber)' : ''}';
        
        return DropdownMenuItem<int>(
          value: item['id'] as int,
          child: Text(
            displayText,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
