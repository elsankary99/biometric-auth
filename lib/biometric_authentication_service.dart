import 'dart:developer';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://biometric.rizme-labs.xyz/api',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuthentication = LocalAuthentication();

// This Function Will check if the user login or not
  Future<bool> isLoggedIn() async {
    String? token = await _secureStorage.read(key: 'auth_token');
    return token != null;
  }

//==== Normal Auth ==============
// This is the normal login and after login we store some information like (Token - email - id) to use in in biometric register ans login
  Future<void> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        await _secureStorage.write(
            key: 'auth_token', value: responseData['token']);
        await _secureStorage.write(
            key: 'user_id', value: responseData['user']['id'].toString());
      } else {
        throw Exception(response.data['message'] ?? 'Login failed');
      }
    } catch (e) {
      log('Login error: $e');
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'password_confirmation': confirmPassword,
        },
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        await _secureStorage.write(
            key: 'auth_token', value: responseData['token']);
        await _secureStorage.write(
            key: 'user_id', value: responseData['user']['id'].toString());
      } else {
        throw Exception(response.data['message'] ?? 'Login failed');
      }
    } catch (e) {
      log('Login error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      String? token = await _secureStorage.read(key: 'auth_token');
      if (token != null) {
        await _dio.post('/auth/logout',
            options: Options(headers: {'Authorization': 'Bearer $token'}));
      }
    } catch (e) {
      log('Logout error: $e');
    } finally {
      await _secureStorage.delete(key: 'auth_token');
    }
  }
// ===================================================================
// ================= Biometric Auth ==================================
// ===================================================================

// (1) Register biometric function it send deviceId with token to backend to save biometric data and check on it when user login with biometric auth
  Future<bool> registerBiometricUser() async {
    // Register Biometric
    try {
      String deviceId = await getDeviceId();
      String? token = await _secureStorage.read(key: 'auth_token');

      final response = await _dio.post('/auth/register-biometric',
          data: {'device_id': deviceId},
          options: Options(headers: {'Authorization': 'Bearer $token'}));

      return response.statusCode == 200;
    } catch (e) {
      log("registerBiometricUser Error");
      return false;
    }
  }

  // get deviceid function
  Future<String> getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "";
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  // This function check if the device has a biometric or not
  Future<bool> checkBiometricAvailability() async {
    try {
      bool canCheckBiometrics = await _localAuthentication.canCheckBiometrics;
      List<BiometricType> availableBiometrics =
          await _localAuthentication.getAvailableBiometrics();
      return canCheckBiometrics && availableBiometrics.isNotEmpty;
    } catch (e) {
      log('Biometric check error: $e');
      return false;
    }
  }

  // this function check after the device contain a biometric if the biometric is right or not
  // in right case it login and send user data like (email - deviceId) to check this data from
  // backend and check the email and the deviceId and return their user depending on email and DeviceId
  Future<bool> authenticateUser() async {
    try {
      bool isAvailable = await checkBiometricAvailability();
      if (!isAvailable) {
        log('Biometrics not available');
        return false;
      }

      bool authenticated = await _localAuthentication.authenticate(
        localizedReason: 'Please authenticate to proceed',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        return await _sendBiometricAuthToServer();
      }
      return false;
    } catch (e) {
      log('Authentication error: $e');
      return false;
    }
  }

  Future<bool> _sendBiometricAuthToServer() async {
    // Login Biometric

    try {
      String? userId = await _secureStorage.read(key: 'user_id');
      String? deviceId = await _secureStorage.read(key: 'device_id');

      if (userId == null || deviceId == null) {
        log('No stored credentials found');
        return false;
      }

      final response = await _dio.post(
        '/auth/biometric-login',
        data: {'user_id': userId, 'device_id': deviceId},
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        await _secureStorage.write(
            key: 'auth_token', value: responseData['token']);
        return true;
      }

      return false;
    } catch (e) {
      log('Server authentication error: $e');
      return false;
    }
  }
}
