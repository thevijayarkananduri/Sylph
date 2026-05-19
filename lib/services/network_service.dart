import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

Future<Map<String, dynamic>> fetchWeather(String city, String owmKey) async {
  final url = Uri.parse(
    'https://api.openweathermap.org/data/2.5/weather?q=${Uri.encodeComponent(city)}&appid=$owmKey&units=metric',
  );

  try {
    final res = await http.get(url).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('City "$city" not found. Check spelling and try again.');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  } on http.ClientException catch (e) {
    throw Exception('Network error: ${e.message}. Check your internet connection.');
  } on TimeoutException {
    throw Exception('Request timed out. Please try again.');
  } catch (e) {
    throw Exception('Error: ${e.toString()}');
  }
}

Future<Map<String, dynamic>?> fetchAQI(String city, String waqiKey) async {
  final url = Uri.parse(
    'https://api.waqi.info/feed/${Uri.encodeComponent(city)}/?token=$waqiKey',
  );

  try {
    final res = await http.get(url).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['status'] == 'ok' ? data['data'] as Map<String, dynamic> : null;
  } catch (e) {
    return null;
  }
}
