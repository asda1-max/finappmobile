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

  /// Update user profile.
  Future<UserModel> updateProfile(
    String token, {
    String? username,
    String? email,
    String? password,
    String? portfolioGoals,
    String? minat,
  }) async {
    final response = await _dio.put(
      ApiConstants.authMe,
      queryParameters: {'token': token},
      data: {
        if (username != null) 'username': username,
        if (email != null) 'email': email,
        if (password != null) 'password': password,
        if (portfolioGoals != null) 'portfolio_goals': portfolioGoals,
        if (minat != null) 'minat': minat,
      },
    );
    return UserModel.fromJson(
      response.data as Map<String, dynamic>,
      token: token,
    );
  }

  /// Upload profile picture.
  Future<String> uploadProfilePicture(String token, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(
      ApiConstants.authProfilePicture,
      queryParameters: {'token': token},
      data: formData,
    );
    return response.data['profile_pic'] as String;
  }

  /// Get Hybrid preset recommendations.
  Future<Map<String, dynamic>> getHybridPreset(String goals, String minat) async {
    final response = await _dio.get(
      '/hybrid-preset',
      queryParameters: {
        'goals': goals,
        'minat': minat,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
