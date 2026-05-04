import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/constants/api_constants.dart';

class FeedbackModel {
  final String id;
  final String userId;
  final String? username;
  final String? profilePic;
  final String rating;
  final String kesan;
  final String saran;
  final String createdAt;

  FeedbackModel({
    required this.id,
    required this.userId,
    this.username,
    this.profilePic,
    required this.rating,
    required this.kesan,
    required this.saran,
    required this.createdAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String?,
      profilePic: json['profile_pic'] as String?,
      rating: json['rating'] as String? ?? '',
      kesan: json['kesan'] as String? ?? '',
      saran: json['saran'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class FeedbackRepository {
  final Dio _dio = ApiClient.instance;

  Future<List<FeedbackModel>> getFeedbacks() async {
    final response = await _dio.get(ApiConstants.feedbacks);
    final List<dynamic> data = response.data;
    return data.map((json) => FeedbackModel.fromJson(json)).toList();
  }

  Future<FeedbackModel> createFeedback(String token, {
    required String rating,
    required String kesan,
    required String saran,
  }) async {
    final response = await _dio.post(
      ApiConstants.feedbacks,
      queryParameters: {'token': token},
      data: {
        'rating': rating,
        'kesan': kesan,
        'saran': saran,
      },
    );
    return FeedbackModel.fromJson(response.data);
  }

  Future<void> deleteFeedback(String token, String id) async {
    await _dio.delete(
      ApiConstants.deleteFeedback(id),
      queryParameters: {'token': token},
    );
  }
}
