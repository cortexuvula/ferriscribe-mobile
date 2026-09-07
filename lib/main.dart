import 'package:flutter/material.dart';

import 'app.dart';
import 'app_bootstrap.dart';
import 'security/local_auth_app_lock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppBootstrap.create(appLockAuth: LocalAuthGateImpl());
  runApp(FerriScribeApp(services: services));
}
