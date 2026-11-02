import 'core/bootstrap.dart';
import 'core/router/redirect.dart';
import 'core/theme/harvest_earth_theme.dart';

/// Mobile app entrypoint: Harvest Earth.
/// flutter run -t lib/main_app.dart
Future<void> main() => bootstrap(target: AppTarget.mobile, theme: harvestEarthTheme);
