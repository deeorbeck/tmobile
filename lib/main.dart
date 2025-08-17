// ignore_for_file: avoid_print, use_build_context_synchronously, library_private_types_in_public_api

import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:version/version.dart';


// ----------------------------------------------------------------------------- 
// --- LOYIHAGA QO'SHILADIGAN BOG'LIQLIKLAR (pubspec.yaml) ---
// ----------------------------------------------------------------------------- 
/*
  Ushbu kodni ishga tushirishdan oldin, loyihangizning `pubspec.yaml` fayliga
  quyidagi bog'liqliklarni qo'shing va `flutter pub get` buyrug'ini ishga tushiring.

  dependencies:
    flutter:
      sdk: flutter
    
    # API chaqiruvlari uchun
    http: ^1.2.1

    # Holatni boshqarish (State Management) uchun
    provider: ^6.1.2

    # Qurilma xotirasida ma'lumot saqlash uchun (localStorage ekvivalenti)
    shared_preferences: ^2.2.3

    # Ikonkalar to'plami (Lucide ikonkalarini ishlatish uchun)
    lucide_flutter: ^0.412.0

    # Tashqi havolalarni ochish uchun (masalan, Telegram)
    url_launcher: ^6.3.0

    # Fayl tanlash uchun (PDF, rasm va hokazo)
    file_picker: ^8.0.6
    
    # "Share" (Ulashish) funksiyasi uchun
    share_plus: ^9.0.0
    
    # Chiziqli chegara (dashed border) chizish uchun
    dotted_border: ^2.1.0

    # Rasm tanlash uchun (avatar)
    image_picker: ^1.1.2
*/
// ----------------------------------------------------------------------------- 
// --- ILOVANING ASOSIY KIRISH NUQTASI (main.dart) ---
// ----------------------------------------------------------------------------- 

void main() {
  print("App started!"); // ADDED FOR DEBUG
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AuthProvider butun ilova uchun state management'ni ta'minlaydi
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: Builder(
        builder: (context) {
          final themeProvider = Provider.of<AuthProvider>(context);
          return MaterialApp(
            title: 'Taqdimot Mobile',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            home: const VersionCheckWrapper(),
          );
        },
      ),
    );
  }
}

// Ilova versiyasini tekshirib, yangilanish kerak bo'lsa, muloqot oynasini ko'rsatadi
class VersionCheckWrapper extends StatefulWidget {
  const VersionCheckWrapper({super.key});

  @override
  State<VersionCheckWrapper> createState() => _VersionCheckWrapperState();
}

class _VersionCheckWrapperState extends State<VersionCheckWrapper> {
  @override
  void initState() {
    super.initState();
    _performVersionCheck();
  }

  Future<void> _performVersionCheck() async {
    try {
      // Ilovaning joriy versiyasini olish
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = Version.parse(packageInfo.version);

      // API'dan eng so'nggi versiyani olish
      final response = await ApiService().getLatestVersion();
      final latestVersion = Version.parse(response['version']);

      // Versiyalarni solishtirish
      if (latestVersion > currentVersion) {
        // Yangilanish oynasini ko'rsatish
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false, // Foydalanuvchi oynani yopa olmaydi
            builder: (_) => UpdateDialog(
              onUpdate: () {
                // TODO: To'g'ri yangilanish manzilini qo'shing (masalan, Play Store)
                // Hozircha Google Play'ning taxminiy manzili ishlatiladi
                launchUrl(Uri.parse("https://play.google.com/store/apps/details?id=com.example.nftmobile"));
              },
            ),
          );
        }
      } else {
        // Yangilanish kerak bo'lmasa, asosiy ilovaga o'tish
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthChecker()),
          );
        }
      }
    } catch (e) {
      print("Versiyani tekshirishda xatolik: $e");
      // Xatolik yuz bersa ham, ilovaga o'tib ketish
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthChecker()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tekshiruv vaqtida yuklanish ekranini ko'rsatish
    return const FullScreenLoader();
  }
}

// Yangilanish kerakligi haqida muloqot oynasi
class UpdateDialog extends StatelessWidget {
  final VoidCallback onUpdate;
  const UpdateDialog({super.key, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Orqaga tugmasi bilan yopib bo'lmaydi
      child: AlertDialog(
        title: const Text("Yangilanish Mavjud"),
        content: const Text("Ilovaning yangi versiyasi chiqdi. Iltimos, davom etish uchun ilovani yangilang."),
        actions: [
          TextButton(
            onPressed: onUpdate,
            child: const Text("Yangilash"),
          ),
        ],
      ),
    );
  }
}


// Foydalanuvchi tizimga kirgan yoki kirmaganligini tekshiradi
class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.isLoading) {
          return const FullScreenLoader();
        }
        return auth.isLoggedIn ? const HomeWrapper() : const LoginScreen();
      },
    );
  }
}

// ----------------------------------------------------------------------------- 
// --- KONSTANTALAR VA MODELLAR ---
// ----------------------------------------------------------------------------- 

// API manzili
const String apiBaseUrl = 'https://api.tm.ismailov.uz'; 

// Shablonlar ma'lumotlari
final Map<String, List<String>> templateData = {
  'Popular': ['slice', 'circuit', 'droplet', 'littlechild', 'abstract', 'paperplane', 'facet', 'wood', 'lon', 'aesthetic'],
  'Classic': ['dim', 'medison', 'berlin', 'savon', 'ugolki', 'medic', 'damask', 'emblema', 'nature', 'vid'],
  'Education': ['dark', 'pentogram', 'blueprint', 'analyze', 'ribbon', 'pencils', 'green', 'reflection', 'digital', 'cosmic'],
  'Modern': ['dividend', 'pretty', 'sitdolor', 'kids', 'stairs', 'white', 'shell', 'digitalocean', 'book', 'draw']
};
const String baseTemplateUrl = 'https://taqdimot.ismailov.uz/images/';

// Foydalanuvchi modeli
class User {
  final int id;
  final int chatId;
  final String fullName;
  final String lang;
  final int balance;
  final int pricePresentation;
  final int pricePresentationWithImages;
  final int priceAbstract;
  final String? token;

  User({
    required this.id,
    required this.chatId,
    required this.fullName,
    required this.lang,
    required this.balance,
    required this.pricePresentation,
    required this.pricePresentationWithImages,
    required this.priceAbstract,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    print('User.fromJson - Raw JSON: $json'); // ADDED FOR DEBUG
    final balanceValue = (json['balance'] as num?)?.toInt() ?? 0; // FIXED BALANCE PARSING
    print('User.fromJson - Parsed Balance: $balanceValue'); // ADDED FOR DEBUG
    return User(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      chatId: int.tryParse(json['chat_id']?.toString() ?? '0') ?? 0,
      fullName: json['full_name'] ?? 'Noma\'lum foydalanuvchi',
      lang: json['lang'] ?? 'uz',
      balance: balanceValue,
      pricePresentation: int.tryParse(json['price_presentation']?.toString() ?? '0') ?? 0,
      pricePresentationWithImages: int.tryParse(json['price_presentation_with_images']?.toString() ?? '0') ?? 0,
      priceAbstract: int.tryParse(json['price_abstract']?.toString() ?? '0') ?? 0,
      token: json['token'],
    );
  }
}

// Hujjat modeli
class Document {
  final String id;
  final String title;
  final String date;
  final String localPath;
  final String? mimeType;

  Document({required this.id, required this.title, required this.date, required this.localPath, this.mimeType});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date,
        'localPath': localPath,
        'mimeType': mimeType,
      };

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      title: json['title'],
      date: json['date'],
      localPath: json['localPath'],
      mimeType: json['mimeType'],
    );
  }
}

// Maxsus xatolik klassi
class PaymentRequiredException implements Exception {
  final String message;
  final int requiredAmount;

  PaymentRequiredException({required this.message, required this.requiredAmount});

  @override
  String toString() {
    return message;
  }
}


// ----------------------------------------------------------------------------- 
// --- API SERVISI (Barcha tarmoq so'rovlari) ---
// ----------------------------------------------------------------------------- 

class ApiService {
  final String _baseUrl = apiBaseUrl;

  Future<dynamic> _enhancedFetch(String url, {String method = 'GET', Map<String, String>? headers, Object? body}) async {
    final defaultHeaders = {
      'ngrok-skip-browser-warning': 'true',
      'Content-Type': 'application/json; charset=UTF-8',
    };

    if (headers != null) {
      defaultHeaders.addAll(headers);
    }
    
    try {
      http.Response response;
      final uri = Uri.parse(url);

      if (method == 'POST') {
        response = await http.post(uri, headers: defaultHeaders, body: jsonEncode(body));
      } else {
        response = await http.get(uri, headers: defaultHeaders);
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = utf8.decode(response.bodyBytes);
        print('API Response for $url: $responseBody'); // ADDED FOR DEBUG
        return responseBody.isNotEmpty ? jsonDecode(responseBody) : {};
      } else {
        final errorText = utf8.decode(response.bodyBytes);
        print('API Error Response for $url (Status: ${response.statusCode}): $errorText'); // ADDED FOR DEBUG
        final errorJson = jsonDecode(errorText);

        if (response.statusCode == 402) {
          throw PaymentRequiredException(
            message: errorJson['detail'] ?? 'To\'lov talab qilinadi',
            requiredAmount: (errorJson['required_balance'] as num?)?.toInt() ?? 0,
          );
        }
        
        throw Exception(errorJson['detail'] ?? 'Server xatosi: ${response.statusCode}');
      }
    } on http.ClientException catch(e) {
        print('Network request failed: $e');
        throw Exception("Serverga ulanib bo'lmadi. Internet aloqasini tekshiring.");
    } catch (e) {
      // Re-throw custom exceptions or handle others
      if (e is PaymentRequiredException) {
        rethrow;
      }
      print('An unexpected error occurred: $e');
      throw Exception("Kutilmagan xatolik yuz berdi.");
    }
  }

  Future<User> login(String code) async {
    final data = await _enhancedFetch('$_baseUrl/login/$code');
    return User.fromJson(data);
  }

  Future<User> getMe(String token) async {
    final data = await _enhancedFetch('$_baseUrl/get-me?token=$token');
    return User.fromJson(data);
  }

  Future<Map<String, dynamic>> uploadFile(String endpoint, File file, {Function(double)? onProgress}) async {
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/$endpoint'));
    request.headers['ngrok-skip-browser-warning'] = 'true';
    String? mimeType;
    String fileExtension = file.path.split('.').last.toLowerCase();
    if (fileExtension == 'jpg' || fileExtension == 'jpeg') {
      mimeType = 'image/jpeg';
    } else if (fileExtension == 'png') {
      mimeType = 'image/png';
    }

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: mimeType != null ? MediaType.parse(mimeType) : null,
    ));

    final response = await request.send();
    
    if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        return jsonDecode(responseBody);
    } else {
        final responseBody = await response.stream.bytesToString();
        final errorJson = jsonDecode(responseBody);
        throw Exception(errorJson['detail'] ?? 'Fayl yuklashda xatolik');
    }
  }

  Future<Map<String, dynamic>> uploadSource(File file, {Function(double)? onProgress}) {
      return uploadFile('upload_source', file, onProgress: onProgress);
  }

  Future<Map<String, dynamic>> uploadImage(File file) {
      return uploadFile('upload_image', file);
  }
  
  Future<dynamic> generateContent(Map<String, dynamic> data) {
    return _enhancedFetch('$_baseUrl/generate_content', method: 'POST', body: data);
  }

  Future<dynamic> regenerateSlideContent(Map<String, dynamic> data) {
    return _enhancedFetch('$_baseUrl/regenerate_slide_content', method: 'POST', body: data);
  }

  Future<dynamic> createFile(Map<String, dynamic> data) {
    return _enhancedFetch('$_baseUrl/create_file', method: 'POST', body: data);
  }
  
  Future<dynamic> getFileStatus(String taskId) {
    return _enhancedFetch('$_baseUrl/file_status/$taskId');
  }

  Future<dynamic> getImageUrl(String topic) {
    return _enhancedFetch('$_baseUrl/get_image_url?topic=$topic');
  }
  
  Future<dynamic> createPaymentLink(Map<String, dynamic> data) {
    return _enhancedFetch('$_baseUrl/create_payment_link', method: 'POST', body: data);
  }

  Future<dynamic> checkPaymentStatus(String paymentId, String token) {
    return _enhancedFetch('$_baseUrl/check_payment_status/$paymentId?token=$token');
  }

  Future<Map<String, dynamic>> getLatestVersion() async {
    final response = await _enhancedFetch('$_baseUrl/version');
    return response as Map<String, dynamic>;
  }

  Future<void> updateUserName(String token, String newName) async {
    await _enhancedFetch('$_baseUrl/update-name', method: 'POST', body: {
      'token': token,
      'new_full_name': newName,
    });
  }

  }

// ----------------------------------------------------------------------------- 
// --- HOLATNI BOSHQARISH (AuthProvider) ---
// ----------------------------------------------------------------------------- 

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoggedIn = false;
  bool _isLoading = true;
  bool _isDarkMode = true;
  List<Document> _documents = [];

  // Key for SharedPreferences
  static const String _documentsKey = 'savedDocuments';

  User? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  bool get isDarkMode => _isDarkMode;
  List<Document> get documents => _documents;

  final ApiService _apiService = ApiService();

  AuthProvider() {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadTheme();
    await checkToken();
    await _loadDocuments(); // Load documents after token check
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    notifyListeners();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  Future<void> checkToken() async {
    _isLoading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('authToken');

    if (savedToken != null) {
      try {
        final userData = await _apiService.getMe(savedToken);
        _user = userData;
        _token = savedToken;
        _isLoggedIn = true;
        print('checkToken - User balance: ${_user?.balance}'); // ADDED FOR DEBUG
      } catch (e) {
        print("Token yaroqsiz: $e");
        await logout();
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String code) async {
    try {
      final userData = await _apiService.login(code);
      _user = userData;
      _token = userData.token;
      _isLoggedIn = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('authToken', userData.token!);
      print('login - User balance: ${_user?.balance}'); // ADDED FOR DEBUG
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    _isLoggedIn = false;
    _documents = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    await prefs.remove('avatar_path'); // Clear avatar path
    await _saveDocuments(); // Save empty list on logout
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_token != null) {
      try {
        final userData = await _apiService.getMe(_token!);
        _user = userData;
        notifyListeners();
      } catch (e) {
        print("Foydalanuvchi ma'lumotlarini yangilashda xatolik: $e");
      }
    }
  }
  
  // New method to save documents
  Future<void> _saveDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = _documents.map((doc) => jsonEncode(doc.toJson())).toList();
    await prefs.setStringList(_documentsKey, jsonList);
    print('DEBUG: Documents saved: $jsonList'); // Debug print
  }

  // New method to load documents
  Future<void> _loadDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList(_documentsKey);
    if (jsonList != null) {
      _documents = jsonList.map((jsonString) => Document.fromJson(jsonDecode(jsonString))).toList();
      print('DEBUG: Documents loaded: $_documents'); // Debug print
    } else {
      _documents = [];
      print('DEBUG: No documents found in SharedPreferences.'); // Debug print
    }
    notifyListeners(); // Notify listeners after loading
  }

  void addDocument(Document newDoc) {
    _documents.insert(0, newDoc);
    _saveDocuments(); // Save after adding
    notifyListeners();
  }

  void deleteDocument(String docId) {
    _documents.removeWhere((doc) => doc.id == docId);
    _saveDocuments(); // Save after deleting
    notifyListeners();
  }

  // Foydalanuvchi ismini yangilash
  Future<void> updateUserName(String newName) async {
    if (_user == null || _token == null) return;

    // Call the API to update the name on the backend
    await _apiService.updateUserName(_token!, newName);

    // If the API call is successful, update the local user object
    _user = User(
      id: _user!.id,
      chatId: _user!.chatId,
      fullName: newName,
      lang: _user!.lang,
      balance: _user!.balance,
      pricePresentation: _user!.pricePresentation,
      pricePresentationWithImages: _user!.pricePresentationWithImages,
      priceAbstract: _user!.priceAbstract,
      token: _user!.token,
    );
    notifyListeners();
  }
}

// ----------------------------------------------------------------------------- 
// --- MAVZULAR (Theme) ---
// ----------------------------------------------------------------------------- 

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF4361EE),
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF4361EE),
      secondary: Color(0xFF3B82F6),
      surface: Color.fromRGBO(255, 255, 255, 0.9),
      background: Color(0xFFF8F9FA),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF1A202C),
      onBackground: Color(0xFF1A202C),
      tertiary: Color(0xFFE9ECEF), // subtle
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Color(0xFF1A202C)),
      headlineMedium: TextStyle(color: Color(0xFF1A202C)),
      headlineSmall: TextStyle(color: Color(0xFF1A202C)),
      bodyLarge: TextStyle(color: Color(0xFF1A202C)),
      bodyMedium: TextStyle(color: Color(0xFF1A202C)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE9ECEF))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE9ECEF))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4361EE), width: 2)),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF3B82F6),
    scaffoldBackgroundColor: const Color(0xFF0D1B2A),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF3B82F6),
      secondary: Color(0xFF4361EE),
      surface: Color.fromRGBO(27, 38, 59, 0.8),
      background: Color(0xFF0D1B2A),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFFF0F4F8),
      onBackground: Color(0xFFF0F4F8),
      tertiary: Color.fromRGBO(255, 255, 255, 0.1), // subtle
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Color(0xFFF0F4F8)),
      headlineMedium: TextStyle(color: Color(0xFFF0F4F8)),
      headlineSmall: TextStyle(color: Color(0xFFF0F4F8)),
      bodyLarge: TextStyle(color: Color(0xFFF0F4F8)),
      bodyMedium: TextStyle(color: Color(0xFFF0F4F8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2)),
    ),
  );
}

// ----------------------------------------------------------------------------- 
// --- EKRANLAR (Screens) ---
// ----------------------------------------------------------------------------- 

// --- LoginScreen ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String _error = '';

  Future<void> _handleLogin() async {
    if (_codeController.text.length != 6) {
      setState(() => _error = "Kod 6 xonali bo'lishi kerak.");
      return;
    }
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      await Provider.of<AuthProvider>(context, listen: false).login(_codeController.text);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          const AuroraBackground(),
          Center( // New Center widget for vertical centering
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center( // Existing Center for horizontal centering
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          // NetworkImage o'rniga loyihadagi AssetImage'dan foydalanamiz
                          backgroundImage: const AssetImage('assets/logo.jpg'), // <-- O'ZGARTIRILDI
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                        ),
                        const SizedBox(height: 16),
                        Text('Taqdimot Mobile', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Maxsus kod olib ilovaga kirishingiz mumkin.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8))),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () async {
                             final url = Uri.parse('https://t.me/taqdimot_robot?start=code');
                             await launchUrl(url, mode: LaunchMode.externalApplication);
                          },
                          child: Text('Kodni olish', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _codeController,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(letterSpacing: 8.0, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            counterText: '',
                            errorText: _error.isNotEmpty ? _error : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                                : const Text('Kirish', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ), // Closing GlassCard
              ), // Closing SingleChildScrollView - ADDED
            ),
          ),
        ],
      ),
    );
  }
}

// --- HomeWrapper (Asosiy ekranlarni boshqaruvchi) ---
class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  void _onItemTapped(int index) {
    if (index == 1) { // "Yaratish" tugmasi
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const CreateScreen()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
        // Adjust page index for PageView if "Yaratish" is skipped
        if (index == 0) { // Hujjatlar
          _pageController.jumpToPage(0);
        } else if (index == 2) { // Profil
          _pageController.jumpToPage(1);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const AuroraBackground(),
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
               MyDocumentsScreen(),
               ProfileScreen(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: theme.colorScheme.surface.withOpacity(0.9),
        elevation: 0,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _buildNavItem(LucideIcons.fileText, 'Hujjatlar', 0),
              SizedBox( // Fixed size for the button
                width: 56.0, // Example width, adjust as needed
                height: 56.0, // Example height, adjust as needed
                child: ElevatedButton(
                  onPressed: () => _onItemTapped(1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    padding: EdgeInsets.zero, // Remove padding from button itself
                    elevation: 2.0,
                  ),
                  child: Icon(LucideIcons.plus, color: theme.colorScheme.onPrimary),
                ),
              ),
              _buildNavItem(LucideIcons.user, 'Profil', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MyDocumentsScreen ---
class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final allDocs = authProvider.documents;

    final filteredDocs = allDocs.where((doc) {
      return doc.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_isSearching)
                  Text('Hujjatlarim', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (_isSearching)
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Qidirish...',
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(_isSearching ? LucideIcons.x : LucideIcons.search),
                  onPressed: () => setState(() => _isSearching = !_isSearching),
                  style: IconButton.styleFrom(backgroundColor: theme.colorScheme.tertiary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: filteredDocs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.fileText, size: 48, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
                          const SizedBox(height: 16),
                          const Text('Hali hech qanday hujjat yaratmadingiz.'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                               Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreateScreen()));
                            },
                            child: const Text("Birinchisini yaratish"),
                          )
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () async {
                                        try {
                                          print('DEBUG: Attempting to open file: ${doc.localPath} with MIME type: ${doc.mimeType}');
                                          final result = await OpenFile.open(
                                            doc.localPath,
                                            type: doc.mimeType
                                          );
                                          if (result.type.name != 'done') {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text("Faylni ochishda xatolik yuz berdi: ${result.message}")),
                                            );
                                            print('DEBUG: OpenFilex error: ${result.message}');
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text("Faylni ochishda kutilmagan xatolik: ${e.toString()}")),
                                          );
                                          print('DEBUG: Unexpected error opening file: $e');
                                        }
                                      },
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(doc.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          Text(doc.date, style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7))),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.share2, size: 18),
                                    onPressed: () async {
                                      await Share.shareXFiles(
                                        [XFile(doc.localPath, mimeType: doc.mimeType ?? 'application/octet-stream')],
                                        text: '@taqdimot_robot orqali tayyorlandi',
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
                                    onPressed: () => authProvider.deleteDocument(doc.id),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CreateScreen ---
class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  String docType = 'Taqdimot';
  final _fullNameController = TextEditingController();
  final _topicController = TextEditingController();
  final _universityController = TextEditingController();
  final _facultyController = TextEditingController();
  final _directionController = TextEditingController();
  final _groupController = TextEditingController();
  final _slideCountController = TextEditingController(text: '8');
  String _selectedLang = 'uz';

  final List<Map<String, String>> _languages = [
    {'code': 'uz', 'name': "🇺🇿 O'zbekcha"},
    {'code': 'kq', 'name': "🇺🇿 Qoraqalpoqcha"},
    {'code': 'ru', 'name': "🇷🇺 Русский"},
    {'code': 'en', 'name': "🇬🇧 English"},
    {'code': 'de', 'name': "🇩🇪 Deutsch(German language)"},
    {'code': 'fr', 'name': "🇫🇷 Français"},
    {'code': 'tr', 'name': "🇹🇷 Türkçe"},
  ];
  
  bool _withImages = true;
  double _slideCount = 8;
  String _templateCategory = 'Popular';
  String _selectedTemplate = 'slice';
  
  File? _sourceFile;
  String? _sourceFilePath;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _fullNameController.text = user.fullName;
    }
  }

  Future<void> _pickFile() async {
    if (kIsWeb) { // ADDED
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fayl yuklash vebda qo'llab-quvvatlanmaydi.")),
      );
      return;
    }
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      if (file.lengthSync() > 10 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fayl hajmi 10MB dan katta bo'lmasligi kerak.")),
        );
        return;
      }
      setState(() {
        _sourceFile = file;
        _isUploading = true;
        _uploadProgress = 0;
      });

      try {
        final response = await ApiService().uploadSource(file, onProgress: (progress) {
          setState(() => _uploadProgress = progress);
        });
        setState(() => _sourceFilePath = response['file_path']);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fayl yuklashda xatolik: ${e.toString()}')),
        );
        setState(() => _sourceFile = null);
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  void _handleCreate() {
    if (!_formKey.currentState!.validate()) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Iltimos, barcha maydonlarni to'g'ri to'ldiring.")),
        );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user!;
    
    final requiredBalance = docType == 'Taqdimot'
        ? (_withImages ? user.pricePresentationWithImages : user.pricePresentation)
        : user.priceAbstract;

    if (user.balance < requiredBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Balans yetarli emas! Kerakli summa: $requiredBalance so\'m.')),
      );
      showDialog(
        context: context,
        builder: (_) => PaymentModal(
          onClose: () => Navigator.pop(context),
          requiredAmount: requiredBalance,
          currentBalance: user.balance,
        ),
      );
      return;
    }

    // ADDED DEBUG PRINTS HERE
    print('DEBUG: fullName: ${_fullNameController.text}, type: ${_fullNameController.text.runtimeType}');
    print('DEBUG: topic: ${_topicController.text}, type: ${_topicController.text.runtimeType}');
    print('DEBUG: docType: $docType, type: ${docType.runtimeType}');
    print('DEBUG: withImages: $_withImages, type: ${_withImages.runtimeType}');
    print('DEBUG: slideCount: ${_slideCount.toInt()}, type: ${(_slideCount.toInt()).runtimeType}');
    print('DEBUG: selectedTemplate: $_selectedTemplate, type: ${_selectedTemplate.runtimeType}');
    print('DEBUG: templateCategory: $_templateCategory, type: ${_templateCategory.runtimeType}');
    print('DEBUG: university: ${_universityController.text}, type: ${_universityController.text.runtimeType}');
    print('DEBUG: faculty: ${_facultyController.text}, type: ${_facultyController.text.runtimeType}');
    print('DEBUG: direction: ${_directionController.text}, type: ${_directionController.text.runtimeType}');
    print('DEBUG: group: ${_groupController.text}, type: ${_groupController.text.runtimeType}');
    print('DEBUG: sourceFilePath: $_sourceFilePath, type: ${_sourceFilePath.runtimeType}');


    final settings = {
      'fullName': _fullNameController.text,
      'topic': _topicController.text,
      'docType': docType,
      'docLang': _selectedLang,
      'withImages': docType == 'Taqdimot' ? _withImages : false,
      'slideCount': docType == 'Taqdimot' ? _slideCount.toInt() : 20,
      'selectedTemplate': _selectedTemplate,
      'templateCategory': _templateCategory,
      'university': _universityController.text,
      'faculty': _facultyController.text,
      'direction': _directionController.text,
      'group': _groupController.text,
      'sourceFilePath': _sourceFilePath,
    };
    
    print('DEBUG: settings map: $settings, type: ${settings.runtimeType}'); // ADDED
    
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditorScreen(settings: settings)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Yangi Hujjat Yaratish"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const AuroraBackground(),
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSectionCard(
                  context,
                  title: 'Hujjat Turi',
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Taqdimot', label: Text('Taqdimot')),
                      ButtonSegment(value: 'Referat', label: Text('Referat')),
                    ],
                    selected: {docType},
                    onSelectionChanged: (newSelection) {
                      setState(() => docType = newSelection.first);
                    },
                  ),
                ),
                _buildSectionCard(
                  context,
                  title: "Asosiy Ma'lumotlar",
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(labelText: "To'liq ism-familiya"),
                        validator: (v) => v!.trim().isEmpty ? "Ism-familiya kiritilishi shart" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _topicController,
                        decoration: const InputDecoration(labelText: "Mavzu"),
                        validator: (v) => v!.trim().isEmpty ? "Mavzu kiritilishi shart" : null,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                    ],
                  ),
                ),
                _buildSectionCard(
                  context,
                  title: "Tilni tanlang",
                  child: DropdownButtonFormField<String>(
                    value: _selectedLang,
                    decoration: const InputDecoration(
                      labelText: 'Hujjat tili',
                    ),
                    items: _languages.map((lang) {
                      return DropdownMenuItem<String>(
                        value: lang['code'],
                        child: Text(lang['name']!),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedLang = newValue!;
                      });
                    },
                  ),
                ),
                _buildSectionCard(
                  context,
                  title: "Manba Fayl (Ixtiyoriy)",
                  child: _sourceFile == null
                      ? DottedBorder(
                          color: theme.textTheme.bodyMedium!.color!.withOpacity(0.5),
                          strokeWidth: 1,
                          dashPattern: const [6, 6],
                          borderType: BorderType.RRect,
                          radius: const Radius.circular(12),
                          child: InkWell(
                            onTap: _pickFile,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                children: [
                                  Icon(LucideIcons.upload, size: 32, color: theme.textTheme.bodyMedium!.color!.withOpacity(0.6)),
                                  const SizedBox(height: 8),
                                  const Text("PDF fayl yuklash"),
                                  Text("Fayl hajmi 10MB gacha", style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            ListTile(
                              leading: Icon(LucideIcons.file, color: theme.colorScheme.primary),
                              title: Text(_sourceFile!.path.split('/').last, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${(_sourceFile!.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB'),
                              trailing: IconButton(
                                icon: const Icon(LucideIcons.trash2, color: Colors.red),
                                onPressed: () => setState(() {
                                  _sourceFile = null;
                                  _sourceFilePath = null;
                                }),
                              ),
                            ),
                            if (_isUploading)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: LinearProgressIndicator(value: _uploadProgress, backgroundColor: theme.colorScheme.tertiary),
                              ),
                          ],
                        ),
                ),
                if (docType == 'Taqdimot') ...[
                  _buildSectionCard(
                    context,
                    title: "Ta'lim muassasasi (Ixtiyoriy)",
                    child: Column(
                      children: [
                        TextFormField(controller: _universityController, decoration: const InputDecoration(labelText: 'Universitet nomi')),
                        const SizedBox(height: 12),
                        TextFormField(controller: _facultyController, decoration: const InputDecoration(labelText: 'Fakulteti')),
                        const SizedBox(height: 12),
                        TextFormField(controller: _directionController, decoration: const InputDecoration(labelText: 'Yo\'nalishi')),
                        const SizedBox(height: 12),
                        TextFormField(controller: _groupController, decoration: const InputDecoration(labelText: 'Guruhi')) ,
                      ],
                    ),
                  ),
                  _buildSectionCard(
                    context,
                    title: '',
                    child: SwitchListTile(
                      title: const Text("Rasmli / Rasmsiz"),
                      value: _withImages,
                      onChanged: (val) => setState(() => _withImages = val),
                      secondary: Icon(_withImages ? LucideIcons.image : LucideIcons.imageOff),
                    ),
                  ),
                  _buildSectionCard(
                    context,
                    title: 'Slaydlar Soni (${_slideCount.toInt()})',
                    child: Slider(
                      value: _slideCount,
                      min: 6,
                      max: 20,
                      divisions: 14,
                      label: _slideCount.round().toString(),
                      onChanged: (double value) {
                        setState(() => _slideCount = value);
                      },
                    ),
                  ),
                  _buildSectionCard(
                    context,
                    title: 'Shablon Kategoriyasi',
                    child: DropdownButtonFormField<String>(
                      value: _templateCategory,
                      items: templateData.keys.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _templateCategory = newValue!;
                          _selectedTemplate = templateData[_templateCategory]![0];
                        });
                      },
                    ),
                  ),
                  _buildSectionCard(
                    context,
                    title: 'Shablonni tanlang',
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage('$baseTemplateUrl${_templateCategory.toLowerCase()}/$_selectedTemplate.png'),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: templateData[_templateCategory]!.length,
                            itemBuilder: (context, index) {
                              final templateName = templateData[_templateCategory]![index];
                              final isSelected = templateName == _selectedTemplate;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedTemplate = templateName),
                                child: Container(
                                  width: 120,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected ? Border.all(color: theme.primaryColor, width: 3) : null,
                                    image: DecorationImage(
                                      image: NetworkImage('$baseTemplateUrl${_templateCategory.toLowerCase()}/$templateName.png'),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _handleCreate,
                  icon: const Icon(LucideIcons.chevronsRight),
                  label: const Text('Tayyorlash'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty) ...[
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// --- EditorScreen ---
class EditorScreen extends StatefulWidget {
  final Map<String, dynamic> settings;
  const EditorScreen({super.key, required this.settings});

  @override
  _EditorScreenState createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _editableSlides = [];
  Map<String, dynamic>? _generatedContentData;
  final Map<String, bool> _regenerating = {}; // key: "type-slideIdx-itemIdx"

  @override
  void initState() {
    super.initState();
    _generateInitialContent();
  }

  Future<void> _generateInitialContent() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final requestData = {
        'token': auth.token,
        'topic': widget.settings['topic'],
        'lang': widget.settings['docLang'] ?? auth.user?.lang ?? 'uz',
        'slides_count': widget.settings['slideCount'],
        'with_image': widget.settings['withImages'],
        'sources': widget.settings['sourceFilePath'] != null ? [widget.settings['sourceFilePath']] : []
      };
      final response = await ApiService().generateContent(requestData);
      _generatedContentData = response;
      
      final slidesForEditing = List<Map<String, dynamic>>.from(response['slides']);
      
      final finalSlides = [
        { 'type': 'title', 'content': { 'title': widget.settings['topic'], 'author': widget.settings['fullName'], 'institution': [widget.settings['university'], widget.settings['faculty'], widget.settings['direction'], widget.settings['group']].where((s) => s.isNotEmpty).join(', ') } },
        { 'type': 'plan', 'content': { 'title': 'Reja:', 'items': List<String>.from(response['plans']) } },
        ...slidesForEditing.map((s) => ({'type': 'content', 'content': s})),
      ];

      setState(() {
        _editableSlides = finalSlides;
        _isLoading = false;
      });

    } catch (e) {
      print("Content generation failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kontent yaratishda xatolik: ${e.toString()}')));
      Navigator.of(context).pop();
    }
  }
  
  void _updateText(int slideIndex, String field, String value) {
    setState(() {
      _editableSlides[slideIndex]['content'][field] = value;
    });
  }
  
  void _updatePlanItem(int slideIndex, int itemIndex, String value) {
    setState(() {
      (_editableSlides[slideIndex]['content']['items'] as List)[itemIndex] = value;
    });
  }

  void _updateSlideContentItem(int slideIndex, int itemIndex, String value) {
     setState(() {
      (_editableSlides[slideIndex]['content']['content'] as List)[itemIndex] = value;
    });
  }

  void _updateSlideImage(int slideIndex, String newImageUrl) {
     setState(() {
      _editableSlides[slideIndex]['content']['image_url'] = newImageUrl;
    });
  }
  
  Future<void> _regenerateText(int slideIndex, int contentIndex) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    // Client-side check for 2% of initial price
    int initialPrice = 0;
    if (widget.settings['docType'] == 'Taqdimot') {
      initialPrice = widget.settings['withImages']
        ? user.pricePresentationWithImages
        : user.pricePresentation;
    } else {
      initialPrice = user.priceAbstract;
    }
    final regenerationCost = initialPrice * 0.02;

    if (user.balance < regenerationCost) {
      final shortfall = regenerationCost - user.balance;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mablag\' yetarli emas. Amal narxi: ${regenerationCost.ceil()} so\'m. Yana ${shortfall.ceil()} so\'m kerak.')),
      );
      showDialog(
        context: context,
        builder: (_) => PaymentModal(
          onClose: () => Navigator.pop(context),
          requiredAmount: regenerationCost.ceil(),
          currentBalance: user.balance,
        ),
      );
      return; // Stop before making the API call
    }

    final key = "text-$slideIndex-$contentIndex";
    setState(() => _regenerating[key] = true);
    try {
      final response = await ApiService().regenerateSlideContent({
          'token': auth.token,
          'main_topic': widget.settings['topic'],
          'slide_topic': _editableSlides[slideIndex]['content']['title'],
          'lang': widget.settings['docLang'] ?? auth.user?.lang ?? 'uz',
          'sources': widget.settings['sourceFilePath'] != null ? [widget.settings['sourceFilePath']] : []
      });
      _updateSlideContentItem(slideIndex, contentIndex, response['new_content']);
      auth.refreshUser(); // Refresh user to update balance
    } on PaymentRequiredException catch (e) {
      // This now acts as a server-side fallback
      final shortfall = e.requiredAmount - user.balance;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mablag\' yetarli emas. Amal narxi: ${e.requiredAmount}, sizda ${user.balance}. Yana $shortfall so\'m kerak.')),
      );
      showDialog(
        context: context,
        builder: (_) => PaymentModal(
          onClose: () => Navigator.pop(context),
          requiredAmount: e.requiredAmount,
          currentBalance: user.balance,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Qayta yaratishda xatolik: ${e.toString()}')));
    } finally {
      setState(() => _regenerating.remove(key));
    }
  }

  Future<void> _regenerateImage(int slideIndex) async {
    final key = "image-$slideIndex";
    setState(() => _regenerating[key] = true);
    try {
      final response = await ApiService().getImageUrl(widget.settings['topic']);
      if (response['image_url'] != null) {
        _updateSlideImage(slideIndex, response['image_url']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rasm yangilashda xatolik: ${e.toString()}')));
    } finally {
      setState(() => _regenerating.remove(key));
    }
  }

  Future<void> _uploadLocalImage(int slideIndex) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rasm yuklash vebda qo'llab-quvvatlanmaydi.")),
      );
      return;
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final key = "image-$slideIndex";
    setState(() {
      _regenerating[key] = true;
      _editableSlides[slideIndex]['content']['local_image_path'] = pickedFile.path; // Store local path
    });

    try {
      final response = await ApiService().uploadImage(File(pickedFile.path));
      _updateSlideImage(slideIndex, response['image_url']); // Update network URL
      // No need to clear local_image_path immediately, it can stay for display
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rasm yuklashda xatolik: ${e.toString()}')));
      setState(() {
        _editableSlides[slideIndex]['content'].remove('local_image_path'); // Clear on error
      });
    } finally {
      setState(() => _regenerating.remove(key));
    }
  }

  Future<void> _doSave() async {
    setState(() => _isSaving = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final planSlide = _editableSlides.firstWhere((s) => s['type'] == 'plan', orElse: () => <String, Object>{'content': {'items': []}});
      final editedContentSlides = _editableSlides.where((s) => s['type'] == 'content').map((s) => s['content']).toList();

      final titleSlideContent = _editableSlides[0]['content']; // Get edited title slide content

        print('DEBUG: _generatedContentData type: ${_generatedContentData.runtimeType}'); // ADDED FOR DEBUG
        print('DEBUG: _generatedContentData: $_generatedContentData'); // ADDED FOR DEBUG

        final finalContentData = {
          ..._generatedContentData!,
          'slides': editedContentSlides,
          'plans': planSlide['content']['items']
        };

        print('DEBUG: finalContentData type: ${finalContentData.runtimeType}'); // ADDED FOR DEBUG
        print('DEBUG: finalContentData: $finalContentData'); // ADDED FOR DEBUG

        final requestData = {
          'token': auth.token,
          'generated_content_data': finalContentData,
          'full_name': titleSlideContent['author'], // Use edited author
          'topic': titleSlideContent['title'],     // Use edited title
          'doc_lang': widget.settings['docLang'] ?? auth.user?.lang ?? 'uz',
          'institution_info': {
              'university': widget.settings['university'], // Keep original institution info
              'faculty': widget.settings['faculty'],
              'direction': widget.settings['direction'],
              'group': widget.settings['group']
          },
          'template_name': widget.settings['docType'] == 'Taqdimot' ? '${widget.settings['templateCategory'].toLowerCase()}/${widget.settings['selectedTemplate']}' : 'template',
          'file_type': widget.settings['docType'] == 'Taqdimot' ? 'pptx' : 'docx',
          'sources': widget.settings['sourceFilePath'] != null ? [widget.settings['sourceFilePath']] : []
        };

        print('DEBUG: requestData type: ${requestData.runtimeType}'); // ADDED FOR DEBUG
        print('DEBUG: requestData: $requestData'); // ADDED FOR DEBUG

      final response = await ApiService().createFile(requestData);
      print('Type of response from createFile: ${response.runtimeType}'); // ADDED FOR DEBUG
      print('Response from createFile: $response'); // ADDED FOR DEBUG
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => GenerationStatusScreen(
          taskInfo: {
            'taskId': response['task_id'],
            'docTitle': widget.settings['topic'],
            'docType': widget.settings['docType']
          }
        )),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Faylni saqlashda xatolik: ${e.toString()}")));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text('${widget.settings['docType']} yaratilmoqda, iltimos kuting...'),
              const SizedBox(height: 8),
              Text("Bu jarayon bir daqiqagacha vaqt olishi mumkin.", style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Muharrir")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _editableSlides.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildSlide(index),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _doSave,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          child: _isSaving
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
              : Text('${widget.settings['docType']}ni Saqlash'),
        ),
      ),
    );
  }

  Widget _buildSlide(int index) {
    final slide = _editableSlides[index];
    final content = slide['content'];
    switch (slide['type']) {
      case 'title':
        return Column(
          children: [
            EditableTextBlock(initialValue: content['institution'], onUpdate: (val) => _updateText(index, 'institution', val), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            EditableTextBlock(initialValue: content['title'], onUpdate: (val) => _updateText(index, 'title', val), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            EditableTextBlock(initialValue: content['author'], onUpdate: (val) => _updateText(index, 'author', val), style: Theme.of(context).textTheme.titleLarge),
          ],
        );
      case 'plan':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditableTextBlock(initialValue: content['title'], onUpdate: (val) => _updateText(index, 'title', val), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            for (int i = 0; i < (content['items'] as List).length; i++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("• "),
                  Expanded(child: EditableTextBlock(initialValue: content['items'][i], onUpdate: (val) => _updatePlanItem(index, i, val))),
                ],
              )
          ],
        );
      case 'content':
        final keyBase = "content-$index";
        return Column(
          children: [
            EditableTextBlock(initialValue: content['title'], onUpdate: (val) => _updateText(index, 'title', val), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            if (content['image_url'] != null || content['local_image_path'] != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  GestureDetector(
                    onTap: () => _uploadLocalImage(index),
                    child: content['local_image_path'] != null
                        ? Image.file(File(content['local_image_path']), fit: BoxFit.cover, height: 150, width: double.infinity)
                        : Image.network(content['image_url'], fit: BoxFit.cover, height: 150, width: double.infinity),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       _buildRegenerateButton(
                        key: "image-$index",
                        onPressed: () => _regenerateImage(index),
                      ),
                       _buildRegenerateButton(
                        icon: LucideIcons.upload,
                        key: "upload-$index",
                        onPressed: () => _uploadLocalImage(index),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 12),
            for (int i = 0; i < (content['content'] as List).length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: EditableTextBlock(initialValue: content['content'][i], onUpdate: (val) => _updateSlideContentItem(index, i, val), minLines: 3)),
                    _buildRegenerateButton(
                      key: "text-$index-$i",
                      onPressed: () => _regenerateText(index, i),
                    ),
                  ],
                ),
              ),
          ],
        );
      case 'final':
        return EditableTextBlock(initialValue: content['text'], onUpdate: (val) => _updateText(index, 'text', val), style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center,);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRegenerateButton({required String key, required VoidCallback onPressed, IconData icon = LucideIcons.refreshCw}) {
    final isRegen = _regenerating[key] ?? false;
    return IconButton(
      icon: isRegen ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, size: 18),
      onPressed: isRegen ? null : onPressed,
    );
  }
}

// --- GenerationStatusScreen ---
class GenerationStatusScreen extends StatefulWidget {
  final Map<String, dynamic> taskInfo;
  const GenerationStatusScreen({super.key, required this.taskInfo});

  @override
  _GenerationStatusScreenState createState() => _GenerationStatusScreenState();
}

class _GenerationStatusScreenState extends State<GenerationStatusScreen> {
  String _status = 'pending';
  String? _error;
  String _statusMessage = '';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _statusMessage = "So'rov yuborildi, ${widget.taskInfo['docType']} yaratish boshlanmoqda...";
    _startPolling();
  }

  void _startPolling() {
    final taskId = widget.taskInfo['taskId'];
    if (taskId == null) {
      setState(() => _error = "Fayl yaratish uchun kerakli ma'lumot (task_id) topilmadi.");
      return;
    }

    _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      try {
        final statusResponse = await ApiService().getFileStatus(taskId);
        setState(() => _status = statusResponse['status']);

        if (_status == 'completed') {
          timer.cancel();
          setState(() => _statusMessage = 'Fayl muvaffaqiyatli yaratildi!');
          
          final downloadUrl = '$apiBaseUrl/download_file/${statusResponse['file_path']}';
          final fileName = statusResponse['file_path'].split('/').last;
          final fileExtension = fileName.split('.').last.toLowerCase();
          final mimeType = _getMimeType(fileExtension);

          final directory = await getApplicationDocumentsDirectory();
          final localPath = '${directory.path}/$fileName';

          // Faylni yuklab olish
          final response = await http.get(Uri.parse(downloadUrl));
          if (response.statusCode == 200) {
            final file = File(localPath);
            await file.writeAsBytes(response.bodyBytes);
            print('Fayl lokalga saqlandi: $localPath');

            final newDoc = Document(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: widget.taskInfo['docTitle'],
              date: DateTime.now().toIso8601String().split('T')[0],
              localPath: localPath,
              mimeType: mimeType,
            );

            Provider.of<AuthProvider>(context, listen: false).addDocument(newDoc);
            Provider.of<AuthProvider>(context, listen: false).refreshUser(); // Balansni yangilash

            // Orqaga qaytishdan oldin biroz kutish
            Future.delayed(const Duration(seconds: 2), () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            });
          } else {
            setState(() => _error = "Faylni yuklab olishda xatolik yuz berdi.");
          }

        } else if (_status == 'failed') {
          timer.cancel();
          setState(() => _error = "Fayl yaratishda xatolik yuz berdi. Iltimos, qayta urinib ko'ring.");
        } else {
          setState(() => _statusMessage = 'Generatsiya qilinmoqda, iltimos kuting...');
        }
      } catch (e) {
        timer.cancel();
        setState(() => _error = 'Fayl holatini tekshirishda xatolik: ${e.toString()}');
      }
    });
  }
  
  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.x, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text("Xatolik", style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("Orqaga"),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_status != 'completed') const CircularProgressIndicator(),
                        if (_status == 'completed') const Icon(LucideIcons.check, size: 48, color: Colors.green),
                        const SizedBox(height: 16),
                        Text(_status == 'completed' ? "Tayyor!" : "Jarayonda...", style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(_statusMessage, textAlign: TextAlign.center),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
  String _getMimeType(String fileExtension) {
    switch (fileExtension) {
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }
}

// --- ProfileScreen ---
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _avatarFile;
  late TextEditingController _nameController;
  bool _isEditingName = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: Provider.of<AuthProvider>(context, listen: false).user?.fullName ?? '');
    _loadAvatar();
    // Refresh user data when entering the profile screen
    Provider.of<AuthProvider>(context, listen: false).refreshUser();
  }

  Future<void> _loadAvatar() async { // ADDED
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('avatar_path');
    if (savedPath != null) {
      setState(() {
        _avatarFile = File(savedPath);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
        // Bu yerda rasmni serverga yuklash logikasi bo'lishi mumkin
      });
      // Rasmni saqlash
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatar_path', pickedFile.path);
    }
  }

  Future<void> _toggleEditName() async {
    if (_isEditingName) {
      // Save name
      if (_nameController.text.trim().isNotEmpty && _nameController.text != Provider.of<AuthProvider>(context, listen: false).user?.fullName) {
        try {
          await Provider.of<AuthProvider>(context, listen: false).updateUserName(_nameController.text);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ism muvaffaqiyatli yangilandi!")));
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ismni yangilashda xatolik: ${e.toString()}")));
        }
      }
    }
    setState(() {
      _isEditingName = !_isEditingName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final theme = Theme.of(context);

    if (user == null) {
      return const Center(child: Text("Foydalanuvchi topilmadi"));
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Column(
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: _avatarFile != null 
                    ? FileImage(_avatarFile!)
                    : const AssetImage('assets/avatar.jpg'),
                  child: const Align(
                    alignment: Alignment.bottomRight,
                    child: CircleAvatar(
                      radius: 15,
                      child: Icon(LucideIcons.pencil, size: 15),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 48), // Balancing space for the IconButton
                  Flexible(
                    child: TextFormField(
                      controller: _nameController,
                      readOnly: !_isEditingName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                      decoration: InputDecoration(
                        border: InputBorder.none, // Always no border
                        focusedBorder: InputBorder.none, // Remove focused border
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Consistent padding
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isEditingName ? LucideIcons.save : LucideIcons.pencil),
                    onPressed: _toggleEditName,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("ID: ${user.chatId}", style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7))),
                  IconButton(
                    icon: Icon(LucideIcons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: user.chatId.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('ID nusxalandi: ${user.chatId}')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionCard(
            context,
            child: SwitchListTile(
              title: const Text("Tungi Rejim"),
              secondary: Icon(authProvider.isDarkMode ? LucideIcons.moon : LucideIcons.sun),
              value: authProvider.isDarkMode,
              onChanged: (val) => authProvider.toggleTheme(),
            ),
          ),
          _buildSectionCard(
            context,
            child: Column(
              children: [
                ListTile(
                  title: const Text("Balans"),
                  trailing: Text("${user.balance} so'm", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => showDialog(context: context, builder: (_) => PaymentModal(onClose: () => Navigator.pop(context))),
                    child: const Text("Hisobni to'ldirish"),
                  ),
                ),
              ],
            ),
          ),
          _buildSectionCard(
            context,
            child: Column(
              children: [
                ListTile(
                  title: const Text("Qo'llab-quvvatlash"),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text("FAQ"),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FaqScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => authProvider.logout(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                backgroundColor: theme.colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text("Chiqish"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassCard(child: child),
    );
  }
}

// --- SupportScreen ---
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Qo'llab-quvvatlash")),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildInfoCard(
            context,
            title: "Biz bilan aloqa",
            content: "Ilova bo'yicha savollar, takliflar yoki muammolar yuzasidan biz bilan bog'lanishingiz mumkin. Biz sizga yordam berishdan doim mamnunmiz.",
          ),
          _buildLinkCard(
            context,
            title: "Rasmiy yangiliklar kanali",
            content: "Barcha yangiliklar, yangilanishlar va maxsus takliflardan xabardor bo'lish uchun kanalimizga obuna bo'ling.",
            linkText: "Taqdimot Robot | News",
            url: "https://t.me/taqdimotnews",
          ),
          _buildLinkCard(
            context,
            title: "Admin & Dasturchi",
            content: "Texnik nosozliklar yoki hamkorlik bo'yicha to'g'ridan-to'g'ri murojaat uchun.",
            linkText: " @webtechgo",
            url: "https://t.me/webtechgo",
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {required String title, required String content}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 8),
              Text(content),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLinkCard(BuildContext context, {required String title, required String content, required String linkText, required String url}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(content, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8))),
              const SizedBox(height: 12),
              ListTile(
                title: Text(linkText),
                trailing: Icon(LucideIcons.chevronRight, color: theme.colorScheme.primary),
                onTap: () async {
                  print('DEBUG: Link card tapped: $url');
                  final uri = Uri.parse(url);
                  print('DEBUG: Attempting to launch URL: $uri');
                  try {
                    if (await canLaunchUrl(uri)) {
                      print('DEBUG: canLaunchUrl returned true. Launching...');
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                      print('DEBUG: URL launched successfully.');
                    } else {
                      print('DEBUG: canLaunchUrl returned false for $uri. Cannot launch URL.');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Havolani ochib bo'lmadi. Iltimos, Telegram ilovasi o'rnatilganligiga ishonch hosil qiling.")),
                      );
                    }
                  } catch (e) {
                    print('DEBUG: Error launching URL: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Havolani ochishda xatolik yuz berdi: $e")),
                    );
                  }
                },
                tileColor: theme.colorScheme.tertiary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- FaqScreen ---
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final List<Map<String, String>> faqData = [
    { "q": "Ilovadan qanday foydalanish mumkin?", "a": "Ilovadan foydalanish juda oson: '+' tugmasini bosing, kerakli hujjat turini tanlang, ma'lumotlarni kiriting va 'Tayyorlash' tugmasini bosing. AI qolganini o'zi bajaradi!" },
    { "q": "Taqdimot yaratish qancha vaqt oladi?", "a": "Odatda, taqdimotni generatsiya qilish 30 soniyadan 1 daqiqagacha vaqt oladi. Bu slaydlardagi ma'lumotlar hajmiga va rasmlar mavjudligiga bog'liq." },
    { "q": "Generatsiya qilingan matnlarni o'zgartirsam bo'ladimi?", "a": "Albatta! 'Muharrir' ekranida har bir matn bloki to'liq tahrirlanadigan. Siz AI taklif qilgan matnni o'zgartirishingiz, to'ldirishingiz yoki butunlay o'chirib, o'zingiznikini yozishingiz mumkin." },
    { "q": "Balansni qanday to'ldirish mumkin?", "a": "'Profil' ekranidagi 'Balans' bo'limida 'Hisobni to'ldirish' tugmasini bosing. U yerda siz uchun qulay bo'lgan to'lov tizimlaridan birini tanlashingiz mumkin." },
    { "q": "Texnik muammo yuzaga kelsa nima qilishim kerak?", "a": "Agar texnik muammoga duch kelsangiz, 'Qo'llab-quvvatlash' sahifasidagi Admin bilan bog'lanish havolasi orqali bizga murojaat qiling. Muammoni iloji boricha tezroq hal qilishga harakat qilamiz." },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ko'p Beriladigan Savollar")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: faqData.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: GlassCard(
              child: ExpansionTile(
                title: Text(faqData[index]['q']!),
                trailing: const Icon(LucideIcons.chevronDown),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(faqData[index]['a']!),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------------------------- 
// --- YORDAMCHI VIDJETLAR (Widgets) ---
// ----------------------------------------------------------------------------- 

// --- FullScreenLoader ---
class FullScreenLoader extends StatelessWidget {
  const FullScreenLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

// --- AuroraBackground ---
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  _AuroraBackgroundState createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<Offset>> _animations;
  final List<Color> _colors = [
    Colors.purple.withOpacity(0.3),
    Colors.blue.withOpacity(0.3),
    Colors.cyan.withOpacity(0.3),
    Colors.pink.withOpacity(0.3),
  ];
  final List<Alignment> _initialAlignments = [
    const Alignment(-1.5, -1.5),
    const Alignment(1.5, -1.0),
    const Alignment(-1.0, 1.5),
    const Alignment(1.5, 1.5),
  ];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (index) {
      return AnimationController(
        // TUZATISH: Animatsiya davomiyligi sezilarli darajada oshirildi (40-60 soniya).
        // Bu harakatni juda sekin va silliq qiladi.
        duration: Duration(seconds: 150 + Random().nextInt(50)),
        vsync: this,
      );
    });

    _animations = List.generate(4, (index) {
      return Tween<Offset>(
        begin: Offset.zero,
        end: Offset(Random().nextDouble() * 0.5 - 0.25, Random().nextDouble() * 0.5 - 0.25),
      ).animate(CurvedAnimation(parent: _controllers[index], curve: Curves.easeInOut));
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TUZATISH: Barcha elementlarga bir xil va kuchli blur effektini kafolatli
    // qo'llash uchun `ImageFiltered` vidjeti ishlatildi.
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 100.0, sigmaY: 100.0),
      child: Stack(
        children: List.generate(4, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Align(
                alignment: Alignment(_initialAlignments[index].x + _animations[index].value.dx, _initialAlignments[index].y + _animations[index].value.dy),
                child: Container(
                  width: MediaQuery.of(context).size.width * (0.6 + Random().nextDouble() * 0.4),
                  height: MediaQuery.of(context).size.width * (0.6 + Random().nextDouble() * 0.4),
                  decoration: BoxDecoration(
                    color: _colors[index],
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// --- GlassCard ---
class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: theme.colorScheme.tertiary.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// --- EditableTextBlock ---
class EditableTextBlock extends StatefulWidget {
  final String initialValue;
  final Function(String) onUpdate;
  final TextStyle? style;
  final TextAlign textAlign;
  final int minLines;

  const EditableTextBlock({
    super.key,
    required this.initialValue,
    required this.onUpdate,
    this.style,
    this.textAlign = TextAlign.start,
    this.minLines = 1,
  });

  @override
  _EditableTextBlockState createState() => _EditableTextBlockState();
}

class _EditableTextBlockState extends State<EditableTextBlock> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant EditableTextBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      onChanged: widget.onUpdate,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: null, // Allows for multiline
      minLines: widget.minLines,
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

// --- PaymentModal ---
class PaymentModal extends StatefulWidget {
  final VoidCallback onClose;
  final int? requiredAmount;
  final int? currentBalance;
  const PaymentModal({super.key, required this.onClose, this.requiredAmount, this.currentBalance});

  @override
  _PaymentModalState createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  String _paymentStep = 'initial'; // initial, link_generated, pending, success, error
  String _amount = '';
  String _provider = 'click';
  String? _checkoutUrl;
  String? _payId;
  String _paymentError = '';
  Timer? _timer;

  final Map<String, String> providerLogos = {
    'click': 'assets/logos/click.png',
    'payme': 'assets/logos/payme.png',
    'uzum': 'assets/logos/uzum.png',
  };

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _createPaymentLink() async {
    final amountInt = int.tryParse(_amount);
    if (amountInt == null || amountInt < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Minimal summa 1000 so'm.")));
      return;
    }
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final response = await ApiService().createPaymentLink({
        'token': auth.token,
        'amount': amountInt,
        'paysystem': _provider,
      });
      setState(() {
        _checkoutUrl = response['checkoutUrl'];
        _payId = response['payId'];
        _paymentStep = 'link_generated';
      });
    } catch (e) {
      setState(() {
        _paymentError = e.toString();
        _paymentStep = 'error';
      });
    }
  }

  void _openCheckoutUrl() async {
    if (_checkoutUrl != null) {
      await launchUrl(Uri.parse(_checkoutUrl!), mode: LaunchMode.externalApplication);
      setState(() => _paymentStep = 'pending');
      _startPolling();
    }
  }

  void _startPolling() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final statusResponse = await ApiService().checkPaymentStatus(_payId!, auth.token!);
        if (statusResponse['status'] == 'succeed') {
          timer.cancel();
          await auth.refreshUser();
          setState(() => _paymentStep = 'success');
        } else if (statusResponse['status'] == 'failed') {
          timer.cancel();
          setState(() {
            _paymentError = statusResponse['message'] ?? "To'lov bekor qilindi.";
            _paymentStep = 'error';
          });
        }
      } catch (e) {
        print("Payment status check failed: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Stack( // <-- Yangi Stack
            clipBehavior: Clip.none, // Bu tugma biroz tashqariga chiqsa ham ko'rinishiga imkon beradi
            children: [
              // Asosiy kontent (Column, TextField'lar va h.k.)
              _buildContent(),

              // Burchakdagi yopish tugmasi
              Positioned(
                top: -12, // Qiymatlarni o'zgartirib, ideal holatga keltiring
                right: -12,
                child: IconButton(
                  icon: const Icon(LucideIcons.x), // Changed from xCircle to x
                  onPressed: widget.onClose,
                  style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final theme = Theme.of(context);
    switch (_paymentStep) {
      case 'initial':
        final missingAmount = (widget.requiredAmount ?? 0) - (widget.currentBalance ?? 0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.requiredAmount != null && widget.currentBalance != null)
              Text(
                "Hujjat yaratish uchun ${widget.requiredAmount} so'm kerak. Sizda ${widget.currentBalance} so'm bor. ${missingAmount > 0 ? '$missingAmount so\'m yetmayapti.' : ''}",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            const SizedBox(height: 16),
            Text("Hisobni to'ldirish", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              onChanged: (val) => _amount = val,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Summa, so'm"),
            ),
            const SizedBox(height: 16),
            Text("To'lov tizimini tanlang", style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildProviderButton('click', providerLogos['click']!),
                _buildProviderButton('payme', providerLogos['payme']!),
                _buildProviderButton('uzum', providerLogos['uzum']!),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _createPaymentLink, child: const Text("To'ldirish")),
          ],
        );
      case 'link_generated':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Havola tayyor", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            const Text("To'lovni amalga oshirish uchun quyidagi tugmani bosing.", textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _openCheckoutUrl, child: const Text("To'lov qilish")),
          ],
        );
      case 'pending':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text("To'lov kutilmoqda...", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text("To'lovni amalga oshirmaguningizcha oynani yopmang.", textAlign: TextAlign.center),
          ],
        );
      case 'success':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.check, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            Text("To'lov qabul qilindi!", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: widget.onClose, child: const Text("Yopish")),
          ],
        );
      case 'error':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.x, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text("Xatolik", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_paymentError, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => setState(() => _paymentStep = 'initial'), child: const Text("Qayta urinish")),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProviderButton(String id, String logoPath) { // Changed iconUrl to logoPath
    final isSelected = _provider == id;
    return GestureDetector(
      onTap: () => setState(() => _provider = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? Theme.of(context).primaryColor : Colors.grey, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.asset(logoPath, width: 60, height: 30, fit: BoxFit.contain), // Changed Image.network to Image.asset
      ),
    );
  }
}



