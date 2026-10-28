import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/admin/admin_queue_screen.dart';
import '../features/admin/admin_reports_screen.dart';
import '../features/admin/admin_review_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/name_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/inquiries/inquiries_screen.dart';
import '../features/listings/listing_form_screen.dart';
import '../features/listings/manage_listing_screen.dart';
import '../features/listings/my_listings_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/properties/favorites_screen.dart';
import '../features/properties/home_screen.dart';
import '../features/properties/property_detail_screen.dart';
import '../features/shell/main_shell.dart';

// Browsing is public, so there is no global redirect: screens that need an account
// show a login prompt, and actions send the user to /login on demand.
final appRouter = GoRouter(
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/account', builder: (_, _) => const AccountScreen())]),
      ],
    ),
    GoRoute(
      path: '/property/:id',
      builder: (_, state) => PropertyDetailScreen(propertyId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/admin/queue', builder: (_, _) => const AdminQueueScreen()),
    GoRoute(path: '/admin/reports', builder: (_, _) => const AdminReportsScreen()),
    GoRoute(
      path: '/admin/review/:id',
      builder: (_, state) => AdminReviewScreen(propertyId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
    GoRoute(path: '/inquiries', builder: (_, _) => const InquiriesScreen()),
    GoRoute(path: '/my-listings', builder: (_, _) => const MyListingsScreen()),
    // 'new' must come before ':id' or it would be read as an id.
    GoRoute(path: '/listing/new', builder: (_, _) => const ListingFormScreen()),
    GoRoute(
      path: '/listing/:id',
      builder: (_, state) => ManageListingScreen(propertyId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'edit',
          builder: (_, state) => ListingFormScreen(propertyId: state.pathParameters['id']),
        ),
      ],
    ),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(
      path: '/login/otp',
      builder: (_, state) {
        final args = state.extra;
        // The extra is lost on a process restart; start over from the phone screen.
        return args is OtpArgs ? OtpScreen(args: args) : const LoginScreen();
      },
    ),
    GoRoute(path: '/login/name', builder: (_, _) => const NameScreen()),
  ],
  errorBuilder: (_, _) => const Scaffold(body: Center(child: Text('الصفحة غير موجودة'))),
);
