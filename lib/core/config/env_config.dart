import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get googleWebClientId => 
    dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
    
  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
  }
}
