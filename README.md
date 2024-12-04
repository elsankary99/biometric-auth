######Biometric Auth
![Biometric-Authentication-blog.webp](https://prod-files-secure.s3.us-west-2.amazonaws.com/0eb85db8-8316-4f89-ae92-bbf4ccd7b91d/e8f4d028-f150-463f-b921-ca085d494e09/Biometric-Authentication-blog.webp)

### Summary of the Biometric Authentication Process

1. **User Registration or Account Creation:**
   - The user registers or logs in normally for the first time.
   - During this process, the **token** and **user ID** are stored securely.
2. **Activating Biometric Authentication:**
   - If the user opts to enable biometric authentication, the `registerBiometricUser()` function is invoked.
   - This function saves the **device ID** linked to the user for future authentication.
3. **Biometric Login Workflow:**
   - When logging in using biometrics, the `authenticateUser()` function is called:
     - **Step 1:** It verifies that biometrics are supported and available on the device using `checkBiometricAvailability()`.
     - **Step 2:** If biometric data is valid, it proceeds with authentication by sending the credentials to the backend via `_sendBiometricAuthToServer()`.
4. **Fast and Simple Login:**
   - If all the above steps succeed, the user is logged in seamlessly using biometric data without needing to re-enter credentials.

This process ensures both security and convenience for the user by leveraging biometric technology.

## Login

**Purpose:**

Handles normal login by authenticating with the backend using the email and password.

**Details:**

- Sends a `POST` request to the `/auth/login` endpoint with the user's credentials.
- If successful:
  - Stores the authentication token and user ID in secure storage for future use.
- If unsuccessful, throws an exception with an error message.

```dart
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

```

---

## Register

**Purpose:**

Allows a new user to register an account by providing their email, password, and password confirmation.

**Details:**

- Sends a `POST` request to the `/auth/register` endpoint.
- If successful:
  - Stores the authentication token and user ID in secure storage.
- Handles exceptions for failed registration.

```dart
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

```

---

## Logout

**Purpose:**

Logs out the user and removes their authentication token from secure storage.

**Details:**

- Sends a `POST` request to the `/auth/logout` endpoint (if a token exists).
- Deletes the authentication token from secure storage to log out the user locally.

```dart
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

```

## IsLoggedIn

**Purpose:**

Checks if the user is already logged in by verifying the presence of an authentication token in secure storage.

**Details:**

- Reads the token from `FlutterSecureStorage`.
- Returns `true` if the token exists; otherwise, `false`.

```dart
Future<bool> isLoggedIn() async {
  String? token = await _secureStorage.read(key: 'auth_token');
  return token != null;
}

```

---

## RegisterBiometricUser

**Purpose:**

Registers the user for biometric authentication by sending the device ID and token to the backend.

**Details:**

- Retrieves the device ID using the `getDeviceId` function.
- Sends a `POST` request to the `/auth/register-biometric` endpoint with the device ID.
- Checks the server's response and logs any errors.

```dart
Future<bool> registerBiometricUser() async {
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

```

---

## GetDeviceId

**Purpose:**

Fetches the unique device ID for Android or iOS devices.

**Details:**

- Uses the `DeviceInfoPlugin` to get the device's unique identifier.
- Returns the identifier based on the platform (Android or iOS).

```dart
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

```

---

## CheckBiometricAvailability

**Purpose:**

Checks if the device has biometric capabilities and if any biometrics are enrolled.

**Details:**

- Uses `LocalAuthentication` to verify biometric capabilities.
- Returns `true` if biometrics are available and enrolled.

```dart
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

```

---

## AuthenticateUser

**Purpose:**

Authenticates the user using biometrics and sends the data to the backend.

**Details:**

- Calls `checkBiometricAvailability` to ensure biometrics are available.
- Prompts the user to authenticate using biometrics.
- If successful, calls `_sendBiometricAuthToServer` to complete the process.

```dart
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

```

---

## SendBiometricAuthToServer

**Purpose:**

Sends the user ID and device ID to the server for biometric login.

**Details:**

- Retrieves the user ID and device ID from secure storage.
- Sends a `POST` request to the `/auth/biometric-login` endpoint.
- Stores the new token if the response is successful.

```dart
Future<bool> _sendBiometricAuthToServer() async {
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

```
