import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sylph/services/network_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0a0a0f),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SylphApp());
}

class SylphApp extends StatelessWidget {
  const SylphApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sylph — Weather & Air',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0a0a0f),
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'DMSans',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFc8f04e),
          secondary: Color(0xFF4ecbf0),
          surface: Color(0xFF111118),
          background: Color(0xFF0a0a0f),
          error: Color(0xFFf04e6a),
        ),
      ),
      home: const WeatherHomePage(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CONSTANTS & THEME
// ═══════════════════════════════════════════════════════════
class AppColors {
  static const bg = Color(0xFF0a0a0f);
  static const surface = Color(0xFF111118);
  static const border = Color.fromRGBO(255, 255, 255, 0.07);
  static const text = Color(0xFFf0ede8);
  static const muted = Color.fromRGBO(240, 237, 232, 0.68);
  static const accent = Color(0xFFc8f04e);
  static const accent2 = Color(0xFF4ecbf0);
  static const danger = Color(0xFFf04e6a);
  static const warn = Color(0xFFf0a84e);
  static const good = Color(0xFF4ef09a);
  static const cardTint = Color.fromRGBO(205, 185, 155, 0.13);
  static const cardBorder = Color.fromRGBO(205, 185, 145, 0.22);
}

class AppFonts {
  static TextStyle display({double size = 24, Color? color}) {
    return TextStyle(
      fontFamily: 'Boldonse',
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.text,
      letterSpacing: -0.02,
    );
  }

  static TextStyle body({double size = 16, FontWeight weight = FontWeight.w400, Color? color}) {
    return TextStyle(
      fontFamily: 'DMSans',
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.text,
    );
  }

  static TextStyle boldonse({double size = 24, Color? color}) {
    return TextStyle(
      fontFamily: 'Boldonse',
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.text,
      letterSpacing: 0.04,
    );
  }

  static TextStyle label({double size = 10, Color? color}) {
    return TextStyle(
      fontFamily: 'DMSans',
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color ?? AppColors.muted,
      letterSpacing: 0.25,
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  API KEYS (use --dart-define for secure builds)
// ═══════════════════════════════════════════════════════════
const String OWM_KEY = String.fromEnvironment('OWM_KEY', defaultValue: 'fa736ae62b05126fda481140ce2f39ef');
const String WAQI_KEY = String.fromEnvironment('WAQI_KEY', defaultValue: '8a0e521b8a539d30e682f61b71cf7413ad20d7ae');

// ═══════════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════════
class WeatherData {
  final String city;
  final String country;
  final double temp;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int visibility;
  final int pressure;
  final String description;
  final int weatherCode;
  final double lat;
  final double lon;
  final int timezone;
  final DateTime localTime;

  WeatherData({
    required this.city,
    required this.country,
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.visibility,
    required this.pressure,
    required this.description,
    required this.weatherCode,
    required this.lat,
    required this.lon,
    required this.timezone,
    required this.localTime,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final tz = json['timezone'] ?? 0;
    final utcMs = DateTime.now().millisecondsSinceEpoch + (DateTime.now().timeZoneOffset.inMilliseconds);
    final localMs = utcMs + (tz * 1000);

    return WeatherData(
      city: json['name'] ?? 'Unknown',
      country: json['sys']?['country'] ?? '',
      temp: (json['main']?['temp'] ?? 0).toDouble(),
      feelsLike: (json['main']?['feels_like'] ?? 0).toDouble(),
      humidity: json['main']?['humidity'] ?? 0,
      windSpeed: (json['wind']?['speed'] ?? 0).toDouble(),
      visibility: json['visibility'] ?? 10000,
      pressure: json['main']?['pressure'] ?? 0,
      description: json['weather']?[0]?['description'] ?? 'Unknown',
      weatherCode: json['weather']?[0]?['id'] ?? 800,
      lat: (json['coord']?['lat'] ?? 0).toDouble(),
      lon: (json['coord']?['lon'] ?? 0).toDouble(),
      timezone: tz,
      localTime: DateTime.fromMillisecondsSinceEpoch(localMs.toInt()),
    );
  }
}

class AQIData {
  final int aqi;
  final String? stationName;
  final Map<String, dynamic>? iaqi;

  AQIData({required this.aqi, this.stationName, this.iaqi});

  factory AQIData.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data == null) return AQIData(aqi: 0);

    return AQIData(
      aqi: data['aqi'] is int ? data['aqi'] : int.tryParse(data['aqi'].toString()) ?? 0,
      stationName: data['city']?['name'],
      iaqi: data['iaqi'],
    );
  }
}

class HistoryItem {
  final String city;
  final String country;
  final double tempC;
  final String description;
  final int? aqiNum;
  final DateTime timestamp;

  HistoryItem({
    required this.city,
    required this.country,
    required this.tempC,
    required this.description,
    this.aqiNum,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'city': city,
    'country': country,
    'tempC': tempC,
    'description': description,
    'aqiNum': aqiNum,
    'timestamp': timestamp.toIso8601String(),
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    city: json['city'],
    country: json['country'],
    tempC: (json['tempC'] ?? 0).toDouble(),
    description: json['description'],
    aqiNum: json['aqiNum'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

// ═══════════════════════════════════════════════════════════
//  MAIN PAGE STATE
// ═══════════════════════════════════════════════════════════
class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final TextEditingController _searchController = TextEditingController();
  WeatherData? _weatherData;
  AQIData? _aqiData;
  bool _isLoading = false;
  String? _errorMessage;
  List<HistoryItem> _history = [];
  bool _isCelsius = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('history') ?? [];
    setState(() {
      _history = historyJson.map((item) => HistoryItem.fromJson(jsonDecode(item))).toList();
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('history', _history.map((item) => jsonEncode(item.toJson())).toList());
  }

  Future<void> _fetchWeather(String city) async {
    if (city.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use the network_service with error handling
      final weatherJson = await fetchWeather(city, OWM_KEY);
      final weather = WeatherData.fromJson(weatherJson);

      // Fetch AQI (optional, doesn't fail the whole request)
      AQIData? aqi;
      try {
        final aqiJson = await fetchAQI(city, WAQI_KEY);
        if (aqiJson != null) {
          aqi = AQIData.fromJson(aqiJson);
        }
      } catch (e) {
        // AQI is optional, continue without it
      }

      setState(() {
        _weatherData = weather;
        _aqiData = aqi;
        _isLoading = false;

        // Add to history
        _history.insert(
          0,
          HistoryItem(
            city: weather.city,
            country: weather.country,
            tempC: weather.temp,
            description: weather.description,
            aqiNum: aqi?.aqi,
            timestamp: DateTime.now(),
          ),
        );
        _saveHistory();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  String _tempDisplay(double celsius) {
    if (_isCelsius) return celsius.toStringAsFixed(1);
    return ((celsius * 9 / 5) + 32).toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Up late?', style: AppFonts.display(size: 40)),
                  IconButton(
                    icon: const Icon(Icons.settings, color: AppColors.accent),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.location_on, color: AppColors.muted, size: 20),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: AppFonts.body(color: AppColors.text),
                        decoration: InputDecoration(
                          hintText: 'Search city...',
                          hintStyle: AppFonts.body(color: AppColors.muted),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onSubmitted: _fetchWeather,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _fetchWeather(_searchController.text),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Icon(Icons.search, color: AppColors.bg, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(240, 78, 106, 0.08),
                    border: Border.all(color: const Color.fromRGBO(240, 78, 106, 0.25)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppFonts.body(color: AppColors.danger, size: 14),
                  ),
                ),

              // Loading indicator
              if (_isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Fetching...', style: AppFonts.label()),
                      ],
                    ),
                  ),
                ),

              // Weather display
              if (_weatherData != null && !_isLoading) ...[
                const SizedBox(height: 24),
                Text(_weatherData!.city, style: AppFonts.display(size: 56)),
                Text(
                  '${_weatherData!.country} • ${_weatherData!.description.capitalize()}',
                  style: AppFonts.body(color: AppColors.muted, size: 14),
                ),
                const SizedBox(height: 32),

                // Temperature card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardTint,
                    border: Border.all(color: AppColors.cardBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _tempDisplay(_weatherData!.temp),
                            style: AppFonts.display(size: 64),
                          ),
                          Text(
                            _isCelsius ? '°C' : '°F',
                            style: AppFonts.body(color: AppColors.muted, size: 14),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Feels like', style: AppFonts.label(size: 11)),
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: Center(
                              child: Text(
                                _tempDisplay(_weatherData!.feelsLike),
                                style: AppFonts.display(size: 32),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // AQI Card
                if (_aqiData != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardTint,
                      border: Border.all(color: AppColors.cardBorder),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Air Quality', style: AppFonts.label()),
                        const SizedBox(height: 12),
                        Text(
                          'AQI: ${_aqiData!.aqi}',
                          style: AppFonts.display(size: 32),
                        ),
                        if (_aqiData!.stationName != null)
                          Text(
                            _aqiData!.stationName!,
                            style: AppFonts.body(color: AppColors.muted, size: 12),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Other metrics
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildMetricCard('Humidity', '${_weatherData!.humidity}%'),
                    _buildMetricCard('Wind Speed', '${_weatherData!.windSpeed.toStringAsFixed(1)} m/s'),
                    _buildMetricCard('Pressure', '${_weatherData!.pressure} hPa'),
                    _buildMetricCard('Visibility', '${(_weatherData!.visibility / 1000).toStringAsFixed(1)} km'),
                  ],
                ),
              ],

              // History
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text('History', style: AppFonts.label(size: 12)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => _fetchWeather(item.city),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardTint,
                              border: Border.all(color: AppColors.cardBorder),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.city, style: AppFonts.body(size: 14, weight: FontWeight.w500)),
                                Text('${item.tempC.toStringAsFixed(1)}°C', style: AppFonts.body(color: AppColors.accent)),
                                if (item.aqiNum != null)
                                  Text('AQI: ${item.aqiNum}', style: AppFonts.label(size: 10)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardTint,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppFonts.label(size: 11)),
          Text(value, style: AppFonts.display(size: 24)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
