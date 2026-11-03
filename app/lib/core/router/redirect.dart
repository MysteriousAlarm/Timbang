import '../../features/auth/application/session.dart';

/// Which build target is running. Decides the public routes and the default theme.
enum AppTarget { mobile, web }

abstract final class Routes {
  static const landing = '/';
  static const splash = '/splash';
  static const login = '/login';
  static const otp = '/login/otp';
  static const setup = '/setup';
  static const prices = '/app/prices';
  static const listings = '/app/listings';
  static const inquiries = '/app/inquiries';
  static const alerts = '/app/alerts';
  static const profile = '/app/profile';
  static const admin = '/admin';
  static const adminCommodities = '/admin/commodities';
  static const adminMarkets = '/admin/markets';
  static const adminPrices = '/admin/prices';
  static const adminUsers = '/admin/users';
  static const adminModeration = '/admin/moderation';
  static const adminAudit = '/admin/audit';
  static const adminSms = '/admin/sms';
  static const report = '/report';
  static String commodity(String id) => '/prices/$id';
  static const newListing = '/listings/new';
  static String listing(String id) => '/listings/$id';
}

/// Pure redirect logic (unit tested). Returns null to stay on [location].
String? resolveRedirect(Session session, String location, AppTarget target) {
  final isPublicLanding = target == AppTarget.web && location == Routes.landing;
  final onLogin = location == Routes.login || location == Routes.otp;

  switch (session) {
    case SessionLoading():
      if (isPublicLanding || location == Routes.splash) return null;
      return Routes.splash;
    case SignedOut():
      if (isPublicLanding || onLogin) return null;
      return target == AppTarget.web && location == Routes.splash ? Routes.landing : Routes.login;
    case NeedsProfile():
      if (isPublicLanding || location == Routes.setup) return null;
      return Routes.setup;
    case SignedIn(:final isAdmin):
      final home = target == AppTarget.web && isAdmin ? Routes.admin : Routes.prices;
      if (location == Routes.splash || onLogin || location == Routes.setup) return home;
      if (target == AppTarget.mobile && location == Routes.landing) return home;
      // Admins can manage TIMBANG from the website OR the phone app.
      if (location.startsWith(Routes.admin) && !isAdmin) return Routes.prices;
      return null;
  }
}
