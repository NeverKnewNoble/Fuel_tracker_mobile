import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fuel_tracker/frappe_API/config.dart';
import 'package:http/http.dart' as http;

class LoginException implements Exception {
  final String message;
  final String type;

  LoginException(this.message, this.type);
}

// Function to verify login credentials using the Frappe API
Future<Map<String, dynamic>> verifyLogin(String email, String password) async {
  const url = '$baseUrl/api/v2/method/fuel_tracker.api.login.verify_login';

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'username': email,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);

      // Check if the login was successful
      if (responseData['data']['status'] == 'success') {
        return {
          'status': responseData['data']['status'],
          'message': responseData['data']['message'],
          'api_key': responseData['data']['api_key'],
          'api_secret': responseData['data']['api_secret'],
        };
      } else {
        // Handle specific login failure cases
        final String errorMessage = responseData['data']['message']?.toString().toLowerCase() ?? '';
        String userMessage;
        
        if (errorMessage.contains('user not found') || errorMessage.contains('user does not exist') || errorMessage.contains('no user found')) {
          userMessage = 'User not found in the system. Please check your email or register for an account.';
        } else if (errorMessage.contains('incorrect password') || errorMessage.contains('wrong password') || errorMessage.contains('invalid password')) {
          userMessage = 'Incorrect password. Please check your password and try again.';
        } else if (errorMessage.contains('invalid email') || errorMessage.contains('incorrect email')) {
          userMessage = 'Invalid email address. Please check your email and try again.';
        } else if (errorMessage.contains('invalid credentials') || errorMessage.contains('authentication failed')) {
          userMessage = 'Invalid email or password. Please check your credentials and try again.';
        } else {
          userMessage = responseData['data']['message'] ?? 'Invalid email or password';
        }
       
        return {
          'status': responseData['data']['status'],
          'message': userMessage,
        };
      }
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw LoginException('Invalid email or password', 'auth');
    } else if (response.statusCode >= 500) {
      throw LoginException('Server is temporarily unavailable. Please try again later.', 'server');
    } else {
      throw LoginException('Something went wrong. Please try again.', 'unknown');
    }
  } on SocketException {
    throw LoginException('No internet connection. Please check your network.', 'network');
  } on TimeoutException {
    throw LoginException('Connection timed out. Please check your internet and try again.', 'timeout');
  } on FormatException {
    throw LoginException('Invalid response from server. Please try again.', 'format');
  }
}