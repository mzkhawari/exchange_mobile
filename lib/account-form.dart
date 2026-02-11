import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'settings_page.dart';
import 'models/gender.dart';
import 'services/api_service.dart';
import 'models/identity_type.dart';
import 'models/account_type.dart';

class CustomerFormPage extends StatefulWidget {
  const CustomerFormPage({super.key});

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityNameCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _identityNoCtrl = TextEditingController();
  final _passportStartDateCtrl = TextEditingController();
  final _passportExpiryDateCtrl = TextEditingController();

  Gender? gender;
  IdentityType? identityType;
  AccountType? accountType;
  int? countryId;
  int? provinceId;
  int? zoneId;

  File? customerPhoto;
  File? idFront;
  File? idBack;

  bool _isLoading = false;
  bool _isPassport = false;
  
  // لیست‌های داده از تنظیمات
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _allProvinces = [];
  List<Map<String, dynamic>> _allZones = [];
  
  // لیست‌های فیلتر شده
  List<Map<String, dynamic>> _filteredProvinces = [];
  List<Map<String, dynamic>> _filteredZones = [];

  @override
  void initState() {
    super.initState();
    _loadSettingsData();
  }
  
  /// بارگذاری داده‌ها از تنظیمات
  Future<void> _loadSettingsData() async {
    final countries = await SettingsDataHelper.getCountries();
    final provinces = await SettingsDataHelper.getProvinces();
    final zones = await SettingsDataHelper.getZones();
    final identityTypes = await SettingsDataHelper.getIdentityTypes();
    final accountTypes = await SettingsDataHelper.getAccountTypes();
    
    print('📊 Form Data Loaded:');
    print('   Countries: ${countries.length} items');
    print('   Provinces: ${provinces.length} items');
    print('   Zones: ${zones.length} items');
    print('   Identity Types: ${identityTypes.length} items');
    print('   Account Types: ${accountTypes.length} items');
    
    if (countries.isNotEmpty) print('   Sample Country: ${countries.first}');
    if (identityTypes.isNotEmpty) print('   Sample Identity Type: ${identityTypes.first}');
    if (accountTypes.isNotEmpty) print('   Sample Account Type: ${accountTypes.first}');
    
    setState(() {
      _countries = countries;
      _allProvinces = provinces;
      _allZones = zones;
    });
    
    // نمایش پیام اخطار اگر داده‌ها خالی باشند
    if (mounted && (countries.isEmpty || identityTypes.isEmpty || accountTypes.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Some dropdown data is missing. Please sync data in Settings page.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
  
  /// فیلتر کردن استان‌ها و زون‌ها بر اساس کشور انتخاب شده
  void _filterProvincesByCountry(int? selectedCountryId) {
    if (selectedCountryId == null) {
      setState(() {
        _filteredProvinces = [];
        _filteredZones = [];
        provinceId = null;
        zoneId = null;
      });
      return;
    }
    
    setState(() {
      // فیلتر استان‌ها و زون‌های مربوط به کشور انتخاب شده
      _filteredProvinces = _allProvinces
          .where((p) => p['parentId'] == selectedCountryId)
          .toList();
      _filteredZones = _allZones
          .where((z) => z['parentId'] == selectedCountryId)
          .toList();
      provinceId = null;
      zoneId = null;
    });
  }

  Future<void> pickImage(Function(File) setter) async {
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: source);
      if (picked != null) setState(() => setter(File(picked.path)));
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final token = await ApiService.getAuthToken();
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ No authentication token available')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final uri = Uri.parse("https://209.42.25.31:7179/api/accountMob/postAccountAttachment");

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add form fields
      request.fields.addAll({
        'firstName': _firstNameCtrl.text,
        'lastName': _lastNameCtrl.text,
        'gender': gender != null ? gender!.code.toString() : '',
        'identityTypeId': identityType?.code.toString() ?? '',
        'identityNo': _identityNoCtrl.text,
        'accountTypeId': accountType?.code.toString() ?? '',
        'mobile': _mobileCtrl.text,
        'email': _emailCtrl.text,
        'cityName': _cityNameCtrl.text,
        'postalCode': _postalCodeCtrl.text,
        'address': _addressCtrl.text,
        'countryId': countryId?.toString() ?? '',
        'provinceId': provinceId?.toString() ?? '',
        'zoneId': zoneId?.toString() ?? '',
      });
      
      // Add passport dates if passport is selected
      if (_isPassport) {
        request.fields.addAll({
          'passportStartDate': _passportStartDateCtrl.text,
          'passportExpiryDate': _passportExpiryDateCtrl.text,
        });
      }

      // Add images if selected
      if (customerPhoto != null) {
        request.files.add(await http.MultipartFile.fromPath('customerPhoto', customerPhoto!.path));
      }
      if (idFront != null) {
        request.files.add(await http.MultipartFile.fromPath('idFront', idFront!.path));
      }
      if (idBack != null) {
        request.files.add(await http.MultipartFile.fromPath('idBack', idBack!.path));
      }

      // Send request
      final response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        final message = data is Map && data['message'] != null
            ? data['message'].toString()
            : (data == true ? 'OK' : 'OK');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Saved successfully: $message')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Customer'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personal Information
              const Text(
                'Personal Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              _input(_firstNameCtrl, 'First Name', Icons.person),
              _input(_lastNameCtrl, 'Last Name', Icons.person_outline),
              _genderDropdown(),
              _input(_mobileCtrl, 'Mobile Number', Icons.phone),
              _input(_emailCtrl, 'Email', Icons.email, required: false),
              
              _accountTypeDropdown(),
              
              const SizedBox(height: 20),
              const Divider(),
              
              // Identity Information
              const Text(
                'Identity Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              _identityTypeDropdown(),
              
              _input(_identityNoCtrl, 'Identity Number', Icons.numbers),
              
              // Show passport date fields only if passport is selected
              if (_isPassport) ...[
                _datePickerField(
                  _passportStartDateCtrl,
                  'Passport Start Date',
                  Icons.calendar_today,
                ),
                _datePickerField(
                  _passportExpiryDateCtrl,
                  'Passport Expiry Date',
                  Icons.calendar_month,
                ),
              ],
              
              const SizedBox(height: 20),
              const Divider(),
              
              // Location Information
              const Text(
                'Location Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              _dynamicDropdown(
                'Country',
                _countries,
                (id) {
                  setState(() => countryId = id);
                  _filterProvincesByCountry(id);
                },
                Icons.public,
              ),
              
              _combinedProvinceZoneDropdown(),
              Row(
                children: [
                  Expanded(
                    child: _input(_cityNameCtrl, 'City', Icons.location_city, required: false),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _input(_postalCodeCtrl, 'Postal Code', Icons.local_post_office, required: false),
                  ),
                ],
              ),
              
              _input(_addressCtrl, 'Full Address', Icons.home, maxLines: 3),

              const SizedBox(height: 20),
              const Divider(),
              
              // Upload Documents
              const Text(
                'Upload Documents',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _imageBox('Customer Photo', customerPhoto, () => pickImage((f) => customerPhoto = f)),
                  _imageBox('ID Front', idFront, () => pickImage((f) => idFront = f)),
                  _imageBox('ID Back', idBack, () => pickImage((f) => idBack = f)),
                ],
              ),

              const SizedBox(height: 30),

              // Save Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveCustomer,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Customer', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController c,
    String label,
    IconData icon, {
    bool required = true,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: required ? (v) => v!.isEmpty ? 'This field is required' : null : null,
      ),
    );
  }

  Widget _genderDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<Gender>(
        decoration: InputDecoration(
          labelText: 'Gender',
          prefixIcon: const Icon(Icons.wc),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        initialValue: gender,
        items: Gender.values
            .map((g) => DropdownMenuItem<Gender>(
                  value: g,
                  child: Text(g.label),
                ))
            .toList(),
        onChanged: (g) => setState(() => gender = g),
        validator: (v) => v == null ? 'Please select Gender' : null,
      ),
    );
  }

  Widget _identityTypeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<IdentityType>(
        decoration: InputDecoration(
          labelText: 'Identity Type',
          prefixIcon: const Icon(Icons.badge),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        initialValue: identityType,
        items: IdentityType.values
            .map((t) => DropdownMenuItem<IdentityType>(
                  value: t,
                  child: Text(t.label),
                ))
            .toList(),
        onChanged: (t) {
          setState(() {
            identityType = t;
            _isPassport = identityType == IdentityType.passport;
            if (!_isPassport) {
              _passportStartDateCtrl.clear();
              _passportExpiryDateCtrl.clear();
            }
          });
        },
        validator: (v) => v == null ? 'Please select Identity Type' : null,
      ),
    );
  }

  Widget _accountTypeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<AccountType>(
        decoration: InputDecoration(
          labelText: 'Account Type',
          prefixIcon: const Icon(Icons.account_balance),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        initialValue: accountType,
        items: AccountType.values
            .map((t) => DropdownMenuItem<AccountType>(
                  value: t,
                  child: Text(t.label),
                ))
            .toList(),
        onChanged: (t) => setState(() => accountType = t),
        validator: (v) => v == null ? 'Please select Account Type' : null,
      ),
    );
  }

  Widget _combinedProvinceZoneDropdown() {
    // ترکیب استان‌ها و زون‌ها در یک لیست
    final combinedList = <Map<String, dynamic>>[
      ..._filteredProvinces.map((p) => {...p, 'type': 'province'}),
      ..._filteredZones.map((z) => {...z, 'type': 'zone'}),
    ];

    // مقدار انتخاب شده را به عنوان String ذخیره می‌کنیم
    String? selectedValue;
    if (provinceId != null || zoneId != null) {
      final id = provinceId ?? zoneId;
      final item = combinedList.firstWhere(
        (item) => item['id'] == id,
        orElse: () => {},
      );
      if (item.isNotEmpty) {
        selectedValue = '${item['id']}_${item['type']}';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Province / Zone',
          prefixIcon: const Icon(Icons.location_city),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: countryId != null ? Colors.grey[50] : Colors.grey[200],
          suffixIcon: combinedList.isEmpty
              ? const Icon(Icons.warning, color: Colors.orange)
              : null,
        ),
        initialValue: selectedValue,
        items: combinedList.isEmpty
            ? null
            : combinedList.map((item) {
                final id = (item['id'] as num?)?.toInt();
                final title = item['title']?.toString() ?? item['name']?.toString() ?? 'N/A';
                final type = item['type'] == 'province' ? 'Province' : 'Zone';
                final valueStr = '${id}_${item['type']}';
                return DropdownMenuItem<String>(
                  value: valueStr,
                  child: Text('$title ($type)'),
                );
              }).where((e) => e.value != null).toList(),
        onChanged: countryId != null && combinedList.isNotEmpty
            ? (valueStr) {
                if (valueStr != null) {
                  final parts = valueStr.split('_');
                  final id = int.tryParse(parts[0]);
                  setState(() {
                    // هر دو مقدار را ست می‌کنیم
                    provinceId = id;
                    zoneId = id;
                  });
                }
              }
            : null,
        validator: (v) => v == null ? 'Please select Province / Zone' : null,
        hint: combinedList.isEmpty
            ? const Text('No data available - Please sync in Settings')
            : countryId == null
                ? const Text('First select Country')
                : null,
      ),
    );
  }

  Widget _dynamicDropdown(
    String label,
    List<Map<String, dynamic>> items,
    Function(int?) onChanged,
    IconData icon, {
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int>(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: enabled ? Colors.grey[50] : Colors.grey[200],
          suffixIcon: items.isEmpty
              ? const Icon(Icons.warning, color: Colors.orange)
              : null,
        ),
        items: items.isEmpty
            ? null
            : items.map((item) {
                final value = (item['id'] as num?)?.toInt();
                final label = item['title']?.toString() ?? item['name']?.toString() ?? 'N/A';
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(label),
                );
              }).where((e) => e.value != null).toList(),
        onChanged: enabled && items.isNotEmpty ? onChanged : null,
        validator: (v) => v == null ? 'Please select $label' : null,
        hint: items.isEmpty
            ? const Text('No data available - Please sync in Settings')
            : !enabled
                ? Text('First select ${_getParentFieldName(label)}')
                : null,
      ),
    );
  }
  
  String _getParentFieldName(String label) {
    if (label == 'Province') return 'Country';
    if (label == 'Zone') return 'Province';
    return '';
  }
  
  Widget _datePickerField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            setState(() {
              controller.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
            });
          }
        },
        validator: (v) => v!.isEmpty ? 'This field is required' : null,
      ),
    );
  }

  Widget _imageBox(String title, File? image, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 2),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[100],
              image: image != null
                  ? DecorationImage(image: FileImage(image), fit: BoxFit.cover)
                  : null,
            ),
            child: image == null
                ? const Icon(Icons.camera_alt, size: 40, color: Colors.blue)
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
