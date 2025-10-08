import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  bool _isConnected = true;
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();

  // Bağlantı durumunu dinlemek için stream
  Stream<bool> get connectionStream => _connectionController.stream;
  
  // Mevcut bağlantı durumu
  bool get isConnected => _isConnected;

  // Bağlantı durumunu başlat
  Future<void> initialize() async {
    // İlk bağlantı durumunu kontrol et
    await _checkInitialConnection();
    
    // Bağlantı değişikliklerini dinle
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        print('Bağlantı kontrolü hatası: $error');
      },
    );
  }

  // İlk bağlantı durumunu kontrol et
  Future<void> _checkInitialConnection() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      _updateConnectionStatus(connectivityResults);
    } catch (e) {
      print('İlk bağlantı kontrolü hatası: $e');
      _isConnected = false;
      _connectionController.add(false);
    }
  }

  // Bağlantı durumu değiştiğinde çağrılır
  void _onConnectivityChanged(List<ConnectivityResult> connectivityResults) {
    _updateConnectionStatus(connectivityResults);
  }

  // Bağlantı durumunu güncelle
  void _updateConnectionStatus(List<ConnectivityResult> connectivityResults) {
    final wasConnected = _isConnected;
    
    // Herhangi bir bağlantı türü varsa bağlı sayılır
    _isConnected = connectivityResults.any((result) => 
      result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi || 
      result == ConnectivityResult.ethernet
    );

    // Durum değiştiyse stream'e bildir
    if (wasConnected != _isConnected) {
      _connectionController.add(_isConnected);
      print('Bağlantı durumu değişti: ${_isConnected ? "Bağlı" : "Bağlantısız"}');
    }
  }

  // Bağlantı durumunu manuel kontrol et
  Future<bool> checkConnection() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      _updateConnectionStatus(connectivityResults);
      return _isConnected;
    } catch (e) {
      print('Manuel bağlantı kontrolü hatası: $e');
      return false;
    }
  }

  // Servisi temizle
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionController.close();
  }
}
