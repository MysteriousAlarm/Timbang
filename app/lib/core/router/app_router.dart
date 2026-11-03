import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_shell.dart';
import '../../features/admin/presentation/audit_page.dart';
import '../../features/admin/presentation/catalog_page.dart';
import '../../features/admin/presentation/moderation_page.dart';
import '../../features/admin/presentation/overview_page.dart';
import '../../features/admin/presentation/prices_page.dart';
import '../../features/admin/presentation/sms_page.dart';
import '../../features/admin/presentation/users_page.dart';
import '../../features/alerts/presentation/alerts_tab.dart';
import '../../features/auth/application/session.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/catalog/domain/catalog_item.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/inquiries/presentation/inbox_tab.dart';
import '../../features/landing/presentation/landing_page.dart';
import '../../features/listings/presentation/create_listing_screen.dart';
import '../../features/listings/presentation/listing_detail_screen.dart';
import '../../features/listings/presentation/listings_tab.dart';
import '../../features/price_board/presentation/commodity_detail_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/profile_setup_screen.dart';
import '../../features/reports/presentation/report_price_screen.dart';
import '../../shared/widgets/state_views.dart';
import '../theme/forest_gold_theme.dart';
import '../theme/harvest_earth_theme.dart';
import 'redirect.dart';

final appTargetProvider = Provider<AppTarget>((ref) => AppTarget.mobile);

/// Farmer/buyer screens always use Harvest Earth, even inside the website build,
/// so a farmer on a phone browser sees the same app. Landing + admin use Forest and Gold.
Widget _farmerTheme(Widget child) => Theme(data: harvestEarthTheme, child: child);
Widget _webTheme(Widget child) => Theme(data: forestGoldTheme, child: child);

final routerProvider = Provider<GoRouter>((ref) {
  final target = ref.watch(appTargetProvider);
  final refresh = ValueNotifier<Session>(ref.read(sessionProvider));
  ref.listen(sessionProvider, (_, next) => refresh.value = next);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: target == AppTarget.web ? Routes.landing : Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(refresh.value, state.matchedLocation, target),
    routes: [
      GoRoute(
        path: Routes.landing,
        builder: (_, _) =>
            target == AppTarget.web ? _webTheme(const LandingPage()) : const LoadingView(),
      ),
      GoRoute(path: Routes.splash, builder: (_, _) => const LoadingView()),
      GoRoute(
        path: Routes.login,
        builder: (_, _) => _farmerTheme(const PhoneScreen()),
        routes: [GoRoute(path: 'otp', builder: (_, _) => _farmerTheme(const OtpScreen()))],
      ),
      GoRoute(
        path: '/prices/:id',
        builder: (_, state) =>
            _farmerTheme(CommodityDetailScreen(commodityId: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: Routes.newListing,
        builder: (_, _) => _farmerTheme(const CreateListingScreen()),
      ),
      GoRoute(
        path: '/listings/:id',
        builder: (_, state) =>
            _farmerTheme(ListingDetailScreen(listingId: state.pathParameters['id']!)),
      ),
      GoRoute(path: Routes.report, builder: (_, _) => _farmerTheme(const ReportPriceScreen())),
      GoRoute(path: Routes.setup, builder: (_, _) => _farmerTheme(const ProfileSetupScreen())),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _farmerTheme(HomeShell(shell: shell)),
        branches: [
          _tab(Routes.prices, const HomePage()),
          _tab(Routes.listings, const ListingsTab()),
          _tab(Routes.inquiries, const InboxTab()),
          _tab(Routes.alerts, const AlertsTab()),
          _tab(Routes.profile, const ProfileScreen()),
        ],
      ),
      ShellRoute(
        builder: (_, state, child) =>
            _webTheme(AdminShell(location: state.matchedLocation, child: child)),
        routes: [
          GoRoute(path: Routes.admin, builder: (_, _) => const AdminOverviewPage()),
          GoRoute(
            path: Routes.adminCommodities,
            builder: (_, _) => const CatalogPage(kind: CatalogKind.commodities),
          ),
          GoRoute(
            path: Routes.adminMarkets,
            builder: (_, _) => const CatalogPage(kind: CatalogKind.markets),
          ),
          GoRoute(path: Routes.adminPrices, builder: (_, _) => const AdminPricesPage()),
          GoRoute(path: Routes.adminUsers, builder: (_, _) => const AdminUsersPage()),
          GoRoute(path: Routes.adminModeration, builder: (_, _) => const AdminModerationPage()),
          GoRoute(path: Routes.adminAudit, builder: (_, _) => const AdminAuditPage()),
          GoRoute(path: Routes.adminSms, builder: (_, _) => const AdminSmsPage()),
        ],
      ),
    ],
  );
});

StatefulShellBranch _tab(String path, Widget page) => StatefulShellBranch(
  routes: [
    GoRoute(
      path: path,
      builder: (_, _) => PhoneWidth(child: page),
    ),
  ],
);
