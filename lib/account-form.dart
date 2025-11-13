import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CustomerFormPage extends StatefulWidget {
  const CustomerFormPage({super.key});

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String? gender;
  String? identityType;
  String? country;
  String? province;
  String? zone;

  File? customerPhoto;
  File? idFront;
  File? idBack;

  bool _isLoading = false;

  Future<void> pickImage(Function(File) setter) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => setter(File(picked.path)));
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse("https://209.42.25.31:7179//api/account/postAccountAttachment");

      final request = http.MultipartRequest('POST', uri);

      // Add form fields
      request.fields.addAll({
        'firstName': _firstNameCtrl.text,
        'lastName': _lastNameCtrl.text,
        'gender': gender ?? '',
        'identityType': identityType ?? '',
        'mobile': _mobileCtrl.text,
        'email': _emailCtrl.text,
        'address': _addressCtrl.text,
        'country': country ?? '',
        'province': province ?? '',
        'zone': zone ?? '',
      });

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
      appBar: AppBar(title: const Text('Add Customer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _input(_firstNameCtrl, 'First Name'),
              _input(_lastNameCtrl, 'Last Name'),
              _dropdown('Gender', ['Male', 'Female'], (v) => gender = v),
              _input(_mobileCtrl, 'Mobile Number'),
              _input(_emailCtrl, 'Email'),
              _input(_addressCtrl, 'Address'),
              _dropdown('Identity Type', ['Passport', 'Tazkira', 'National ID'], (v) => identityType = v),
              _dropdown('Country', ['Afghanistan', 'Iran', 'Pakistan'], (v) => country = v),
              _dropdown('Province', ['Kabul', 'Herat', 'Kandahar'], (v) => province = v),
              _dropdown('Zone', ['North', 'South', 'East', 'West'], (v) => zone = v),

              const SizedBox(height: 10),
              const Text('Upload Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _imageBox('Customer', customerPhoto, () => pickImage((f) => customerPhoto = f)),
                  _imageBox('ID Front', idFront, () => pickImage((f) => idFront = f)),
                  _imageBox('ID Back', idBack, () => pickImage((f) => idBack = f)),
                ],
              ),

              const SizedBox(height: 20),

              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _saveCustomer,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Customer'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String label) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        validator: (v) => v!.isEmpty ? 'Required' : null,
      );

  Widget _dropdown(String label, List<String> items, Function(String?) onChanged) =>
      DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? 'Select $label' : null,
      );

  Widget _imageBox(String title, File? image, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
              image: image != null
                  ? DecorationImage(image: FileImage(image), fit: BoxFit.cover)
                  : null,
            ),
            child: image == null
                ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                : null,
          ),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
