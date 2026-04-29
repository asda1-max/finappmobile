import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/user_model.dart';

/// Repository handling all auth-related API calls.
class AuthRepository {
  final Dio _dio = ApiClient.instance;

  /// Register a new user.
  Future<UserModel> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiConstants.authRegister,
      data: {
        'username': username,
        'email': email,
        'password': password,
      },
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Login with username + password, returns user with JWT token.
  Future<UserModel> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiConstants.authLogin,
      data: {
        'username': username,
        'password': password,
      },
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get current user profile using JWT token.
  Future<UserModel> getProfile(String token) async {
    final response = await _dio.get(
      ApiConstants.authMe,
      queryParameters: {'token': token},
    );
    return UserModel.fromJson(
      response.data as Map<String, dynamic>,
      token: token,
    );
  }
}
