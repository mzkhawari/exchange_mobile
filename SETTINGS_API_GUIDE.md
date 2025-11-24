# راهنمای استفاده از صفحه تنظیمات (Settings Page)

## مقدمه
صفحه تنظیمات برای مدیریت و ذخیره‌سازی داده‌های مرجع (Master Data) از API‌ها طراحی شده است. این داده‌ها در `SharedPreferences` ذخیره می‌شوند و در فرم‌های مختلف قابل استفاده هستند.

## ساختار فایل‌ها

### 1. `settings_page.dart`
- صفحه اصلی تنظیمات
- نمایش داده‌های ذخیره شده
- دکمه‌های همگام‌سازی و پاک کردن کش
- کلاس `SettingsDataHelper` برای دسترسی آسان به داده‌ها

### 2. استفاده در فرم‌ها (مثال: `account-form.dart`)
```dart
import 'settings_page.dart';

// در initState:
final countries = await SettingsDataHelper.getCountries();
final provinces = await SettingsDataHelper.getProvinces();
```

## نحوه افزودن API جدید

### مرحله 1: افزودن متغیر در `_SettingsPageState`

```dart
class _SettingsPageState extends State<SettingsPage> {
  // داده‌های موجود...
  List<Map<String, dynamic>> _countries = [];
  
  // ✅ API جدید خود را اضافه کنید
  List<Map<String, dynamic>> _yourNewData = [];
  
  // ...
}
```

### مرحله 2: بارگذاری از Cache در `_loadCachedData()`

```dart
Future<void> _loadCachedData() async {
  final prefs = await SharedPreferences.getInstance();
  
  // داده‌های موجود...
  final countriesJson = prefs.getString('settings_countries');
  
  // ✅ API جدید
  final yourNewDataJson = prefs.getString('settings_your_new_data');
  
  setState(() {
    _countries = countriesJson != null ? ... : [];
    
    // ✅ تبدیل JSON به List
    _yourNewData = yourNewDataJson != null 
        ? List<Map<String, dynamic>>.from(jsonDecode(yourNewDataJson)) 
        : [];
  });
}
```

### مرحله 3: فراخوانی API در `_syncAllData()`

```dart
Future<void> _syncAllData() async {
  final prefs = await SharedPreferences.getInstance();
  
  try {
    // ✅ فراخوانی API واقعی
    final yourNewData = await ApiService.getYourNewData(); // API خود را بنویسید
    
    // یا استفاده از داده نمونه موقت:
    final sampleYourNewData = [
      {'id': 1, 'name': 'Sample 1', 'code': 'S1'},
      {'id': 2, 'name': 'Sample 2', 'code': 'S2'},
    ];
    
    // ✅ ذخیره در SharedPreferences
    await prefs.setString(
      'settings_your_new_data',
      jsonEncode(yourNewData), // یا sampleYourNewData
    );
    
    await _loadCachedData();
  } catch (e) {
    debugPrint('Error: $e');
  }
}
```

### مرحله 4: پاک کردن Cache در `_clearCache()`

```dart
Future<void> _clearCache() async {
  final prefs = await SharedPreferences.getInstance();
  
  // داده‌های موجود...
  await prefs.remove('settings_countries');
  
  // ✅ API جدید
  await prefs.remove('settings_your_new_data');
  
  await _loadCachedData();
}
```

### مرحله 5: نمایش در UI - `build()`

```dart
@override
Widget build(BuildContext context) {
  return ListView(
    children: [
      // داده‌های موجود...
      _buildDataCard('کشورها', _countries, Icons.public),
      
      // ✅ API جدید
      _buildDataCard('عنوان دلخواه', _yourNewData, Icons.your_icon),
    ],
  );
}
```

### مرحله 6: افزودن متد در `SettingsDataHelper`

```dart
class SettingsDataHelper {
  // متدهای موجود...
  
  /// ✅ دریافت داده‌های جدید
  static Future<List<Map<String, dynamic>>> getYourNewData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_your_new_data');
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }
}
```

## نحوه افزودن API به `api_service.dart`

اگر API شما در `ApiService` وجود ندارد، ابتدا آن را اضافه کنید:

```dart
class ApiService {
  // متدهای موجود...
  
  /// ✅ دریافت داده‌های جدید از API
  static Future<List<Map<String, dynamic>>> getYourNewData() async {
    try {
      final token = await getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/your-endpoint'), // آدرس API
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // اگر API آرایه برمی‌گرداند:
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        
        // اگر API آبجکت با فیلد data برمی‌گرداند:
        if (data['data'] != null && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      
      return [];
    } catch (e) {
      debugPrint('Error fetching your data: $e');
      return [];
    }
  }
}
```

## مثال کامل: افزودن API "شهرها" (Cities)

### 1. در `settings_page.dart`:

```dart
class _SettingsPageState extends State<SettingsPage> {
  List<Map<String, dynamic>> _cities = [];
  
  Future<void> _loadCachedData() async {
    final citiesJson = prefs.getString('settings_cities');
    setState(() {
      _cities = citiesJson != null 
          ? List<Map<String, dynamic>>.from(jsonDecode(citiesJson)) 
          : [];
    });
  }
  
  Future<void> _syncAllData() async {
    final cities = await ApiService.getCities();
    await prefs.setString('settings_cities', jsonEncode(cities));
  }
  
  Future<void> _clearCache() async {
    await prefs.remove('settings_cities');
  }
  
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _buildDataCard('شهرها', _cities, Icons.location_city),
      ],
    );
  }
}

class SettingsDataHelper {
  static Future<List<Map<String, dynamic>>> getCities({int? provinceId}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('settings_cities');
    if (data != null) {
      var cities = List<Map<String, dynamic>>.from(jsonDecode(data));
      if (provinceId != null) {
        cities = cities.where((c) => c['provinceId'] == provinceId).toList();
      }
      return cities;
    }
    return [];
  }
}
```

### 2. در `api_service.dart`:

```dart
static Future<List<Map<String, dynamic>>> getCities() async {
  try {
    final token = await getAuthToken();
    final response = await http.get(
      Uri.parse('$baseUrl/master/cities'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  } catch (e) {
    debugPrint('Error fetching cities: $e');
    return [];
  }
}
```

### 3. استفاده در فرم:

```dart
class _YourFormState extends State<YourForm> {
  List<Map<String, dynamic>> _cities = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    final cities = await SettingsDataHelper.getCities();
    setState(() => _cities = cities);
  }
  
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      items: _cities.map((city) {
        return DropdownMenuItem(
          value: city['id'].toString(),
          child: Text(city['name']),
        );
      }).toList(),
      onChanged: (value) {
        // ...
      },
    );
  }
}
```

## نکات مهم

### 1. نام‌گذاری کلیدها
همیشه از پیشوند `settings_` استفاده کنید:
- `settings_countries`
- `settings_provinces`
- `settings_your_data`

### 2. ساختار داده
همه داده‌ها باید حداقل `id` و `name` داشته باشند:
```dart
{
  'id': 1,
  'name': 'نام',
  'code': 'کد اختیاری',
  // سایر فیلدها...
}
```

### 3. فیلترینگ
برای داده‌های وابسته (مثل استان‌ها به کشور):
```dart
static Future<List<Map<String, dynamic>>> getProvinces({int? countryId}) async {
  var provinces = await _getAllProvinces();
  if (countryId != null) {
    provinces = provinces.where((p) => p['countryId'] == countryId).toList();
  }
  return provinces;
}
```

### 4. بررسی داده‌ها قبل از استفاده
```dart
final cities = await SettingsDataHelper.getCities();
if (cities.isEmpty) {
  // نمایش پیام به کاربر برای همگام‌سازی
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('لطفاً ابتدا در تنظیمات داده‌ها را همگام‌سازی کنید'),
    ),
  );
}
```

## لیست API‌های فعلی

| نام | کلید | متد Helper |
|-----|------|-----------|
| کشورها | `settings_countries` | `getCountries()` |
| استان‌ها | `settings_provinces` | `getProvinces()` |
| مناطق | `settings_zones` | `getZones()` |
| ارزها | `settings_currencies` | `getCurrencies()` |
| شعبات | `settings_branches` | `getBranches()` |
| انواع شناسنامه | `settings_identity_types` | `getIdentityTypes()` |

## مثال استفاده کامل در فرم

```dart
import 'settings_page.dart';

class MyFormPage extends StatefulWidget {
  const MyFormPage({super.key});
  
  @override
  State<MyFormPage> createState() => _MyFormPageState();
}

class _MyFormPageState extends State<MyFormPage> {
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _provinces = [];
  
  int? _selectedCountryId;
  int? _selectedProvinceId;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    final countries = await SettingsDataHelper.getCountries();
    setState(() => _countries = countries);
  }
  
  Future<void> _onCountryChanged(String? value) async {
    if (value != null) {
      final countryId = int.parse(value);
      final provinces = await SettingsDataHelper.getProvinces(
        countryId: countryId,
      );
      
      setState(() {
        _selectedCountryId = countryId;
        _provinces = provinces;
        _selectedProvinceId = null; // ریست استان
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Country Dropdown
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Country'),
            items: _countries.map((country) {
              return DropdownMenuItem(
                value: country['id'].toString(),
                child: Text(country['name']),
              );
            }).toList(),
            onChanged: _onCountryChanged,
          ),
          
          // Province Dropdown
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Province'),
            items: _provinces.map((province) {
              return DropdownMenuItem(
                value: province['id'].toString(),
                child: Text(province['name']),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedProvinceId = int.parse(value));
              }
            },
          ),
        ],
      ),
    );
  }
}
```

## پایان
این راهنما به شما کمک می‌کند تا API‌های جدید را به صفحه تنظیمات اضافه کرده و در فرم‌های خود استفاده کنید.
