import 'dart:convert';
import 'package:fuel_tracker/frappe_API/config.dart';
import 'package:http/http.dart' as http;

// Function to verify login credentials using the Frappe API
Future<Map<String, dynamic>> verifyLogin(String email, String password) async {
  const url = '$baseUrl/api/v2/method/fuel_tracker.api.login.verify_login'; 
  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'username': email,  
      'password': password,
    }),
  );

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
      // Handle login failure
      return {
        'status': responseData['data']['status'],
        'message': responseData['data']['message'],
      };
    }
  } else {
    throw Exception('Failed to log in');
  }
}