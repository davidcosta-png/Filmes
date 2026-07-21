import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/auth_page.dart';
import 'pages/home_page.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedThemeDark = prefs.getBool('theme_dark') ?? false;
  runApp(MyApp(isDark: savedThemeDark));
}

class ThemeNotifier extends ChangeNotifier {
  bool isDark;
  ThemeNotifier(this.isDark);

  toggle() async {
    isDark = !isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_dark', isDark);
  }
}

class AuthNotifier extends ChangeNotifier {
  String? username;
  String? role;
  String? token;
  String? refreshToken;

  bool get isLoggedIn => token != null && token!.isNotEmpty;
  bool get isAdmin => role == 'admin';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');
    refreshToken = prefs.getString('refresh_token');
    username = prefs.getString('current_user');
    role = prefs.getString('current_role');

    // If there's a token, validate with backend /auth/me to refresh profile
    if (token != null && token!.isNotEmpty) {
      try {
        final svc = AuthService();
        final profile = await svc.me(token!);
        username = profile['username'];
        role = profile['role'];
        await prefs.setString('current_user', username ?? '');
        await prefs.setString('current_role', role ?? '');
      } catch (e) {
        // token invalid — try refresh token
        if (refreshToken != null && refreshToken!.isNotEmpty) {
          try {
            final svc = AuthService();
            final refreshed = await svc.refresh(refreshToken!);
            token = refreshed['token'];
            refreshToken = refreshed['refreshToken'];
            final profile = await svc.me(token!);
            username = profile['username'];
            role = profile['role'];
            await prefs.setString('auth_token', token ?? '');
            await prefs.setString('refresh_token', refreshToken ?? '');
            await prefs.setString('current_user', username ?? '');
            await prefs.setString('current_role', role ?? '');
          } catch (e2) {
            // refresh failed — clear
            token = null;
            refreshToken = null;
            await prefs.remove('auth_token');
            await prefs.remove('refresh_token');
            await prefs.remove('current_user');
            await prefs.remove('current_role');
          }
        } else {
          token = null;
          await prefs.remove('auth_token');
          await prefs.remove('current_user');
          await prefs.remove('current_role');
        }
      }
    }

    notifyListeners();
  }

  Future<void> loginWithProfile(String t, Map<String, dynamic> profile, {String? refresh}) async {
    token = t;
    refreshToken = refresh;
    username = profile['username'];
    role = profile['role'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token ?? '');
    if (refreshToken != null) await prefs.setString('refresh_token', refreshToken!);
    if (username != null) await prefs.setString('current_user', username!);
    if (role != null) await prefs.setString('current_role', role!);
    notifyListeners();
  }

  Future<void> refreshUsingStored() async {
    if (refreshToken == null) return;
    try {
      final svc = AuthService();
      final refreshed = await svc.refresh(refreshToken!);
      final profile = await svc.me(refreshed['token']);
      await loginWithProfile(refreshed['token'], profile, refresh: refreshed['refreshToken']);
    } catch (e) {
      // ignore
    }
  }

  Future<void> logout() async {
    try {
      final svc = AuthService();
      if (refreshToken != null) {
        await svc.logout(refreshToken!);
      }
    } catch (e) {
      // ignore errors on logout
    }
    token = null;
    username = null;
    role = null;
    refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('current_user');
    await prefs.remove('current_role');
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  final bool isDark;
  const MyApp({Key? key, required this.isDark}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier(isDark)),
        ChangeNotifierProvider(create: (_) => AuthNotifier()..load()),
      ],
      child: Consumer<ThemeNotifier>(builder: (context, theme, _) {
        return MaterialApp(
          title: 'Stream Aggregator (Prototype)',
          theme: ThemeData.light().copyWith(
            colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue),
          ),
          darkTheme: ThemeData.dark(),
          themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
          home: Consumer<AuthNotifier>(builder: (context, auth, _) {
            return auth.isLoggedIn ? HomePage() : AuthPage();
          }),
        );
      }),
    );
  }
}

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com> 