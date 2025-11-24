import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'settings_page.dart';
import 'services/api_service.dart';

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
  final _identityNoCtrl = TextEditingController();
  final _passportStartDateCtrl = TextEditingController();
  final _passportExpiryDateCtrl = TextEditingController();

  String? gender;
  int? identityTypeId;
  String? selectedIdentityTypeName;
  int? accountTypeId;
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
  List<Map<String, dynamic>> _identityTypes = [];
  List<Map<String, dynamic>> _accountTypes = [];
  
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
    
    setState(() {
      _countries = countries;
      _allProvinces = provinces;
      _allZones = zones;
      _identityTypes = identityTypes;
      _accountTypes = accountTypes;
    });
  }
  
  /// فیلتر کردن استان‌ها بر اساس کشور انتخاب شده
  void _filterProvincesByCountry(int? selectedCountryId) {
    if (selectedCountryId == null) {
      setState(() {
        _filteredProvinces = [];
        _filteredZones = [];
      });
      return;
    }
    
    setState(() {
      _filteredProvinces = _allProvinces
          .where((p) => p['parentId'] == selectedCountryId)
          .toList();
      _filteredZones = _allZones
          .where((z) => z['countryId'] == selectedCountryId)
          .toList();
      provinceId = null;
      zoneId = null;
    });
  }
  
  /// فیلتر کردن مناطق بر اساس استان انتخاب شده
  void _filterZonesByProvince(int? selectedProvinceId) {
    if (selectedProvinceId == null) {
      return;
    }
    
    setState(() {
      _filteredZones = _filteredZones
          .where((z) => z['parentId'] == selectedProvinceId)
          .toList();
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

      final uri = Uri.parse("https://api1.katawazexchange.com/api/account/postAccountAttachment");

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add form fields
      request.fields.addAll({
        'firstName': _firstNameCtrl.text,
        'lastName': _lastNameCtrl.text,
        'gender': gender ?? '',
        'identityTypeId': identityTypeId?.toString() ?? '',
        'identityNo': _identityNoCtrl.text,
        'accountTypeId': accountTypeId?.toString() ?? '',
        'mobile': _mobileCtrl.text,
        'email': _emailCtrl.text,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Saved successfully: ${data['message'] ?? 'OK'}')),
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
              _dropdown('Gender', ['Male', 'Female'], (v) => gender = v, Icons.wc),
              _input(_mobileCtrl, 'Mobile Number', Icons.phone),
              _input(_emailCtrl, 'Email', Icons.email, required: false),
              
              _dynamicDropdown(
                'Account Type',
                _accountTypes,
                (id) => setState(() => accountTypeId = id),
                Icons.account_balance,
              ),
              
              const SizedBox(height: 20),
              const Divider(),
              
              // Identity Information
              const Text(
                'Identity Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              _dynamicDropdown(
                'Identity Type',
                _identityTypes,
                (id) {
                  setState(() {
                    identityTypeId = id;
                    // Check if selected identity type is passport
                    final selected = _identityTypes.firstWhere(
                      (item) => item['id'] == id,
                      orElse: () => {},
                    );
                    selectedIdentityTypeName = selected['name']?.toString().toLowerCase() ?? '';
                    _isPassport = selectedIdentityTypeName?.contains('passport') ?? false;
                    
                    // Clear passport fields if not passport
                    if (!_isPassport) {
                      _passportStartDateCtrl.clear();
                      _passportExpiryDateCtrl.clear();
                    }
                  });
                },
                Icons.badge,
              ),
              
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
              
              _dynamicDropdown(
                'Province',
                _filteredProvinces,
                (id) {
                  setState(() => provinceId = id);
                  _filterZonesByProvince(id);
                },
                Icons.location_city,
                enabled: countryId != null,
              ),
              
              _dynamicDropdown(
                'Zone',
                _filteredZones,
                (id) => setState(() => zoneId = id),
                Icons.location_on,
                enabled: countryId != null,
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

  Widget _dropdown(
    String label,
    List<String> items,
    Function(String?) onChanged,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? 'Please select $label' : null,
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
                return DropdownMenuItem<int>(
                  value: item['id'] as int,
                  child: Text(item['title']?.toString() ?? 'N/A'),
                );
              }).toList(),
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
