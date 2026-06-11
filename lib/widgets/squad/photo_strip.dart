import 'package:flutter/material.dart';
import '../../models/photo.dart';
import '../../screens/squad/camera_screen.dart';

/// Pushes the camera for [squadId]; on a send, shows a brief confirmation.
/// Photos ship immediately; viewing is per-member via the story viewer.
Future<void> launchProofCamera(BuildContext context, String squadId, {PhotoGoalRef? goalRef}) async {
  final result = await Navigator.push<PhotoSent>(
      context, CameraScreen.route(squadId: squadId, goalRef: goalRef));
  if (result != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Shared with your squad'), duration: Duration(seconds: 2)));
  }
}
