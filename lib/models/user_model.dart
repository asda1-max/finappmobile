/// Simple user model for auth state.
class UserModel {
  final String userId;
  final String username;
  final String email;
  final String token;
  final String? profilePic;
  final int? prefStabilitas;
  final int? prefPertumbuhan;
  final int? prefDividen;
  final int? prefRisiko;

  const UserModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.token,
    this.profilePic,
    this.prefStabilitas,
    this.prefPertumbuhan,
    this.prefDividen,
    this.prefRisiko,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    return UserModel(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      token: token ?? json['token'] as String? ?? '',
      profilePic: json['profile_pic'] as String?,
      prefStabilitas: json['pref_stabilitas'] as int?,
      prefPertumbuhan: json['pref_pertumbuhan'] as int?,
      prefDividen: json['pref_dividen'] as int?,
      prefRisiko: json['pref_risiko'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'email': email,
        'token': token,
        'profile_pic': profilePic,
        'pref_stabilitas': prefStabilitas,
        'pref_pertumbuhan': prefPertumbuhan,
        'pref_dividen': prefDividen,
        'pref_risiko': prefRisiko,
      };
}
