/// Simple user model for auth state.
class UserModel {
  final String userId;
  final String username;
  final String email;
  final String token;
  final String? profilePic;
  final String? portfolioGoals;
  final String? minat;

  const UserModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.token,
    this.profilePic,
    this.portfolioGoals,
    this.minat,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    return UserModel(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      token: token ?? json['token'] as String? ?? '',
      profilePic: json['profile_pic'] as String?,
      portfolioGoals: json['portfolio_goals'] as String?,
      minat: json['minat'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'email': email,
        'token': token,
        'profile_pic': profilePic,
        'portfolio_goals': portfolioGoals,
        'minat': minat,
      };
}
