import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/run.dart';
import '../widgets/run_share_card.dart';

class RunShareService {
  Future<void> shareRun({
    required Run run,
    required String username,
    required BuildContext context,
  }) async {
    final controller = ScreenshotController();
    final bytes = await controller.captureFromWidget(
      RunShareCard(run: run, username: username),
      pixelRatio: 1.0,
      context: context,
    );
    final tmp = await getTemporaryDirectory();
    final file = File(
      '${tmp.path}/run_${run.id}.png',
    );
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Ma course Train Your Heart',
    );
  }
}
