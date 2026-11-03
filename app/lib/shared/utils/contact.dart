import 'package:url_launcher/url_launcher.dart';

/// Opens the phone dialer / SMS app. Contact numbers are only shown to signed-in users.
Future<bool> callNumber(String e164) => launchUrl(Uri(scheme: 'tel', path: e164));

Future<bool> textNumber(String e164, {String? body}) => launchUrl(
  Uri(scheme: 'sms', path: e164, queryParameters: body == null ? null : {'body': body}),
);
