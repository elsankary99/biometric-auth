import 'package:flutter/material.dart';
import 'package:biometric_login/biometric_authentication_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoggedIn = false;
  bool _isLoading = false;
  String _loginStatus = 'Not Logged In';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () async {
        final deviceId = await _authService.getDeviceId();
        const secureStorage = FlutterSecureStorage();
        await secureStorage.write(key: 'device_id', value: deviceId);
      },
    );
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    bool loggedIn = await _authService.isLoggedIn();
    setState(() {
      _isLoggedIn = loggedIn;
      _loginStatus = loggedIn ? 'Logged In' : 'Not Logged In';
    });
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      await _authService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      await _checkLoginStatus();
      _showSnackBar('Login Successful');
    } catch (e) {
      _showSnackBar('Login Failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBiometricLogin() async {
    setState(() => _isLoading = true);
    try {
      bool success = await _authService.authenticateUser();
      if (success) {
        await _checkLoginStatus();
        _showSnackBar('Biometric Login Successful');
      } else {
        _showSnackBar('Biometric Login Failed');
      }
    } catch (e) {
      _showSnackBar('Biometric Login Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegisterBiometric() async {
    setState(() => _isLoading = true);
    try {
      final success = await _authService.registerBiometricUser();
      if (success) {
        await _checkLoginStatus();
        _showSnackBar('Biometric Register Successful');
      } else {
        _showSnackBar('Biometric Register Failed');
      }
    } catch (e) {
      _showSnackBar('Biometric Register Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    await _authService.logout();
    await _checkLoginStatus();
    _showSnackBar('Logged Out Successfully');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentication')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Login Status: $_loginStatus',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isLoggedIn ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            if (!_isLoggedIn) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Login'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleBiometricLogin,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Biometric Login'),
              ),
            ],
            if (_isLoggedIn) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleRegisterBiometric,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Register Biometric'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _handleLogout,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
