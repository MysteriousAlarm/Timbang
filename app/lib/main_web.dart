import 'core/bootstrap.dart';
import 'core/router/redirect.dart';
import 'core/theme/forest_gold_theme.dart';

/// Website + admin entrypoint: Forest and Gold.
/// flutter run -d chrome -t lib/main_web.dart
Future<void> main() => bootstrap(target: AppTarget.web, theme: forestGoldTheme);
