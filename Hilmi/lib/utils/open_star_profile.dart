import 'package:flutter/material.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/screens/star_profile_screen.dart';

Future<void> openStarProfile(
  BuildContext context, {
  required ProfileStory story,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => StarProfileScreen(story: story),
    ),
  );
}

/// 由用户 id / 展示信息打开个人详情页。
void openStarProfileForUser(
  BuildContext context, {
  required String userId,
  String? name,
  String? email,
  String? imageUrl,
}) {
  final id = userId.trim();
  if (id.isEmpty) return;
  openStarProfile(
    context,
    story: ProfileStory(
      id: id,
      name: name,
      imageUrl: imageUrl,
      email: email,
    ),
  );
}
