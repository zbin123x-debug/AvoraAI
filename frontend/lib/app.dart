// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';

import 'config/api_config.dart';
import 'services/api_client.dart';
import 'services/goal_metrics.dart';

const ink = Color(0xFF17231D);
const green = Color(0xFF236B4E);
const canvas = Color(0xFFF7F6F0);
const line = Color(0xFFE4E8E3);

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _roleLabel(Object? role) => switch (role) {
  'Admin' => 'Quản trị viên',
  'SuperAdmin' => 'Quản trị viên cấp cao',
  'User' => 'Người dùng',
  'Unknown' => 'Không xác định',
  _ => '$role',
};

String _auditActionLabel(Object? action) => switch (action) {
  'CreateAdmin' => 'Tạo tài khoản quản trị viên',
  'UpdateAdmin' => 'Cập nhật quản trị viên',
  'LockAdmin' => 'Khóa quản trị viên',
  'UnlockAdmin' => 'Mở khóa quản trị viên',
  'SoftDeleteAdmin' => 'Xóa quản trị viên',
  'RestoreAdmin' => 'Khôi phục quản trị viên',
  'RequestAdminEmailChange' => 'Yêu cầu đổi email quản trị viên',
  'ConfirmAdminEmailChange' => 'Xác nhận đổi email quản trị viên',
  'ChangeOwnAdminEmail' => 'Đổi email tài khoản quản trị',
  'ChangeOwnAdminPhone' => 'Đổi số điện thoại tài khoản quản trị',
  'CreateFood' => 'Thêm thực phẩm',
  'UpdateFood' => 'Cập nhật thực phẩm',
  'DeleteFood' => 'Xóa thực phẩm',
  'CheckFoodSource' => 'Kiểm tra nguồn dữ liệu thực phẩm',
  'VerifyFood' => 'Xác minh thực phẩm',
  'DeleteRating' => 'Xóa đánh giá',
  'UpdateOwnProfile' => 'Cập nhật hồ sơ cá nhân',
  _ => '$action',
};

String _auditOutcomeLabel(Object? outcome) => switch (outcome) {
  'Succeeded' => 'Thành công',
  'Failed' => 'Thất bại',
  _ => '$outcome',
};

bool _isPasswordLetter(int rune) {
  final char = String.fromCharCode(rune);
  return char.toLowerCase() != char.toUpperCase();
}

bool _hasPasswordDigit(String password) =>
    password.runes.any((r) => r >= 48 && r <= 57);

bool _hasPasswordSymbol(String password) => password.runes.any((r) {
  return (r >= 33 && r <= 47) ||
      (r >= 58 && r <= 64) ||
      (r >= 91 && r <= 96) ||
      (r >= 123 && r <= 126);
});

bool _isPasswordValid(String password) {
  if (password.length < 10 || password.length > 128 || password.isEmpty) {
    return false;
  }
  final firstRune = password.runes.first;
  final first = String.fromCharCode(firstRune);
  return _isPasswordLetter(firstRune) &&
      first == first.toUpperCase() &&
      first != first.toLowerCase() &&
      _hasPasswordDigit(password) &&
      _hasPasswordSymbol(password);
}

const _passwordRequirement =
    'Mật khẩu dài 10–128 ký tự, bắt đầu bằng chữ hoa, có ít nhất một số và một ký tự đặc biệt.';

class AvoraApp extends StatelessWidget {
  const AvoraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Avora AI',
    locale: const Locale('vi'),
    supportedLocales: const [Locale('vi')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(seedColor: green, surface: canvas),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: line),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? green
                : const Color(0xFF879089),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? green
                : const Color(0xFF879089),
            size: 22,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: ink,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        titleLarge: TextStyle(color: ink, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: ink),
        bodyMedium: TextStyle(color: Color(0xFF65726A)),
      ),
    ),
    home: const LaunchPage(),
  );
}

class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});
  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  final api = ApiClient();
  Map<String, dynamic>? session;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    api.restoreSession().then((s) {
      if (mounted) {
        setState(() {
          session = s;
          loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: green)),
      );
    }
    if (session == null) {
      return AuthPage(api: api, onSignedIn: (s) => setState(() => session = s));
    }
    if (session!['mustChangePassword'] == true) {
      return FirstLoginPasswordPage(
        api: api,
        requireOtp: true,
        onComplete: () => setState(() => session = null),
      );
    }
    if (session!['role'] == 'SuperAdmin') {
      return SuperAdminPage(
        api: api,
        onLogout: () => setState(() => session = null),
      );
    }
    if (session!['role'] == 'Admin') {
      return AdminPage(
        api: api,
        onLogout: () => setState(() => session = null),
      );
    }
    if (session!['profileComplete'] != true &&
        session!['profileComplete'] != 'true') {
      return OnboardingPage(
        api: api,
        step: int.tryParse('${session!['onboardingStep']}') ?? 1,
        onComplete: () => setState(() {
          session!['profileComplete'] = true;
        }),
      );
    }
    return UserShell(api: api, onLogout: () => setState(() => session = null));
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.api, required this.onSignedIn});
  final ApiClient api;
  final ValueChanged<Map<String, dynamic>> onSignedIn;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false, showPassword = false, showWelcome = false;
  String? error;
  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.api.post('/api/auth/login', {
        'email': email.text.trim(),
        'password': password.text,
      });
      await widget.api.persistSession(result);
      widget.onSignedIn(result);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      showWelcome ? _buildWelcome(context) : _buildLogin(context);

  Widget _buildLogin(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAF7),
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF1F8F1), Color(0xFFF9FBF8)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 740;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 112,
                  child: IgnorePointer(
                    child: CustomPaint(painter: _LandingWavesPainter()),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        26,
                        compact ? 18 : 30,
                        26,
                        24,
                      ),
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF12A64A),
                                      Color(0xFF006B37),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x24116B3B),
                                      blurRadius: 14,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.spa_outlined,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Avora',
                                    style: TextStyle(
                                      color: Color(0xFF173D2B),
                                      fontSize: 27,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.8,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDDF2DF),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Text(
                                      'AI',
                                      style: TextStyle(
                                        color: Color(0xFF16813E),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 21 : 31),
                        const Text(
                          'Ch\u{e0}o m\u{1eeb}ng b\u{1ea1}n tr\u{1edf} l\u{1ea1}i!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF163A29),
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '\u{110}\u{103}ng nh\u{1ead}p \u{111}\u{1ec3} ti\u{1ebf}p t\u{1ee5}c qu\u{1ea3}n l\u{fd} dinh d\u{1b0}\u{1ee1}ng c\u{f9}ng Avora AI.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF65726A),
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: compact ? 22 : 28),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            labelText: 'Email ho\u{1eb7}c s\u{1ed1} \u{111}i\u{1ec7}n tho\u{1ea1}i',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: !showPassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) {
                            if (!busy) login();
                          },
                          decoration: InputDecoration(
                            labelText: 'M\u{1ead}t kh\u{1ea9}u',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => showPassword = !showPassword),
                              icon: Icon(
                                showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _forgot(context, widget.api),
                            child: const Text(
                              'Qu\u{ea}n m\u{1ead}t kh\u{1ea9}u?',
                            ),
                          ),
                        ),
                        if (error != null) _ErrorBox(error!),
                        const SizedBox(height: 7),
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: busy ? null : login,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF07843E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                            child: busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    '\u{110}\u{103}ng nh\u{1ead}p',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 19),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: Color(0xFFD8DED9)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'Ho\u{1eb7}c \u{111}\u{103}ng nh\u{1ead}p b\u{1eb1}ng',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: Color(0xFFD8DED9)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        Row(
                          children: [
                            Expanded(
                              child: _AuthProviderButton(
                                label: 'Google',
                                mark: const Text(
                                  'G',
                                  style: TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4285F4),
                                  ),
                                ),
                                onPressed: () =>
                                    _showProviderMessage(context, 'Google'),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: _AuthProviderButton(
                                label: 'Facebook',
                                mark: const Text(
                                  'f',
                                  style: TextStyle(
                                    fontSize: 27,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1877F2),
                                  ),
                                ),
                                onPressed: () =>
                                    _showProviderMessage(context, 'Facebook'),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: _AuthProviderButton(
                                label: 'Apple',
                                mark: const Icon(
                                  Icons.apple,
                                  size: 22,
                                  color: Color(0xFF111111),
                                ),
                                onPressed: () =>
                                    _showProviderMessage(context, 'Apple'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Ch\u{1b0}a c\u{f3} t\u{e0}i kho\u{1ea3}n? ',
                                style: TextStyle(color: Color(0xFF59645D)),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RegisterPage(api: widget.api),
                                  ),
                                ),
                                child: const Text(
                                  'T\u{1ea1}o t\u{e0}i kho\u{1ea3}n m\u{1edb}i',
                                  style: TextStyle(
                                    color: Color(0xFF126B3B),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Center(
                          child: Text(
                            '\u{110}\u{103}ng nh\u{1ead}p nhanh, \u{111}\u{1ed3}ng b\u{1ed9} h\u{1ed3} s\u{1a1} dinh d\u{1b0}\u{1ee1}ng c\u{1ee7}a b\u{1ea1}n.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF7A837C),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  void _showProviderMessage(BuildContext context, String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '\u{110}\u{103}ng nh\u{1ead}p ' + provider + ' ch\u{1b0}a \u{111}\u{1b0}\u{1ee3}c k\u{1ebf}t n\u{1ed1}i. H\u{e3}y d\u{f9}ng email/s\u{1ed1} \u{111}i\u{1ec7}n tho\u{1ea1}i v\u{e0} m\u{1ead}t kh\u{1ea9}u.',
        ),
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF1F8F1), Color(0xFFF9FBF7), Color(0xFFF6FAF5)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 760;
            final heroHeight = compact ? 300.0 : 330.0;
            final artWidth = (constraints.maxWidth * .58)
                .clamp(190.0, 310.0)
                .toDouble();
            final headingWidth = (constraints.maxWidth * .63)
                .clamp(210.0, 340.0)
                .toDouble();
            final headingSize = constraints.maxWidth < 380 ? 27.0 : 29.0;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 132,
                  child: CustomPaint(painter: _LandingWavesPainter()),
                ),
                ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    SizedBox(
                      height: heroHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            right: -12,
                            top: compact ? 50 : 58,
                            width: artWidth,
                            height: compact ? 228 : 250,
                            child: Image.asset(
                              'assets/avora_landing_hero.png',
                              fit: BoxFit.contain,
                              alignment: Alignment.centerRight,
                            ),
                          ),
                          Positioned(left: 22, top: 14, child: _LandingBrand()),
                          Positioned(
                            left: 21,
                            top: compact ? 103 : 112,
                            width: headingWidth,
                            child: Text(
                              'Dinh dưỡng vừa vặn\nvới nhịp sống của\nbạn.',
                              style: TextStyle(
                                fontSize: headingSize,
                                height: 1.06,
                                letterSpacing: -1.0,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF172B22),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 27,
                            top: compact ? 210 : 228,
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A9A43),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 22,
                            top: compact ? 227 : 246,
                            width: (constraints.maxWidth * .54)
                                .clamp(190.0, 280.0)
                                .toDouble(),
                            child: const Text(
                              'Lập mục tiêu, theo dõi thông tin cá nhân và quản lý nguyên liệu bạn đang có.',
                              style: TextStyle(
                                color: Color(0xFF46594F),
                                height: 1.45,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      padding: const EdgeInsets.fromLTRB(8, 13, 8, 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0D173B2B),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            child: _LandingFeature(
                              icon: Icons.restaurant,
                              label: 'Gợi ý\nthực đơn',
                            ),
                          ),
                          Expanded(
                            child: _LandingFeature(
                              icon: Icons.track_changes,
                              label: 'Đặt mục tiêu\n(cân nặng, sức khỏe)',
                            ),
                          ),
                          Expanded(
                            child: _LandingFeature(
                              icon: Icons.bar_chart_rounded,
                              label: 'Theo dõi\ndinh dưỡng',
                            ),
                          ),
                          Expanded(
                            child: _LandingFeature(
                              icon: Icons.shopping_basket_outlined,
                              label: 'Quản lý\nnguyên liệu',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(38),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE4F4E5),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Text(
                                  'AVORA AI',
                                  style: TextStyle(
                                    color: Color(0xFF187441),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 17),
                              const Text(
                                'Bắt đầu cùng Avora',
                                style: TextStyle(
                                  fontSize: 29,
                                  height: 1.1,
                                  color: ink,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Đăng nhập để tiếp tục hoặc tạo tài khoản để thiết lập hồ sơ của bạn.',
                                style: TextStyle(
                                  color: Color(0xFF737C76),
                                  height: 1.4,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 23),
                              SizedBox(
                                width: double.infinity,
                                height: 58,
                                child: FilledButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          RegisterPage(api: widget.api),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.person_add_alt_1_outlined,
                                    size: 23,
                                  ),
                                  label: const Text(
                                    'Tạo tài khoản mới',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF087A42),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 13),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      setState(() => showWelcome = false),
                                  icon: const Icon(
                                    Icons.login_rounded,
                                    size: 23,
                                  ),
                                  label: const Text(
                                    'Tôi đã có tài khoản',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF17633F),
                                    side: const BorderSide(
                                      color: Color(0xFFD7DED8),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 112),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _LandingBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF075A32),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.spa_outlined, color: Colors.white, size: 27),
      ),
      const SizedBox(width: 10),
      const Text(
        'Avora',
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w800,
          color: Color(0xFF173B2D),
          letterSpacing: -1,
        ),
      ),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFCFEBC9),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Text(
          'AI',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17633F),
          ),
        ),
      ),
    ],
  );
}

class _LandingFeature extends StatelessWidget {
  const _LandingFeature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFE7F5E8),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Icon(icon, color: const Color(0xFF178343), size: 28),
      ),
      const SizedBox(height: 6),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF202B25),
          fontSize: 10.5,
          height: 1.15,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _LandingWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pale = Paint()..color = const Color(0xFFDFF3DF);
    final light = Paint()..color = const Color(0xFFBCE7BB);
    final green = Paint()..color = const Color(0xFF8FD18F);
    final top = Path()
      ..moveTo(0, size.height * .12)
      ..cubicTo(
        size.width * .16,
        size.height * .02,
        size.width * .28,
        size.height * .48,
        size.width * .49,
        size.height * .49,
      )
      ..cubicTo(
        size.width * .70,
        size.height * .52,
        size.width * .84,
        size.height * .12,
        size.width,
        size.height * .13,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final middle = Path()
      ..moveTo(0, size.height * .38)
      ..cubicTo(
        size.width * .20,
        size.height * .25,
        size.width * .32,
        size.height * .74,
        size.width * .56,
        size.height * .70,
      )
      ..cubicTo(
        size.width * .79,
        size.height * .67,
        size.width * .86,
        size.height * .31,
        size.width,
        size.height * .34,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final lower = Path()
      ..moveTo(0, size.height * .62)
      ..cubicTo(
        size.width * .22,
        size.height * .49,
        size.width * .39,
        size.height * .88,
        size.width * .61,
        size.height * .86,
      )
      ..cubicTo(
        size.width * .82,
        size.height * .84,
        size.width * .91,
        size.height * .56,
        size.width,
        size.height * .56,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(top, pale);
    canvas.drawPath(middle, light);
    canvas.drawPath(lower, green);
  }

  @override
  bool shouldRepaint(covariant _LandingWavesPainter oldDelegate) => false;
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final email = TextEditingController(),
      pw = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false;
  String? error;
  bool otp = false;
  int secondsRemaining = 60;
  Timer? timer;
  void _startCountdown() {
    timer?.cancel();
    secondsRemaining = 60;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        if (secondsRemaining > 0) secondsRemaining--;
        if (secondsRemaining == 0) t.cancel();
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    pw.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> resend() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post('/api/auth/register/resend', {
        'email': email.text.trim(),
      });
      _startCountdown();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> next() async {
    if (!otp && pw.text != confirm.text) {
      setState(() => error = 'Mật khẩu xác nhận chưa khớp.');
      return;
    }
    if (!otp && !_isPasswordValid(pw.text)) {
      setState(() => error = _passwordRequirement);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!otp) {
        await widget.api.post('/api/auth/register', {
          'email': email.text.trim(),
          'password': pw.text,
        });
        confirm.clear();
        setState(() => otp = true);
        _startCountdown();
      } else {
        await widget.api.post('/api/auth/verify-registration', {
          'email': email.text.trim(),
          'code': confirm.text.trim(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tài khoản đã xác minh. Hãy đăng nhập.'),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tạo tài khoản')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Bắt đầu cùng Avora.',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          otp
              ? 'Nhập mã 6 số được gửi tới ${email.text}. Mã có hiệu lực 60 giây.'
              : 'Đăng ký bằng email. Tài khoản chỉ hoạt động sau khi xác minh.',
        ),
        if (otp) ...[
          const SizedBox(height: 6),
          Text(
            secondsRemaining > 0
                ? 'Mã còn hiệu lực $secondsRemaining giây.'
                : 'Mã đã hết hạn. Bạn có thể gửi mã mới.',
          ),
        ],
        const SizedBox(height: 28),
        if (!otp) ...[
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: pw,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu'),
          ),
          const SizedBox(height: 6),
          const Text(_passwordRequirement),
          const SizedBox(height: 14),
          TextField(
            controller: confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu'),
          ),
        ] else
          TextField(
            controller: confirm,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Mã xác thực'),
          ),
        if (error != null) _ErrorBox(error!),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: busy ? null : next,
          child: Text(
            busy
                ? 'Đang xử lý…'
                : otp
                ? 'Xác minh'
                : 'Tiếp tục',
          ),
        ),
        if (otp)
          TextButton(
            onPressed: busy || secondsRemaining > 0 ? null : resend,
            child: const Text('Gửi lại mã'),
          ),
      ],
    ),
  );
}

Future<void> _forgot(BuildContext context, ApiClient api) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => ForgotPasswordPage(api: api)));

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController();
  final code = TextEditingController();
  final password = TextEditingController();
  bool busy = false, codeSent = false, showPassword = false;
  int secondsRemaining = 0;
  Timer? timer;
  String? error;

  void _startCountdown() {
    timer?.cancel();
    setState(() => secondsRemaining = 60);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        if (secondsRemaining > 0) secondsRemaining--;
        if (secondsRemaining == 0) t.cancel();
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    code.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final address = email.text.trim();
    if (address.isEmpty || !address.contains('@')) {
      setState(() => error = 'Vui lòng nhập email hợp lệ.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post('/api/auth/forgot-password', {'email': address});
      if (!mounted) return;
      setState(() => codeSent = true);
      _startCountdown();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (code.text.trim().length != 6) {
      setState(() => error = 'Mã xác thực phải gồm 6 chữ số.');
      return;
    }
    if (!_isPasswordValid(password.text)) {
      setState(() => error = _passwordRequirement);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post('/api/auth/reset-password', {
        'email': email.text.trim(),
        'code': code.text.trim(),
        'newPassword': password.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mật khẩu đã được đặt lại. Hãy đăng nhập.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quên mật khẩu')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Khôi phục tài khoản',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              codeSent
                  ? 'Nhập mã 6 số đã gửi tới ${email.text}. Mã có hiệu lực trong 60 giây.'
                  : 'Nhập email đã đăng ký. Chúng tôi sẽ gửi mã xác thực để bạn đặt mật khẩu mới.',
            ),
            if (codeSent) ...[
              const SizedBox(height: 6),
              Text(
                secondsRemaining > 0
                    ? 'Bạn có thể gửi lại mã sau $secondsRemaining giây.'
                    : 'Bạn có thể yêu cầu gửi mã mới.',
              ),
            ],
            const SizedBox(height: 28),
            TextField(
              controller: email,
              enabled: !codeSent,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            if (codeSent) ...[
              const SizedBox(height: 14),
              TextField(
                controller: code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Mã xác thực 6 số',
                  prefixIcon: Icon(Icons.verified_outlined),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: password,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => showPassword = !showPassword),
                    icon: Icon(
                      showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(_passwordRequirement),
            ],
            if (error != null) _ErrorBox(error!),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: busy ? null : (codeSent ? _resetPassword : _sendCode),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(codeSent ? 'Đặt lại mật khẩu' : 'Gửi mã xác thực'),
            ),
            if (codeSent)
              TextButton(
                onPressed: busy || secondsRemaining > 0 ? null : _sendCode,
                child: const Text('Gửi lại mã'),
              ),
          ],
        ),
      ),
    ),
  );
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.api,
    required this.step,
    required this.onComplete,
  });
  final ApiClient api;
  final int step;
  final VoidCallback onComplete;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late int step;
  final name = TextEditingController(),
      birth = TextEditingController(),
      height = TextEditingController(),
      weight = TextEditingController(),
      allergy = TextEditingController();
  int mealsPerDay = 3;
  String gender = 'Chưa chọn',
      diet = 'Ăn bình thường',
      activity = 'Ít vận động';
  bool noAllergy = true, busy = false, loading = true;
  final allergies = <String>[];
  String? error;
  @override
  void initState() {
    super.initState();
    step = widget.step;
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.api.get('/api/me/profile', auth: true);
      name.text = '${r['fullName'] ?? ''}';
      final savedBirthDate = DateTime.tryParse('${r['birthDate'] ?? ''}');
      if (savedBirthDate != null) birth.text = _formatBirthDate(savedBirthDate);
      height.text = '${r['heightCm'] ?? ''}';
      weight.text = '${r['weightKg'] ?? ''}';
      final savedMealsPerDay = int.tryParse('${r['mealsPerDay'] ?? ''}');
      if (savedMealsPerDay == 3 ||
          savedMealsPerDay == 4 ||
          savedMealsPerDay == 5) {
        mealsPerDay = savedMealsPerDay!;
      }
      if (['Nữ', 'Nam', 'Khác'].contains(r['gender'])) gender = r['gender'];
      if (['Ăn bình thường', 'Ăn chay'].contains(r['diet'])) diet = r['diet'];
      if ([
        'Ít vận động',
        'Vận động nhẹ',
        'Vận động vừa',
        'Vận động nhiều',
      ].contains(r['activityLevel'])) {
        activity = r['activityLevel'];
      }
      noAllergy = r['noAllergies'] == true;
      final raw = r['allergiesJson'];
      if (raw is String) {
        final decoded = raw.isEmpty
            ? <String>[]
            : (jsonDecode(raw) as List<dynamic>)
                  .map((e) => e.toString())
                  .toList();
        allergies.addAll(decoded);
      }
    } catch (_) {
      /* A new profile returns 404; use the blank form. */
    }
    if (mounted) setState(() => loading = false);
  }

  String _formatBirthDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year.toString().padLeft(4, '0')}';

  String? _birthDateForApi() {
    final parts = birth.text.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final apiDate = _birthDateForApi();
    final existing = apiDate == null ? null : DateTime.tryParse(apiDate);
    final selected = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Ch\u1ecdn ng\u00e0y sinh',
      cancelText: 'H\u1ee7y',
      confirmText: 'Ch\u1ecdn',
    );
    if (selected != null) {
      setState(() => birth.text = _formatBirthDate(selected));
    }
  }

  Future<void> next() async {
    if (step == 1 &&
        (name.text.trim().isEmpty ||
            height.text.isEmpty ||
            weight.text.isEmpty)) {
      setState(() => error = 'Hãy nhập họ tên, chiều cao và cân nặng.');
      return;
    }
    if (step == 1 && _birthDateForApi() == null) {
      setState(() => error = 'H\u00e3y ch\u1ecdn ng\u00e0y sinh.');
      return;
    }
    if (step == 2 && noAllergy && allergies.isNotEmpty) {
      setState(
        () => error = 'Bỏ chọn “Không có dị ứng” trước khi thêm dị ứng.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.put('/api/me/profile', {
        'fullName': name.text.trim().isEmpty ? null : name.text.trim(),
        'birthDate': _birthDateForApi(),
        'gender': gender == 'Chưa chọn' ? null : gender,
        'heightCm': double.tryParse(height.text),
        'weightKg': double.tryParse(weight.text),
        'mealsPerDay': mealsPerDay,
        'diet': diet,
        'noAllergies': noAllergy,
        'allergies': allergies,
        'activityLevel': activity,
        'step': step,
      }, auth: true);
      if (step < 3) {
        setState(() => step++);
      } else {
        widget.onComplete();
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    TextEditingController c,
    String label, {
    TextInputType type = TextInputType.text,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(labelText: label),
    ),
  );
  Widget select(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: values
        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
        .toList(),
    onChanged: onChanged,
  );
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: green)),
      );
    }
    final children = <Widget>[
      LinearProgressIndicator(
        value: step / 3,
        color: green,
        backgroundColor: line,
        borderRadius: BorderRadius.circular(8),
      ),
      const SizedBox(height: 24),
      Text(
        step == 1
            ? 'Thông tin cơ thể'
            : step == 2
            ? 'Thói quen ăn uống'
            : 'Vận động & xem lại',
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      const SizedBox(height: 8),
      Text('Bước $step trên 3'),
      const SizedBox(height: 24),
    ];
    if (step == 1) {
      children.addAll([
        field(name, 'Họ và tên'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: _pickBirthDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Ngày sinh',
                suffixIcon: Icon(Icons.calendar_month_outlined),
              ),
              child: Text(
                birth.text.isEmpty ? 'Chọn ngày / tháng / năm' : birth.text,
              ),
            ),
          ),
        ),
        select('Giới tính', gender, [
          'Chưa chọn',
          'Nữ',
          'Nam',
          'Khác',
        ], (v) => setState(() => gender = v!)),
        const SizedBox(height: 12),
        field(height, 'Chiều cao (cm)', type: TextInputType.number),
        field(weight, 'Cân nặng hiện tại (kg)', type: TextInputType.number),
      ]);
    } else if (step == 2) {
      children.addAll([
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<int>(
            initialValue: mealsPerDay,
            decoration: const InputDecoration(
              labelText: 'Số bữa ăn mỗi ngày',
              helperText: 'Chọn 3, 4 hoặc 5 bữa',
            ),
            items: const [
              DropdownMenuItem(value: 3, child: Text('3 bữa')),
              DropdownMenuItem(value: 4, child: Text('4 bữa')),
              DropdownMenuItem(value: 5, child: Text('5 bữa')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => mealsPerDay = value);
            },
          ),
        ),
        select('Chế độ ăn', diet, [
          'Ăn bình thường',
          'Ăn chay',
        ], (v) => setState(() => diet = v!)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Không có dị ứng'),
          value: noAllergy,
          onChanged: (v) {
            setState(() => noAllergy = v);
            if (v) allergies.clear();
          },
        ),
        if (!noAllergy)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: allergy,
                  decoration: const InputDecoration(
                    labelText: 'Thêm nguyên liệu dị ứng',
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    if (allergy.text.trim().isNotEmpty) {
                      allergies.add(allergy.text.trim());
                    }
                    allergy.clear();
                  });
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        Wrap(
          spacing: 8,
          children: allergies
              .map(
                (a) => InputChip(
                  label: Text(a),
                  onDeleted: () => setState(() => allergies.remove(a)),
                ),
              )
              .toList(),
        ),
      ]);
    } else {
      children.addAll([
        select('Mức độ vận động', activity, [
          'Ít vận động',
          'Vận động nhẹ',
          'Vận động vừa',
          'Vận động nhiều',
        ], (v) => setState(() => activity = v!)),
        const SizedBox(height: 20),
        const _InfoCard(
          icon: Icons.fact_check_outlined,
          title: 'Kiểm tra hồ sơ',
          text: 'Thông tin được lưu vào tài khoản của bạn. Avora AI chưa tạo thực đơn hay chỉ số dinh dưỡng.',
        ),
        Text('Họ tên: ${name.text.isEmpty ? '—' : name.text}'),
        Text('Ăn uống: $diet · $mealsPerDay bữa/ngày'),
        Text('Vận động: $activity'),
      ]);
    }
    if (error != null) children.add(_ErrorBox(error!));
    children.addAll([
      const SizedBox(height: 20),
      FilledButton(
        onPressed: busy ? null : next,
        child: Text(
          busy
              ? 'Đang lưu…'
              : step == 3
              ? 'Hoàn tất'
              : 'Tiếp tục',
        ),
      ),
    ]);
    return Scaffold(
      appBar: AppBar(
        leading: step > 1
            ? IconButton(
                onPressed: () => setState(() => step--),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text('Hồ sơ  ·  $step/3'),
        actions: [
          TextButton(
            onPressed: busy ? null : next,
            child: Text(
              step == 3 ? 'Hoàn tất' : 'Tiếp tục',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
        children: children,
      ),
    );
  }
}

class UserShell extends StatefulWidget {
  const UserShell({super.key, required this.api, required this.onLogout});
  final ApiClient api;
  final VoidCallback onLogout;
  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int tab = 0;
  Map<String, dynamic> profile = {};
  final _homePageKey = GlobalKey<_HomePageState>();
  final _goalDashboardKey = GlobalKey<_GoalDashboardPageState>();
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final loaded = await widget.api.get('/api/me/profile', auth: true);
      if (mounted) setState(() => profile = loaded);
    } catch (_) {
      if (mounted) setState(() => profile = {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        key: _homePageKey,
        api: widget.api,
        profile: profile,
        onPersonal: () => setState(() => tab = 3),
        onFridge: () => setState(() => tab = 2),
        onMeal: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DishCatalogPage(api: widget.api)),
        ),
        onFoods: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FoodDirectoryPage(api: widget.api)),
        ),
        onFavorites: () async {
          await Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => FavoritesPage(api: widget.api)),
          );
          await _homePageKey.currentState?._loadSummary();
        },
      ),
      GoalDashboardPage(key: _goalDashboardKey, api: widget.api),
      FridgePage(api: widget.api),
      PersonalPage(
        api: widget.api,
        profile: profile,
        onLogout: widget.onLogout,
        onGoalHistory: () => setState(() => tab = 1),
        onProfileChanged: (value) {
          final mealCountChanged =
              profile['mealsPerDay'] != value['mealsPerDay'];
          setState(() => profile = value);
          if (mealCountChanged) _goalDashboardKey.currentState?.load();
        },
        onFavoritesChanged: () => _homePageKey.currentState?._loadSummary(),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: tab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_outlined),
            selectedIcon: Icon(Icons.track_changes),
            label: 'Mục tiêu',
          ),
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen),
            label: 'Tủ lạnh',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.profile,
    required this.onPersonal,
    required this.onFoods,
    required this.onFavorites,
    required this.onFridge,
    required this.onMeal,
  });
  final ApiClient api;
  final Map<String, dynamic> profile;
  final VoidCallback onPersonal, onFoods, onFavorites, onFridge, onMeal;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? fridgeCount;
  int? favoriteCount;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final results = await Future.wait([
        widget.api.get('/api/me/fridge', auth: true),
        widget.api.get('/api/me/favorites', auth: true),
      ]);
      if (!mounted) return;
      setState(() {
        fridgeCount = (results[0]['data'] as List<dynamic>? ?? []).length;
        favoriteCount = (results[1]['data'] as List<dynamic>? ?? []).length;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          fridgeCount = null;
          favoriteCount = null;
        });
      }
    }
  }

  String get _greetingName {
    final fullName = '${widget.profile['fullName'] ?? ''}'.trim();
    return fullName.isEmpty ? 'bạn' : fullName.split(RegExp(r'\s+')).last;
  }

  String _today(DateTime date) {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    return '${weekdays[date.weekday - 1]} · ${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _today(DateTime.now()),
                  style: const TextStyle(
                    color: Color(0xFF6B7770),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chào $_greetingName',
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: widget.onPersonal,
            customBorder: const CircleBorder(),
            child: _ProfileAvatar(
              api: widget.api,
              profile: widget.profile,
              radius: 23,
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      Container(
        constraints: const BoxConstraints(minHeight: 218),
        padding: const EdgeInsets.fromLTRB(19, 19, 18, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E6248),
          borderRadius: BorderRadius.circular(21),
          boxShadow: const [
            BoxShadow(
              color: Color(0x251E6248),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -52,
              bottom: -76,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF1D1A7),
                  border: Border.all(color: const Color(0xFFF8E8CD), width: 12),
                ),
              ),
            ),
            const Positioned(
              right: 22,
              bottom: 28,
              child: Icon(
                Icons.eco_rounded,
                size: 68,
                color: Color(0xCC739B68),
              ),
            ),
            SizedBox(
              width: MediaQuery.sizeOf(context).width * .62,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'AVORA AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  const Text(
                    'Bắt đầu từ những gì đang có.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Quản lý nguyên liệu và hồ sơ trong cùng một nơi.',
                    style: TextStyle(
                      color: Color(0xFFD7E8DE),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: widget.onMeal,
                    icon: const Icon(Icons.restaurant_menu_outlined, size: 17),
                    label: const Text('Món ăn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: green,
                      minimumSize: const Size(0, 39),
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Khám phá',
        style: TextStyle(fontSize: 19, color: ink, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) => GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth > 580 ? 1.9 : 1.28,
          children: [
            _HomeTile(
              icon: Icons.eco_outlined,
              title: 'Thực phẩm',
              description: 'Danh mục đã xác minh',
              color: const Color(0xFFEAF3ED),
              onTap: widget.onFoods,
            ),
            _HomeTile(
              icon: Icons.favorite_border,
              title: 'Món yêu thích',
              description: favoriteCount == null
                  ? 'Xem các mục đã lưu'
                  : '$favoriteCount món đã lưu',
              color: const Color(0xFFFFF0E4),
              onTap: widget.onFavorites,
            ),
            _HomeTile(
              icon: Icons.directions_run_outlined,
              title: 'Vận động',
              description:
                  '${widget.profile['activityLevel'] ?? 'Xem mức vận động trong hồ sơ'}',
              color: const Color(0xFFEAF0F6),
              onTap: widget.onPersonal,
            ),
            _HomeTile(
              icon: Icons.menu_book_outlined,
              title: 'Công thức món ăn',
              description: 'Khám phá các món ăn',
              color: const Color(0xFFF1EAF6),
              onTap: widget.onMeal,
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: widget.onFridge,
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: const Border.fromBorderSide(BorderSide(color: line)),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3ED),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.kitchen_outlined, color: green),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tủ lạnh của bạn',
                      style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fridgeCount == null
                          ? 'Mở để xem nguyên liệu đã lưu'
                          : '$fridgeCount nguyên liệu đang được lưu',
                      style: const TextStyle(
                        color: Color(0xFF6B7770),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9AA29D)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1E9),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome_outlined, color: green, size: 20),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hồ sơ cá nhân hóa',
                    style: TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Cập nhật thông tin để hoàn thiện trải nghiệm của bạn.',
                    style: TextStyle(
                      color: Color(0xFF6B7770),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title, description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 23, color: green),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6B7770), fontSize: 9),
            ),
          ],
        ),
      ),
    ),
  );
}

class DishCatalogPage extends StatefulWidget {
  const DishCatalogPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<DishCatalogPage> createState() => _DishCatalogPageState();
}

class _DishCatalogPageState extends State<DishCatalogPage> {
  bool loading = true;
  String? error;
  String searchText = '';
  String selectedCategory = '';
  int selectedStars = 0;
  List<dynamic> dishes = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.get('/api/dishes', auth: true);
      dishes = result['data'] as List<dynamic>? ?? [];
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openDish(Map<String, dynamic> dish) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            DishDetailPage(api: widget.api, dishId: '${dish['id']}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('M\u00f3n \u0103n')),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: green))
        : error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!, textAlign: TextAlign.center),
                TextButton(
                  onPressed: load,
                  child: const Text('Th\u1eed l\u1ea1i'),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: load,
            child: Builder(
              builder: (context) {
                final categories =
                    dishes
                        .map(
                          (raw) =>
                              '${(raw as Map<String, dynamic>)['category'] ?? ''}',
                        )
                        .where((value) => value.trim().isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort();
                final visible = dishes.where((raw) {
                  final dish = raw as Map<String, dynamic>;
                  final name = '${dish['name'] ?? ''}'.toLowerCase();
                  final category = '${dish['category'] ?? ''}';
                  final breakdown = dish['ratingBreakdown'];
                  final selectedCount = selectedStars == 0 || breakdown is! Map
                      ? 0
                      : int.tryParse('${breakdown['$selectedStars']}') ?? 0;
                  return name.contains(searchText.toLowerCase()) &&
                      (selectedCategory.isEmpty ||
                          category == selectedCategory) &&
                      (selectedStars == 0 || selectedCount > 0);
                }).toList();
                int starsCount(Map<String, dynamic> dish, int stars) {
                  final breakdown = dish['ratingBreakdown'];
                  if (breakdown is! Map) return 0;
                  return int.tryParse('${breakdown['$stars']}') ?? 0;
                }

                visible.sort((left, right) {
                  final a = left as Map<String, dynamic>;
                  final b = right as Map<String, dynamic>;
                  final countCompare = selectedStars == 0
                      // Trong "Tất cả", ưu tiên nhiều đánh giá 4–5 sao.
                      ? (starsCount(b, 4) + starsCount(b, 5)).compareTo(
                          starsCount(a, 4) + starsCount(a, 5),
                        )
                      : starsCount(
                          b,
                          selectedStars,
                        ).compareTo(starsCount(a, selectedStars));
                  if (countCompare != 0) return countCompare;
                  if (selectedStars == 0) {
                    final fiveStarCompare = starsCount(
                      b,
                      5,
                    ).compareTo(starsCount(a, 5));
                    if (fiveStarCompare != 0) return fiveStarCompare;
                  }
                  final averageA = (a['averageRating'] as num?) ?? 0;
                  final averageB = (b['averageRating'] as num?) ?? 0;
                  final averageCompare = averageB.compareTo(averageA);
                  return averageCompare != 0
                      ? averageCompare
                      : '${a['name']}'.compareTo('${b['name']}');
                });
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'T\u00ecm t\u00ean m\u00f3n \u0103n',
                      ),
                      onChanged: (value) =>
                          setState(() => searchText = value.trim()),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Tất cả'),
                            selected: selectedStars == 0,
                            onSelected: (_) =>
                                setState(() => selectedStars = 0),
                          ),
                          const SizedBox(width: 6),
                          for (final stars in [5, 4, 3, 2, 1]) ...[
                            ChoiceChip(
                              label: Text('$stars★'),
                              selected: selectedStars == stars,
                              onSelected: (_) =>
                                  setState(() => selectedStars = stars),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory.isEmpty
                            ? ''
                            : selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Nh\u00f3m m\u00f3n',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('T\u1ea5t c\u1ea3 nh\u00f3m'),
                          ),
                          ...categories.map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => selectedCategory = value ?? ''),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (dishes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Text(
                            'Ch\u01b0a c\u00f3 m\u00f3n \u0103n \u0111\u01b0\u1ee3c c\u00f4ng b\u1ed1.',
                          ),
                        ),
                      )
                    else if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Text(
                            'Kh\u00f4ng t\u00ecm th\u1ea5y m\u00f3n ph\u00f9 h\u1ee3p.',
                          ),
                        ),
                      ),
                    ...visible.map((raw) {
                      final dish = raw as Map<String, dynamic>;
                      final ingredientCount =
                          (dish['ingredients'] as List<dynamic>? ?? []).length;
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEAF3ED),
                            child: Icon(
                              Icons.restaurant_outlined,
                              color: green,
                            ),
                          ),
                          title: Text(
                            '${dish['name'] ?? 'M\u00f3n \u0103n'}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${dish['category'] ?? ''} \u00b7 $ingredientCount nguy\u00ean li\u1ec7u \u00b7 '
                            '${dish['averageRating'] ?? '—'}★ (${dish['ratingCount'] ?? 0})',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => openDish(dish),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
  );
}

class DishDetailPage extends StatefulWidget {
  const DishDetailPage({super.key, required this.api, required this.dishId});
  final ApiClient api;
  final String dishId;

  @override
  State<DishDetailPage> createState() => _DishDetailPageState();
}

class _DishDetailPageState extends State<DishDetailPage> {
  Map<String, dynamic>? dish;
  List<Map<String, dynamic>> ratings = [];
  final comment = TextEditingController();
  int selectedRating = 0;
  bool editingRating = false;
  bool savingRating = false;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        widget.api.get('/api/dishes/${widget.dishId}', auth: true),
        widget.api.get('/api/dishes/${widget.dishId}/ratings', auth: true),
      ]);
      dish = results[0];
      ratings = ((results[1]['ratings'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>();
      selectedRating = int.tryParse('${dish?['myRating'] ?? 0}') ?? 0;
      comment.text = '${dish?['myComment'] ?? ''}';
      editingRating = selectedRating == 0;
      error = null;
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveRating() async {
    if (selectedRating < 1 || selectedRating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn số sao từ 1 đến 5 trước khi gửi.')),
      );
      return;
    }
    final submittedStars = selectedRating;
    setState(() => savingRating = true);
    try {
      await widget.api.put('/api/me/ratings/${widget.dishId}', {
        'stars': submittedStars,
        'comment': comment.text.trim(),
      }, auth: true);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              submittedStars >= 4
                  ? 'Đã lưu đánh giá và đưa món vào Mục yêu thích.'
                  : 'Đã lưu đánh giá và bỏ món khỏi Mục yêu thích.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => savingRating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết món ăn')),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: green))
        : error != null
        ? Center(child: Text(error!, textAlign: TextAlign.center))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${dish?['name'] ?? 'Món ăn'}',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              Text('${dish?['category'] ?? ''}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFE89A37)),
                  const SizedBox(width: 5),
                  Text(
                    '${dish?['averageRating'] ?? '—'} / 5',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Text('(${dish?['ratingCount'] ?? 0} đánh giá)'),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Khẩu phần công thức gốc: 1 người'),
              const SizedBox(height: 22),
              const Text(
                'Nguyên liệu và định lượng',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              ...((dish?['ingredients'] as List<dynamic>? ?? []).map((raw) {
                final ingredient = raw as Map<String, dynamic>;
                final amount = ingredient['amountInstruction'];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.circle, size: 8, color: green),
                  title: Text('${ingredient['name'] ?? ''}'),
                  trailing: Text(
                    amount == null || '$amount'.trim().isEmpty
                        ? 'Chưa có định lượng'
                        : '$amount',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              })),
              if ((dish?['cookingNotes'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Ghi chú (cách nấu)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text('${dish?['cookingNotes']}'),
              ],
              const SizedBox(height: 24),
              Text(
                dish?['myRating'] != null && !editingRating
                    ? 'Đánh giá của bạn'
                    : 'Đánh giá và góp ý',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (dish?['myRating'] != null && !editingRating)
                OutlinedButton.icon(
                  onPressed: () => setState(() => editingRating = true),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Chỉnh sửa đánh giá'),
                )
              else ...[
                Row(
                  children: [
                    for (var star = 1; star <= 5; star++)
                      IconButton(
                        tooltip: '$star sao',
                        onPressed: () => setState(() => selectedRating = star),
                        icon: Icon(
                          star <= selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: const Color(0xFFE89A37),
                          size: 30,
                        ),
                      ),
                  ],
                ),
                TextField(
                  controller: comment,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Góp ý về món ăn',
                    hintText: 'Chia sẻ nhận xét của bạn',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: savingRating ? null : saveRating,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(
                    savingRating
                        ? 'Đang lưu…'
                        : dish?['myRating'] != null
                        ? 'Lưu chỉnh sửa'
                        : 'Gửi đánh giá',
                  ),
                ),
                if (dish?['myRating'] != null)
                  TextButton(
                    onPressed: savingRating
                        ? null
                        : () => setState(() {
                            selectedRating =
                                int.tryParse('${dish?['myRating']}') ?? 0;
                            comment.text = '${dish?['myComment'] ?? ''}';
                            editingRating = false;
                          }),
                    child: const Text('Hủy chỉnh sửa'),
                  ),
              ],
              const SizedBox(height: 18),
              const Text(
                'Nhận xét của người dùng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if (ratings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Chưa có đánh giá nào cho món này.'),
                ),
              ...ratings.map(
                (rating) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star,
                        color: Color(0xFFE89A37),
                        size: 18,
                      ),
                      Text('${rating['stars']}'),
                    ],
                  ),
                  title: Text(
                    '${rating['comment'] ?? ''}'.trim().isEmpty
                        ? 'Không có góp ý'
                        : '${rating['comment']}',
                  ),
                  subtitle: Text('${rating['updatedAtUtc'] ?? ''}'),
                ),
              ),
            ],
          ),
  );
}

class MealPlannerPage extends StatefulWidget {
  const MealPlannerPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<MealPlannerPage> createState() => _MealPlannerPageState();
}

class _MealPlannerPageState extends State<MealPlannerPage> {
  bool loading = true;
  String? error;
  List<dynamic> ingredients = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.api.get('/api/me/fridge', auth: true);
      ingredients = result['data'] as List<dynamic>? ?? [];
      error = null;
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Khám phá bữa ăn')),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: green))
        : error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!, textAlign: TextAlign.center),
                  TextButton(onPressed: load, child: const Text('Thử lại')),
                ],
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E6248),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.restaurant_menu_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Bữa ăn theo nguyên liệu của bạn',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Avora sẽ ưu tiên những nguyên liệu đang có trong tủ lạnh.',
                      style: TextStyle(color: Color(0xFFD7E8DE), height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF7D9C3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF9B5C31)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Giao diện gợi ý bữa ăn đang được hoàn thiện. Hiện chưa có món ăn hay dữ liệu dinh dưỡng để tính toán.',
                        style: TextStyle(
                          color: Color(0xFF75492D),
                          height: 1.5,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 23),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nguyên liệu hiện có',
                    style: TextStyle(
                      fontSize: 18,
                      color: ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${ingredients.length}',
                    style: const TextStyle(color: Color(0xFF6B7770)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (ingredients.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.kitchen_outlined,
                          color: green,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tủ lạnh chưa có nguyên liệu',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Mở tủ lạnh'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...ingredients.map((raw) {
                  final item = raw as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEAF3ED),
                        child: Icon(Icons.eco_outlined, color: green),
                      ),
                      title: Text('${item['name']}'),
                      subtitle: Text(
                        item['foodId'] == null
                            ? 'Nguyên liệu bạn đã nhập'
                            : 'Từ danh mục thực phẩm đã xác minh',
                      ),
                    ),
                  );
                }),
            ],
          ),
  );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.api,
    required this.profile,
    required this.radius,
  });
  final ApiClient api;
  final Map<String, dynamic> profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fullName = '${profile['fullName'] ?? ''}'.trim();
    final avatarUrl = profile['avatarUrl'];
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE4EDE2),
      foregroundImage: avatarUrl is String && avatarUrl.isNotEmpty
          ? NetworkImage(
              '${ApiConfig.baseUrl}$avatarUrl',
              headers: {
                if (api.accessToken != null)
                  'Authorization': 'Bearer ${api.accessToken}',
              },
            )
          : null,
      onForegroundImageError: avatarUrl is String ? (_, _) {} : null,
      child: Text(
        fullName.isEmpty ? 'A' : fullName.characters.first.toUpperCase(),
        style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FoodGroupFilter {
  _FoodGroupFilter(this.key, this.label, this.order);
  final String key;
  final String label;
  final int order;
  final Set<String> foodGroupIds = {};
}

class FoodDirectoryPage extends StatefulWidget {
  const FoodDirectoryPage({super.key, required this.api, this.onAdded});
  final ApiClient api;
  final VoidCallback? onAdded;
  @override
  State<FoodDirectoryPage> createState() => _FoodDirectoryPageState();
}

class _FoodDirectoryPageState extends State<FoodDirectoryPage> {
  final search = TextEditingController();
  List<Map<String, dynamic>> foods = [];
  Set<String> fridgeFoodIds = {};
  Set<String> fridgeNames = {};
  String? error;
  bool loading = true;
  String? addingId;
  String selectedFoodGroup = 'all';

  List<_FoodGroupFilter> get foodGroupFilters {
    final groups = <String, _FoodGroupFilter>{};
    for (final food in foods) {
      final groupValue = food['foodGroup'];
      if (groupValue is! Map) continue;
      final group = Map<String, dynamic>.from(groupValue);
      final groupId = '${food['foodGroupId'] ?? group['id'] ?? ''}';
      if (groupId.isEmpty || groupId == 'null') continue;
      final code = '${group['code'] ?? ''}'.toUpperCase().replaceAll(
        RegExp(r'[^A-Z0-9]'),
        '',
      );
      final name = '${group['name'] ?? 'Khác'}';
      final (key, label, order) = _foodGroupPresentation(code, name);
      final filter = groups.putIfAbsent(
        key,
        () => _FoodGroupFilter(key, label, order),
      );
      filter.foodGroupIds.add(groupId);
    }
    final categories = groups.values.toList()
      ..sort((a, b) {
        final order = a.order.compareTo(b.order);
        return order == 0 ? a.label.compareTo(b.label) : order;
      });
    return [_FoodGroupFilter('all', 'Tất cả', -1), ...categories];
  }

  (String, String, int) _foodGroupPresentation(String code, String name) {
    if (code == 'VEGETABLE' || code == 'ROOT') {
      return ('vegetables', 'Rau củ', 0);
    }
    if (code == 'FRUIT') return ('fruit', 'Trái cây', 1);
    if (code == 'MEAT') return ('meat', 'Thịt', 2);
    if (code == 'FISH' || code == 'SEAFOOD' || code == 'SHRIMP') {
      return ('seafood', 'Cá & hải sản', 3);
    }
    if (code == 'EGG' || code == 'DAIRY' || code == 'MILK') {
      return ('egg_dairy', 'Trứng & sữa', 4);
    }
    if (code == 'GRAIN' || code == 'CEREAL' || code == 'RICE') {
      return ('grains', 'Ngũ cốc', 5);
    }
    if (code == 'NUT') return ('nuts', 'Các loại hạt', 6);
    if (code == 'OIL' || code == 'FAT') return ('oils', 'Dầu mỡ', 7);
    if (code == 'SPICE' || code == 'CONDIMENT' || code == 'SEASONING') {
      return ('seasoning', 'Gia vị', 8);
    }
    return ('group:$code:$name', name, 100);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final responses = await Future.wait([
        widget.api.get('/api/foods'),
        widget.api.get('/api/me/fridge', auth: true),
      ]);
      foods = (responses[0]['data'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      if (!foodGroupFilters.any((filter) => filter.key == selectedFoodGroup)) {
        selectedFoodGroup = 'all';
      }
      final fridge = responses[1]['data'] as List<dynamic>? ?? [];
      fridgeFoodIds = fridge
          .where((item) => item['foodId'] != null)
          .map((item) => '${item['foodId']}')
          .toSet();
      fridgeNames = fridge
          .map((item) => '${item['name']}'.trim().toLowerCase())
          .toSet();
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addToFridge(Map<String, dynamic> food) async {
    final id = '${food['id']}';
    if (fridgeFoodIds.contains(id) ||
        fridgeNames.contains('${food['name']}'.trim().toLowerCase())) {
      setState(() {
        fridgeFoodIds.add(id);
        fridgeNames.add('${food['name']}'.trim().toLowerCase());
      });
      return;
    }
    setState(() {
      addingId = id;
      error = null;
    });
    try {
      await widget.api.post('/api/me/fridge', {
        'name': food['name'],
        'foodId': food['id'],
      }, auth: true);
      if (!mounted) return;
      setState(() {
        fridgeFoodIds.add(id);
        fridgeNames.add('${food['name']}'.trim().toLowerCase());
      });
      widget.onAdded?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${food['name']} đã có trong Tủ lạnh.')),
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => addingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final term = search.text.trim().toLowerCase();
    final filters = foodGroupFilters;
    final selectedFilter = filters.firstWhere(
      (filter) => filter.key == selectedFoodGroup,
      orElse: () => filters.first,
    );
    final visible = foods.where((food) {
      if (!'${food['name']}'.toLowerCase().contains(term)) return false;
      if (selectedFilter.key == 'all') return true;
      return selectedFilter.foodGroupIds.contains(
        '${food['foodGroupId'] ?? ''}',
      );
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thực phẩm'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Tìm nguyên liệu chưa chế biến',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          if (!loading && error == null)
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = filters[index];
                  final selected = filter.key == selectedFilter.key;
                  return ChoiceChip(
                    label: Text(filter.label),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: green,
                    backgroundColor: const Color(0xFFEAF3ED),
                    side: BorderSide(
                      color: selected ? green : const Color(0xFFDCE6DF),
                    ),
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : ink,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    onSelected: (_) =>
                        setState(() => selectedFoodGroup = filter.key),
                  );
                },
              ),
            ),
          if (loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: green)),
            )
          else if (error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!, textAlign: TextAlign.center),
                    TextButton(onPressed: load, child: const Text('Thử lại')),
                  ],
                ),
              ),
            )
          else if (visible.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  term.isEmpty && selectedFilter.key == 'all'
                      ? 'Chưa có nguyên liệu đã xác minh.'
                      : 'Không tìm thấy nguyên liệu phù hợp.',
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final food = visible[index];
                  final id = '${food['id']}';
                  final inFridge =
                      fridgeFoodIds.contains(id) ||
                      fridgeNames.contains(
                        '${food['name']}'.trim().toLowerCase(),
                      );
                  return Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: line),
                    ),
                    child: ListTile(
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FoodDetailPage(api: widget.api, food: food),
                        ),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEAF1E7),
                        child: ClipOval(
                          child: food['hasImage'] == true
                              ? Image.network(
                                  '${ApiConfig.baseUrl}/api/foods/${food['id']}/image',
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.eco_outlined,
                                    color: green,
                                  ),
                                )
                              : const Icon(Icons.eco_outlined, color: green),
                        ),
                      ),
                      title: Text('${food['name']}'),
                      subtitle: Text(
                        '4 ch\u1ec9 ti\u00eau \u0111\u1ea7u: n\u0103ng l\u01b0\u1ee3ng, \u0111\u1ea1m, carbohydrate, ch\u1ea5t b\u00e9o',
                      ),
                      trailing: inFridge
                          ? const Text(
                              'Đã có trong tủ',
                              style: TextStyle(
                                color: green,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : IconButton(
                              tooltip: 'Thêm vào Tủ lạnh',
                              onPressed: addingId == id
                                  ? null
                                  : () => addToFridge(food),
                              icon: addingId == id
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.add_circle_outline),
                            ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class FoodDetailPage extends StatefulWidget {
  const FoodDetailPage({super.key, required this.api, required this.food});
  final ApiClient api;
  final Map<String, dynamic> food;
  @override
  State<FoodDetailPage> createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage> {
  bool adding = false;

  Future<void> addToFridge() async {
    setState(() => adding = true);
    try {
      await widget.api.post('/api/me/fridge', {
        'name': widget.food['name'],
        'foodId': widget.food['id'],
      }, auth: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.food['name']} đã được thêm vào tủ lạnh.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = widget.food['nutrition'] as Map<String, dynamic>? ?? {};
    final nutritionFieldNames = _nutritionFields
        .map((field) => field.$1)
        .toSet();
    final sources = (widget.food['sources'] as List<dynamic>? ?? [])
        .where(
          (source) =>
              nutritionFieldNames.contains(source['fieldName']) ||
              source['fieldName'] == 'FoodInfo',
        )
        .toList();
    final available = _nutritionFields
        .where((field) => nutrition[_nutritionJsonKey(field.$1)] != null)
        .toList();
    Widget nutritionRow((String, String) field) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(child: Text(field.$2)),
          Text(
            '${nutrition[_nutritionJsonKey(field.$1)]}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết thực phẩm')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: widget.food['hasImage'] == true
                ? Image.network(
                    '${ApiConfig.baseUrl}/api/foods/${widget.food['id']}/image',
                    height: 155,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 155,
                      decoration: const BoxDecoration(color: Color(0xFFEAF3ED)),
                      child: const Center(
                        child: Icon(Icons.eco_outlined, size: 64, color: green),
                      ),
                    ),
                  )
                : Container(
                    height: 155,
                    decoration: const BoxDecoration(color: Color(0xFFEAF3ED)),
                    child: const Center(
                      child: Icon(Icons.eco_outlined, size: 64, color: green),
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          Text(
            '${widget.food['name']}',
            style: const TextStyle(
              fontSize: 26,
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thực phẩm chưa chế biến',
            style: TextStyle(color: Color(0xFF6B7770)),
          ),
          const SizedBox(height: 18),
          if (available.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Chưa có dữ liệu dinh dưỡng được xác minh cho thực phẩm này.',
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dữ liệu dinh dưỡng',
                      style: TextStyle(
                        fontSize: 17,
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Giá trị dinh dưỡng áp dụng cho ${widget.food['basis'] ?? '100 g phần ăn được'}.',
                      style: const TextStyle(
                        color: Color(0xFF6B7770),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '1. Nhóm 8 chỉ tiêu chính',
                      style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                    ...available.take(8).map(nutritionRow),
                    if (available.length > 8) ...[
                      const Divider(),
                      const Text(
                        '2. Nhóm 4 chỉ tiêu bổ sung',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      ...available.skip(8).map(nutritionRow),
                    ],
                  ],
                ),
              ),
            ),
          if (sources.isNotEmpty)
            Card(
              child: ExpansionTile(
                title: const Text('Nguồn tham khảo'),
                children: sources.map((raw) {
                  final source = raw as Map<String, dynamic>;
                  final citation = '${source['citation'] ?? ''}'.trim();
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      source['isChecked'] == true
                          ? Icons.verified_outlined
                          : Icons.info_outline,
                      color: green,
                    ),
                    title: Text(
                      source['fieldName'] == 'FoodInfo'
                          ? 'Nguồn chung của thực phẩm'
                          : '${source['fieldName'] ?? 'Nguồn'}',
                    ),
                    subtitle: Text(
                      citation.isNotEmpty ? citation : '${source['url'] ?? ''}',
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: adding ? null : addToFridge,
            icon: const Icon(Icons.add),
            label: Text(adding ? 'Đang thêm…' : 'Thêm vào tủ lạnh'),
          ),
        ],
      ),
    );
  }
}

class GoalDashboardPage extends StatefulWidget {
  const GoalDashboardPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<GoalDashboardPage> createState() => _GoalDashboardPageState();
}

class _GoalDashboardPageState extends State<GoalDashboardPage> {
  Map<String, dynamic> profile = {};
  Map<String, dynamic> currentGoal = {};
  List<Map<String, dynamic>> todayMeals = [];
  final Set<String> cancellingMeals = {};
  final Set<String> cancellingExtraMeals = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final loadedProfile = await widget.api.get('/api/me/profile', auth: true);
      Map<String, dynamic> loadedGoal = {};
      List<Map<String, dynamic>> loadedMeals = [];
      try {
        loadedGoal = await widget.api.get('/api/me/goals/current', auth: true);
      } catch (_) {}
      final now = DateTime.now();
      final day =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      try {
        final response = await widget.api.get(
          '/api/me/meals/log?date=$day',
          auth: true,
        );
        loadedMeals = ((response['data'] as List<dynamic>?) ?? [])
            .cast<Map<String, dynamic>>();
      } catch (_) {}
      profile = loadedProfile;
      currentGoal = loadedGoal;
      todayMeals = loadedMeals;
      error = null;
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  double? _number(Object? value) => double.tryParse('$value');

  String _weight(Object? value) {
    final number = _number(value);
    return number == null ? '—' : '${number.toStringAsFixed(1)} kg';
  }

  double? _energy(Object? values) {
    if (values is! Map) return null;
    final value = values['energy_kcal'] ?? values['energyKcal'];
    return value is num ? value.toDouble() : double.tryParse('$value');
  }

  double? get _todayEnergy {
    if (todayMeals.isEmpty) return 0;
    var total = 0.0;
    var hasEnergy = false;
    for (final meal in todayMeals) {
      final value = _energy(meal['estimatedNutrients']);
      if (value != null) {
        total += value;
        hasEnergy = true;
      }
    }
    return hasEnergy ? total : null;
  }

  double? get _targetEnergy {
    final dailyTarget = _number(currentGoal['dailyCalorieTarget']);
    if (dailyTarget != null && dailyTarget > 0) return dailyTarget;

    final allocations = currentGoal['mealAllocations'];
    if (allocations is! List || allocations.isEmpty) return null;
    var total = 0.0;
    for (final allocation in allocations) {
      if (allocation is! Map) return null;
      final value = _mealEnergyTarget(allocation);
      if (value == null) return null;
      total += value;
    }
    return total;
  }

  double? _mealEnergyTarget(Map<dynamic, dynamic>? allocation) {
    final targets = allocation?['targets'];
    if (targets is! Map) return null;
    final energy = targets['energy_kcal'] ?? targets['energyKcal'];
    if (energy is num) return energy.toDouble();
    if (energy is Map) {
      final minimum = _number(energy['minimum']);
      final maximum = _number(energy['maximum']);
      if (minimum != null && maximum != null) return (minimum + maximum) / 2;
      return _number(energy['target']);
    }
    return _number(energy);
  }

  Future<void> editGoal() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => GoalPage(api: widget.api),
      ),
    );
    if (!mounted) return;
    await load();
    if (result != null && mounted) {
      final appliesToday = result['appliesToday'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appliesToday
                ? 'Mục tiêu mới áp dụng hôm nay cho các bữa còn lại.'
                : 'Đã ghi đủ bữa hôm nay; mục tiêu mới bắt đầu từ ngày mai.',
          ),
        ),
      );
    }
  }

  Future<void> cancelLoggedMeal(Map<String, dynamic> meal) async {
    final suggestionId = '${meal['mealSuggestionId'] ?? ''}';
    if (suggestionId.isEmpty || cancellingMeals.contains(suggestionId)) return;
    setState(() => cancellingMeals.add(suggestionId));
    try {
      await widget.api.delete(
        '/api/me/meals/$suggestionId/confirm',
        auth: true,
      );
      if (!mounted) return;
      setState(() {
        todayMeals.removeWhere(
          (item) => '${item['mealSuggestionId'] ?? ''}' == suggestionId,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã hủy lưu bữa ${meal['mealName']}')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không hủy được bữa ăn: $e')));
      }
    } finally {
      if (mounted) setState(() => cancellingMeals.remove(suggestionId));
    }
  }

  Future<void> openMeal(String mealName) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MealGenerationPage(
          api: widget.api,
          goalId: '${currentGoal['id'] ?? ''}',
          mealName: mealName,
          mealNames: ((currentGoal['mealAllocations'] as List<dynamic>?) ?? [])
              .map((meal) => '${meal['mealName']}')
              .toList(),
          mealDate: DateTime.now(),
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> openExtraMeal([Map<String, dynamic>? meal]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ExtraMealEditorPage(api: widget.api, meal: meal),
      ),
    );
    if (saved == true && mounted) await load();
  }

  Future<void> cancelExtraMeal(Map<String, dynamic> meal) async {
    final suggestionId = '${meal['mealSuggestionId'] ?? ''}';
    if (suggestionId.isEmpty || cancellingExtraMeals.contains(suggestionId)) {
      return;
    }
    setState(() => cancellingExtraMeals.add(suggestionId));
    try {
      await widget.api.delete(
        '/api/me/meals/$suggestionId/confirm',
        auth: true,
      );
      if (!mounted) return;
      setState(() {
        todayMeals.removeWhere(
          (item) => '${item['mealSuggestionId'] ?? ''}' == suggestionId,
        );
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã hủy bữa ăn thêm.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không hủy được bữa ăn: $e')));
      }
    } finally {
      if (mounted) setState(() => cancellingExtraMeals.remove(suggestionId));
    }
  }

  Future<void> openReport() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => GoalReportPage(api: widget.api)),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final currentWeight = _number(profile['weightKg']);
    final targetWeight = _number(
      currentGoal['targetWeightKg'] ?? profile['targetWeightKg'],
    );
    final bmi = GoalMetrics.bmi(
      weightKg: currentWeight,
      heightCm: _number(profile['heightCm']),
    );
    final remaining = currentWeight == null || targetWeight == null
        ? null
        : (currentWeight - targetWeight).abs();
    final goalName =
        '${currentGoal['goal'] ?? profile['goal'] ?? 'Chưa thiết lập'}';
    final todayEnergy = _todayEnergy;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const Text(
              'avora',
              style: TextStyle(
                color: green,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFE88F55),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Text(
                'Mục tiêu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cập nhật',
            onPressed: load,
            icon: const Icon(Icons.bar_chart),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: green))
          : error != null
          ? Center(
              child: TextButton.icon(
                onPressed: load,
                icon: const Icon(Icons.refresh),
                label: Text('Thử lại · $error'),
              ),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _goalSummaryCard(
                    goalName: goalName,
                    currentWeight: currentWeight,
                    targetWeight: targetWeight,
                    remaining: remaining,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _metricCard(
                          'BMI từ hồ sơ',
                          bmi == null ? '—' : bmi.toStringAsFixed(1),
                          'kg/m²',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _metricCard(
                          'Năng lượng hôm nay',
                          todayEnergy == null
                              ? '—'
                              : todayEnergy.toStringAsFixed(0),
                          'kcal đã ghi nhận hôm nay',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _energyCard(),
                  const SizedBox(height: 12),
                  _mealsCard(),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: openReport,
                      icon: const Icon(Icons.bar_chart_rounded),
                      label: const Text('Xem báo cáo tuần / tháng'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E6248),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _goalSummaryCard({
    required String goalName,
    required double? currentWeight,
    required double? targetWeight,
    required double? remaining,
  }) {
    final active = currentGoal.isNotEmpty;
    final durationDays = int.tryParse('${currentGoal['durationDays'] ?? ''}');
    final durationMonths = durationDays == null
        ? null
        : (durationDays / 30).round();
    final pendingValue = currentGoal['pendingGoal'];
    final pendingGoal = pendingValue is Map
        ? Map<String, dynamic>.from(pendingValue)
        : null;
    final pendingDurationDays = int.tryParse(
      '${pendingGoal?['durationDays'] ?? ''}',
    );
    final pendingDurationLabel = pendingDurationDays == null
        ? ''
        : '${(pendingDurationDays / 30).round()} tháng';
    final pendingStartDate = pendingGoal?['effectiveStartDate'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF195F46),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF1E4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  active ? 'Đang thực hiện' : 'Chưa thiết lập',
                  style: TextStyle(
                    color: Color(0xFF195F46),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              IconButton.filledTonal(
                tooltip: 'Chỉnh sửa mục tiêu',
                onPressed: editGoal,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          Text(
            goalName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _goalWeightColumn('Hiện tại', _weight(currentWeight)),
              _goalWeightColumn(
                remaining == null
                    ? 'Còn lại'
                    : 'Còn ${remaining.toStringAsFixed(1)} kg',
                '→',
              ),
              _goalWeightColumn('Mục tiêu', _weight(targetWeight)),
            ],
          ),
          if (durationMonths != null) ...[
            const SizedBox(height: 10),
            Text(
              'Thời hạn: $durationMonths tháng',
              style: const TextStyle(color: Color(0xFFDCEBE2), fontSize: 12),
            ),
          ],
          if (pendingGoal != null) ...[
            const SizedBox(height: 6),
            Text(
              'Mục tiêu tiếp theo bắt đầu $pendingStartDate · $pendingDurationLabel',
              style: const TextStyle(color: Color(0xFFFFE2AD), fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            active
                ? currentGoal['targetStatus'] == 'Ready'
                      ? 'Mục tiêu dinh dưỡng cho các bữa đã sẵn sàng.'
                      : 'Mục tiêu đã lưu; món AI sẽ dùng khẩu phần chuẩn của công thức.'
                : 'Thiết lập mục tiêu để bắt đầu theo dõi.',
            style: const TextStyle(color: Color(0xFFDCEBE2), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _goalWeightColumn(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFFDCEBE2), fontSize: 11),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _metricCard(String title, String value, String unit) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.black54, fontSize: 11),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: green,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(unit, style: const TextStyle(color: Colors.black54, fontSize: 10)),
      ],
    ),
  );

  Widget _sectionCard({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );

  Widget _energyCard() {
    final consumed = _todayEnergy;
    final target = _targetEnergy;
    final excess = consumed != null && target != null && consumed > target
        ? consumed - target
        : null;
    final progress = consumed == null || target == null || target <= 0
        ? 0.0
        : (consumed / target).clamp(0.0, 1.0).toDouble();
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NĂNG LƯỢNG HÔM NAY',
            style: TextStyle(
              color: green,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Từ các bữa ăn đã xác nhận',
            style: TextStyle(
              color: ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor: const Color(0xFFEDEBE4),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          excess == null
                              ? const Color(0xFFE98643)
                              : const Color(0xFFC8433B),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          consumed == null ? '—' : consumed.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: excess == null
                                ? ink
                                : const Color(0xFFC8433B),
                          ),
                        ),
                        const Text(
                          'kcal',
                          style: TextStyle(fontSize: 10, color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Đã ghi nhận hôm nay',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    Text(
                      consumed == null
                          ? 'Chưa có dữ liệu năng lượng'
                          : '${consumed.toStringAsFixed(0)} kcal',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Divider(height: 18),
                    const Text(
                      'Mục tiêu trong ngày',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    Text(
                      target == null
                          ? 'Chưa thiết lập'
                          : '${target.toStringAsFixed(0)} kcal',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (excess != null) ...[
            const SizedBox(height: 10),
            Text(
              'Đã vượt mục tiêu ${excess.toStringAsFixed(0)} kcal',
              style: const TextStyle(
                color: Color(0xFFC8433B),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
          if (target == null) ...[
            const SizedBox(height: 10),
            const Text(
              'Chưa có chỉ tiêu năng lượng cho các bữa trong mục tiêu hiện tại.',
              style: TextStyle(color: Colors.black54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mealsCard() {
    final allocations = (currentGoal['mealAllocations'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final mealNames = allocations.isNotEmpty
        ? allocations.map((meal) => '${meal['mealName']}').toList()
        : todayMeals
              .where((meal) => meal['isExtraMeal'] != true)
              .map((meal) => '${meal['mealName']}')
              .toSet()
              .toList();
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bữa ăn hôm nay',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const Divider(height: 20),
          if (mealNames.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Chưa có bữa ăn nào được xác nhận hôm nay.',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          ...mealNames.map((mealName) {
            Map<String, dynamic>? allocation;
            for (final candidate in allocations) {
              if (candidate['mealName'] == mealName) {
                allocation = candidate;
                break;
              }
            }
            final mealTarget = _mealEnergyTarget(allocation);
            final logged = todayMeals
                .where((meal) => meal['mealName'] == mealName)
                .toList();
            final actual = logged.isEmpty ? null : logged.first;
            final dishName = actual?['dishName']?.toString();
            final energy = _energy(actual?['estimatedNutrients']);
            final subtitle = actual == null
                ? 'Chưa ghi nhận'
                : '${dishName ?? 'Đã ghi nhận'}${energy == null ? '' : ' · ${energy.toStringAsFixed(0)} kcal'}';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: actual == null
                    ? const Color(0xFFF3F2ED)
                    : const Color(0xFFE8F2EB),
                child: Icon(
                  actual == null ? Icons.restaurant : Icons.check,
                  color: actual == null ? Colors.black45 : green,
                  size: 18,
                ),
              ),
              title: Text(
                mealName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtitle, style: const TextStyle(fontSize: 11)),
                  if (mealTarget != null)
                    Text(
                      '~${mealTarget.toStringAsFixed(0)} kcal mục tiêu',
                      style: const TextStyle(fontSize: 10, color: green),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (actual != null) ...[
                    if (cancellingMeals.contains(
                      '${actual['mealSuggestionId'] ?? ''}',
                    ))
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Tooltip(
                        message: 'Hủy lưu bữa',
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFB8453D),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(52, 36),
                          ),
                          onPressed: () => cancelLoggedMeal(actual),
                          icon: const Icon(Icons.undo, size: 18),
                          label: const Text('Hủy'),
                        ),
                      ),
                  ] else
                    const Icon(
                      Icons.restaurant,
                      color: Colors.black45,
                      size: 19,
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.black45),
                ],
              ),
              onTap: () => openMeal(mealName),
            );
          }),
          ...todayMeals
              .where((meal) => meal['isExtraMeal'] == true)
              .map(_extraMealTile),
          const SizedBox(height: 8),
          _DashedAddMealButton(onTap: () => openExtraMeal()),
          if (allocations.isEmpty &&
              todayMeals.isEmpty &&
              profile['mealsPerDay'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton.icon(
                onPressed: editGoal,
                icon: const Icon(Icons.track_changes_outlined),
                label: const Text('Thiết lập mục tiêu và lịch bữa ăn'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _extraMealTile(Map<String, dynamic> meal) {
    final suggestionId = '${meal['mealSuggestionId'] ?? ''}';
    final energy = _energy(meal['estimatedNutrients']);
    final isCancelling = cancellingExtraMeals.contains(suggestionId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFEAF3ED),
        child: Icon(Icons.add, color: green, size: 20),
      ),
      title: const Text(
        'Bữa phụ ngoài',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      subtitle: Text(
        energy == null
            ? 'Chưa có dữ liệu kcal'
            : '${energy.toStringAsFixed(0)} kcal',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Sửa bữa ăn',
            onPressed: () => openExtraMeal(meal),
            icon: const Icon(Icons.edit_outlined, size: 19),
          ),
          isCancelling
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  tooltip: 'Hủy lưu bữa',
                  onPressed: () => cancelExtraMeal(meal),
                  icon: const Icon(
                    Icons.undo,
                    color: Color(0xFFB8453D),
                    size: 20,
                  ),
                ),
        ],
      ),
      onTap: () => openExtraMeal(meal),
    );
  }
}

class GoalPage extends StatefulWidget {
  const GoalPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<GoalPage> createState() => _GoalPageState();
}

class _DashedAddMealButton extends StatelessWidget {
  const _DashedAddMealButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(15);
    return CustomPaint(
      foregroundPainter: _DashedRoundedBorderPainter(
        color: const Color(0xFF76A78D),
      ),
      child: Material(
        color: const Color(0xFFEAF3ED),
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, color: green, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Thêm bữa ăn / bữa phụ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: green,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(15)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 7, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}

class ExtraMealEditorPage extends StatefulWidget {
  const ExtraMealEditorPage({super.key, required this.api, this.meal});
  final ApiClient api;
  final Map<String, dynamic>? meal;

  @override
  State<ExtraMealEditorPage> createState() => _ExtraMealEditorPageState();
}

class _ExtraMealEditorPageState extends State<ExtraMealEditorPage> {
  final calories = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final nutrients = widget.meal?['estimatedNutrients'];
    final value = nutrients is Map
        ? nutrients['energy_kcal'] ?? nutrients['energyKcal']
        : widget.meal?['caloriesKcal'];
    if (value != null) calories.text = '$value';
  }

  @override
  void dispose() {
    calories.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final amount = double.tryParse(calories.text.trim().replaceAll(',', '.'));
    if (amount == null || amount < 1 || amount > 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập lượng calo từ 1 đến 10000 kcal.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final body = {'caloriesKcal': amount};
      final existing = widget.meal;
      if (existing == null) {
        await widget.api.post('/api/me/extra-meals', body, auth: true);
      } else {
        await widget.api.put(
          '/api/me/extra-meals/${existing['mealSuggestionId']}',
          body,
          auth: true,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.meal == null ? 'Thêm bữa phụ' : 'Sửa bữa phụ'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        const Text(
          'Nếu bạn ăn bên ngoài hoặc ăn thêm, nhập tổng kcal để cộng vào lượng đã ăn hôm nay.',
          style: TextStyle(color: Color(0xFF66746B), height: 1.45),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: calories,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Năng lượng',
            suffixText: 'kcal',
            helperText: 'Nhập từ 1 đến 10000 kcal',
          ),
          onSubmitted: (_) => saving ? null : save(),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add),
          label: Text(
            saving
                ? 'Đang lưu…'
                : widget.meal == null
                ? 'Cộng kcal hôm nay'
                : 'Cập nhật kcal',
          ),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ],
    ),
  );
}

enum _ReportPeriod { week, month }

class _ReportDay {
  _ReportDay(this.date);
  final DateTime date;
  double calories = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;
  int mealCount = 0;
  int macroMealCount = 0;
  bool hasCalorieOnlyMeal = false;
}

class _WeightSample {
  const _WeightSample(this.date, this.kg);
  final DateTime date;
  final double kg;
}

class GoalReportPage extends StatefulWidget {
  const GoalReportPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<GoalReportPage> createState() => _GoalReportPageState();
}

class _GoalReportPageState extends State<GoalReportPage> {
  _ReportPeriod period = _ReportPeriod.week;
  bool loading = true;
  String? error;
  List<_ReportDay> days = [];
  List<_WeightSample> allWeights = [];
  Map<String, dynamic> goal = {};
  Map<String, dynamic> profile = {};

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int get _dayCount => period == _ReportPeriod.week ? 7 : 30;
  DateTime get _startDate => _today.subtract(Duration(days: _dayCount - 1));

  double? _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final fromDate = _isoDate(_startDate);
      final toDate = _isoDate(_today);
      final results = await Future.wait([
        widget.api.get(
          '/api/me/meals/log?fromDate=$fromDate&toDate=$toDate',
          auth: true,
        ),
        widget.api.get('/api/me/weight-history', auth: true),
        widget.api.get('/api/me/profile', auth: true),
      ]);
      Map<String, dynamic> loadedGoal = {};
      try {
        loadedGoal = await widget.api.get('/api/me/goals/current', auth: true);
      } catch (_) {}
      final daily = <String, _ReportDay>{};
      for (var offset = 0; offset < _dayCount; offset++) {
        final date = _startDate.add(Duration(days: offset));
        daily[_isoDate(date)] = _ReportDay(date);
      }
      final logs = (results[0]['data'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      for (final meal in logs) {
        final dateValue = meal['mealDate']?.toString();
        if (dateValue == null) continue;
        final day = daily[dateValue];
        if (day == null) continue;
        final nutrients = meal['estimatedNutrients'];
        if (nutrients is! Map) continue;
        final energy = _number(
          nutrients['energy_kcal'] ?? nutrients['energyKcal'],
        );
        final protein = _number(
          nutrients['protein_g'] ?? nutrients['proteinG'],
        );
        final carbs = _number(
          nutrients['carbohydrate_g'] ?? nutrients['carbohydrateG'],
        );
        final fat = _number(
          nutrients['total_fat_g'] ??
              nutrients['totalFatG'] ??
              nutrients['fatG'],
        );
        if (energy != null) day.calories += energy;
        if (meal['isCalorieOnly'] == true) {
          day.hasCalorieOnlyMeal = true;
        } else {
          if (protein != null) day.protein += protein;
          if (carbs != null) day.carbs += carbs;
          if (fat != null) day.fat += fat;
          if (protein != null || carbs != null || fat != null) {
            day.macroMealCount++;
          }
        }
        day.mealCount++;
      }
      final weightRows = ((results[1]['data'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>();
      final loadedWeights =
          weightRows
              .map((row) {
                final date = DateTime.tryParse('${row['recordedOn'] ?? ''}');
                final kg = _number(row['weightKg']);
                if (date == null || kg == null) return null;
                return _WeightSample(
                  DateTime(date.year, date.month, date.day),
                  kg,
                );
              })
              .whereType<_WeightSample>()
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      days = daily.values.toList();
      allWeights = loadedWeights;
      profile = results[2];
      goal = loadedGoal;
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  double? get _dailyTarget => _number(goal['dailyCalorieTarget']);
  double? get _targetWeight =>
      _number(goal['targetWeightKg'] ?? profile['targetWeightKg']);
  _WeightSample? get _latestWeight =>
      allWeights.isEmpty ? null : allWeights.last;
  List<_WeightSample> get _visibleWeights => allWeights
      .where(
        (point) =>
            !point.date.isBefore(_startDate) && !point.date.isAfter(_today),
      )
      .toList();

  double? get _goalProgress {
    final target = _targetWeight;
    final current = _latestWeight?.kg;
    if (target == null || current == null || allWeights.isEmpty) return null;
    final initial = allWeights.first.kg;
    final totalDistance = (target - initial).abs();
    if (totalDistance < .1) return (target - current).abs() <= .5 ? 1 : 0;
    final name = '${goal['goal'] ?? profile['goal'] ?? ''}';
    final traveled = name == 'Giảm cân'
        ? initial - current
        : name == 'Tăng cân'
        ? current - initial
        : totalDistance - (target - current).abs();
    return (traveled / totalDistance).clamp(0, 1);
  }

  Future<void> addWeight() async {
    final controller = TextEditingController(
      text: '${_latestWeight?.kg ?? profile['weightKg'] ?? ''}',
    );
    var recordedOn = _today;
    final input = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ghi cân nặng thực tế'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Cân nặng',
                  suffixText: 'kg',
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () async {
                  final selected = await showDatePicker(
                    context: dialogContext,
                    initialDate: recordedOn,
                    firstDate: DateTime(_today.year - 5),
                    lastDate: _today,
                  );
                  if (selected != null) {
                    setDialogState(() {
                      recordedOn = DateTime(
                        selected.year,
                        selected.month,
                        selected.day,
                      );
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  '${recordedOn.day}/${recordedOn.month}/${recordedOn.year}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final kg = double.tryParse(
                  controller.text.trim().replaceAll(',', '.'),
                );
                if (kg == null || kg < 15 || kg > 500) return;
                Navigator.pop(dialogContext, {
                  'weightKg': kg,
                  'recordedOn': _isoDate(recordedOn),
                });
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (input == null || !mounted) return;
    try {
      await widget.api.post('/api/me/weight-history', input, auth: true);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu cân nặng thực tế.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _reportCard({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: line),
    ),
    child: child,
  );

  Widget _legend(Color color, String text, {bool lineMark = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: lineMark ? 18 : 10,
        height: lineMark ? 3 : 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 11)),
    ],
  );

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    final chartWidth = math.max(
      MediaQuery.sizeOf(context).width - 48,
      days.length * 38.0,
    );
    final actualCalories = days.fold<double>(
      0,
      (sum, day) => sum + day.calories,
    );
    final calorieDays = days.where((day) => day.mealCount > 0).length;
    final averageCalories = calorieDays == 0
        ? 0.0
        : actualCalories / calorieDays;
    final progress = _goalProgress;
    final latestWeight = _latestWeight;
    final targetWeight = _targetWeight;
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo thống kê')),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: green))
          : error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(error!, textAlign: TextAlign.center),
                  ),
                  TextButton(onPressed: load, child: const Text('Thử lại')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  SegmentedButton<_ReportPeriod>(
                    segments: const [
                      ButtonSegment(
                        value: _ReportPeriod.week,
                        label: Text('Tuần · 7 ngày'),
                      ),
                      ButtonSegment(
                        value: _ReportPeriod.month,
                        label: Text('Tháng · 30 ngày'),
                      ),
                    ],
                    selected: {period},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty || selection.first == period) {
                        return;
                      }
                      setState(() => period = selection.first);
                      load();
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Số liệu từ ${_isoDate(_startDate)} đến ${_isoDate(_today)}',
                    style: const TextStyle(
                      color: Color(0xFF66746B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ReportSummaryTile(
                        label: 'Tổng kcal',
                        value: actualCalories.toStringAsFixed(0),
                        detail: 'đã xác nhận',
                      ),
                      _ReportSummaryTile(
                        label: 'Trung bình',
                        value: averageCalories.toStringAsFixed(0),
                        detail: 'kcal/ngày có bữa',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _reportCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Calo tiêu thụ theo ngày',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 14,
                          children: [
                            _legend(green, 'Đã ăn'),
                            if (_dailyTarget != null)
                              _legend(const Color(0xFFC8D5CD), 'Mục tiêu'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (calorieDays == 0)
                          const Text(
                            'Chưa có bữa ăn đã xác nhận trong khoảng thời gian này.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartWidth.toDouble(),
                            height: 205,
                            child: CustomPaint(
                              painter: _CaloriesChartPainter(
                                days: days,
                                target: _dailyTarget,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _reportCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dinh dưỡng mỗi ngày',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _legend(
                              const Color(0xFF236B4E),
                              'Protein',
                              lineMark: true,
                            ),
                            _legend(
                              const Color(0xFFE89A37),
                              'Carb',
                              lineMark: true,
                            ),
                            _legend(
                              const Color(0xFF6685C5),
                              'Fat',
                              lineMark: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (days.any((day) => day.macroMealCount > 0))
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: chartWidth.toDouble(),
                              height: 190,
                              child: CustomPaint(
                                painter: _MacroChartPainter(days),
                              ),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                              'Chưa có dữ liệu Protein, Carb, Fat trong khoảng thời gian này.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          days.any((day) => day.hasCalorieOnlyMeal)
                              ? 'Bữa phụ chỉ nhập kcal được cộng vào biểu đồ calo; chưa có dữ liệu để tính Protein, Carb và Fat.'
                              : 'Gram dinh dưỡng được tính từ các bữa đã xác nhận.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF66746B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _reportCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cân nặng và tiến độ mục tiêu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          latestWeight == null
                              ? 'Chưa có cân nặng thực tế.'
                              : 'Gần nhất: ${latestWeight.kg.toStringAsFixed(1)} kg · '
                                    '${latestWeight.date.day}/${latestWeight.date.month}',
                          style: const TextStyle(
                            color: Color(0xFF66746B),
                            fontSize: 12,
                          ),
                        ),
                        if (targetWeight != null)
                          Text(
                            'Mục tiêu: ${targetWeight.toStringAsFixed(1)} kg'
                            '${progress == null ? '' : ' · Đạt ${(progress * 100).round()}%'}',
                            style: const TextStyle(
                              color: green,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 14,
                          children: [
                            _legend(
                              const Color(0xFF236B4E),
                              'Cân nặng',
                              lineMark: true,
                            ),
                            if (targetWeight != null)
                              _legend(
                                const Color(0xFFE89A37),
                                'Mục tiêu',
                                lineMark: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_visibleWeights.isEmpty)
                          const Text(
                            'Chưa có lịch sử cân trong khoảng này. Hãy ghi cân nặng để theo dõi tiến độ.',
                            style: TextStyle(color: Colors.black54),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: math
                                  .max(
                                    MediaQuery.sizeOf(context).width - 48,
                                    _visibleWeights.length * 42.0,
                                  )
                                  .toDouble(),
                              height: 190,
                              child: CustomPaint(
                                painter: _WeightChartPainter(
                                  _visibleWeights,
                                  targetWeight,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: addWeight,
                          icon: const Icon(Icons.monitor_weight_outlined),
                          label: const Text('Ghi cân nặng thực tế'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ReportSummaryTile extends StatelessWidget {
  const _ReportSummaryTile({
    required this.label,
    required this.value,
    required this.detail,
  });
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    width: (MediaQuery.sizeOf(context).width - 42) / 2,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF3ED),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: green)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        Text(
          detail,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
      ],
    ),
  );
}

void _paintChartText(
  Canvas canvas,
  String text,
  Offset position, {
  double size = 9,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: size, color: const Color(0xFF748078)),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  painter.paint(canvas, position);
}

class _CaloriesChartPainter extends CustomPainter {
  _CaloriesChartPainter({required this.days, required this.target});
  final List<_ReportDay> days;
  final double? target;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const left = 36.0, right = 5.0, top = 10.0, bottom = 30.0;
    final chartHeight = size.height - top - bottom;
    final chartWidth = size.width - left - right;
    final maxValue = math.max(
      500.0,
      math.max(
            target ?? 0,
            days.fold<double>(0, (m, d) => math.max(m, d.calories)),
          ) *
          1.12,
    );
    final gridPaint = Paint()
      ..color = const Color(0xFFE7ECE8)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
      _paintChartText(
        canvas,
        (maxValue * (4 - i) / 4).round().toString(),
        Offset(0, y - 6),
        size: 8,
      );
    }
    final groupWidth = chartWidth / days.length;
    final barWidth = math.min(10.0, groupWidth * .28);
    for (var i = 0; i < days.length; i++) {
      final x = left + groupWidth * (i + .5);
      final day = days[i];
      void bar(double value, double centerX, Color color) {
        if (value <= 0) return;
        final height = chartHeight * value / maxValue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              centerX - barWidth / 2,
              top + chartHeight - height,
              barWidth,
              height,
            ),
            const Radius.circular(3),
          ),
          Paint()..color = color,
        );
      }

      if (target != null)
        bar(target!, x - barWidth * .65, const Color(0xFFC8D5CD));
      bar(day.calories, target == null ? x : x + barWidth * .65, green);
      if (days.length <= 7 || i % 5 == 0 || i == days.length - 1) {
        final label = '${day.date.day}/${day.date.month}';
        _paintChartText(
          canvas,
          label,
          Offset(x - 10, top + chartHeight + 7),
          size: 8,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CaloriesChartPainter oldDelegate) =>
      oldDelegate.days != days || oldDelegate.target != target;
}

class _MacroChartPainter extends CustomPainter {
  _MacroChartPainter(this.days);
  final List<_ReportDay> days;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const left = 10.0, right = 8.0, top = 12.0, bottom = 28.0;
    final chartHeight = size.height - top - bottom;
    final chartWidth = size.width - left - right;
    final maxValue = math.max(
      10.0,
      days.fold<double>(
            0,
            (m, d) =>
                math.max(m, math.max(d.protein, math.max(d.carbs, d.fat))),
          ) *
          1.12,
    );
    final gridPaint = Paint()
      ..color = const Color(0xFFE7ECE8)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = top + chartHeight * i / 3;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }
    final groupWidth = chartWidth / days.length;
    final series = [
      (const Color(0xFF236B4E), (day) => day.protein),
      (const Color(0xFFE89A37), (day) => day.carbs),
      (const Color(0xFF6685C5), (day) => day.fat),
    ];
    for (final (color, valueFor) in series) {
      final points = <Offset>[];
      for (var i = 0; i < days.length; i++) {
        final x = left + groupWidth * (i + .5);
        final y = top + chartHeight * (1 - valueFor(days[i]) / maxValue);
        points.add(Offset(x, y));
      }
      if (points.length > 1) {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      for (final point in points) {
        canvas.drawCircle(point, 3, Paint()..color = color);
      }
    }
    for (var i = 0; i < days.length; i++) {
      if (days.length <= 7 || i % 5 == 0 || i == days.length - 1) {
        final x = left + groupWidth * (i + .5);
        _paintChartText(
          canvas,
          '${days[i].date.day}/${days[i].date.month}',
          Offset(x - 10, top + chartHeight + 7),
          size: 8,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MacroChartPainter oldDelegate) =>
      oldDelegate.days != days;
}

class _WeightChartPainter extends CustomPainter {
  _WeightChartPainter(this.points, this.target);
  final List<_WeightSample> points;
  final double? target;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const left = 10.0, right = 10.0, top = 16.0, bottom = 28.0;
    final chartHeight = size.height - top - bottom;
    final chartWidth = size.width - left - right;
    var minValue = points.map((point) => point.kg).reduce(math.min);
    var maxValue = points.map((point) => point.kg).reduce(math.max);
    if (target != null) {
      minValue = math.min(minValue, target!);
      maxValue = math.max(maxValue, target!);
    }
    if (maxValue - minValue < 1) {
      minValue -= 1;
      maxValue += 1;
    } else {
      final margin = (maxValue - minValue) * .12;
      minValue -= margin;
      maxValue += margin;
    }
    double yFor(double value) =>
        top + chartHeight * (1 - (value - minValue) / (maxValue - minValue));
    final gridPaint = Paint()
      ..color = const Color(0xFFE7ECE8)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = top + chartHeight * i / 3;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }
    if (target != null) {
      final y = yFor(target!);
      final paint = Paint()
        ..color = const Color(0xFFE89A37)
        ..strokeWidth = 1.5;
      var x = left;
      while (x < size.width - right) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 6, size.width - right), y),
          paint,
        );
        x += 10;
      }
    }
    final firstDay = points.first.date;
    final span = points.last.date.difference(firstDay).inDays;
    final coords = points.map((point) {
      final x = span == 0
          ? left + chartWidth / 2
          : left + chartWidth * point.date.difference(firstDay).inDays / span;
      return Offset(x, yFor(point.kg));
    }).toList();
    if (coords.length > 1) {
      final path = Path()..moveTo(coords.first.dx, coords.first.dy);
      for (final point in coords.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
    for (var i = 0; i < coords.length; i++) {
      canvas.drawCircle(coords[i], 4, Paint()..color = green);
      _paintChartText(
        canvas,
        points[i].kg.toStringAsFixed(1),
        Offset(coords[i].dx - 12, coords[i].dy - 17),
        size: 8,
      );
      _paintChartText(
        canvas,
        '${points[i].date.day}/${points[i].date.month}',
        Offset(coords[i].dx - 10, top + chartHeight + 7),
        size: 8,
      );
    }
  }

  @override
  bool shouldRepaint(_WeightChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.target != target;
}

class _GoalPageState extends State<GoalPage> {
  final target = TextEditingController();
  Map<String, dynamic> profile = {};
  String goal = 'Giữ cân';
  int durationMonths = 3;
  int mealsPerDay = 4;
  String? error;
  bool loading = true, saving = false;
  bool showTargetValidation = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    target.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      profile = await widget.api.get('/api/me/profile', auth: true);
      final profileMeals = int.tryParse('${profile['mealsPerDay'] ?? ''}');
      if (profileMeals != null && [3, 4, 5].contains(profileMeals)) {
        mealsPerDay = profileMeals;
      }
      final savedGoal = profile['goal'];
      if (['Giữ cân', 'Giảm cân', 'Tăng cân'].contains(savedGoal)) {
        goal = '$savedGoal';
      }
      target.text = '${profile['targetWeightKg'] ?? ''}';
      try {
        final currentGoal = await widget.api.get(
          '/api/me/goals/current',
          auth: true,
        );
        final pendingValue = currentGoal['pendingGoal'];
        final goalSettings = pendingValue is Map
            ? Map<String, dynamic>.from(pendingValue)
            : currentGoal;
        final configuredGoal = goalSettings['goal'];
        if (['Giữ cân', 'Giảm cân', 'Tăng cân'].contains(configuredGoal)) {
          goal = '$configuredGoal';
        }
        final configuredMeals = int.tryParse(
          '${goalSettings['mealsPerDay'] ?? ''}',
        );
        if (configuredMeals != null && [3, 4, 5].contains(configuredMeals)) {
          mealsPerDay = configuredMeals;
        }
        target.text =
            '${goalSettings['targetWeightKg'] ?? profile['targetWeightKg'] ?? ''}';
        final durationDays = int.tryParse(
          '${goalSettings['durationDays'] ?? ''}',
        );
        if (durationDays != null) {
          durationMonths = (durationDays / 30).round().clamp(1, 24).toInt();
        }
      } catch (_) {}
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  double? get _weight => double.tryParse('${profile['weightKg'] ?? ''}');
  double? get _height => double.tryParse('${profile['heightCm'] ?? ''}');
  double? get _targetValue =>
      double.tryParse(target.text.trim().replaceAll(',', '.'));
  bool get _hasStats =>
      _weight != null && _height != null && [3, 4, 5].contains(mealsPerDay);

  String? get _targetError {
    return GoalMetrics.targetError(
      goal: goal,
      currentKg: _weight,
      targetKg: _targetValue,
    );
  }

  Future<void> supplementProfile() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingPage(
          api: widget.api,
          step: 1,
          onComplete: () => Navigator.pop(context),
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> saveGoal() async {
    if (!_hasStats) {
      setState(() => error = 'Hãy bổ sung hồ sơ trước khi lưu mục tiêu.');
      return;
    }
    if (_targetError != null) {
      setState(() {
        showTargetValidation = true;
        error = null;
      });
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.api.put('/api/me/goal', {
        'goal': goal,
        'targetWeightKg': goal == 'Giữ cân' ? _weight : _targetValue,
        'durationDays': durationMonths * 30,
        'mealsPerDay': mealsPerDay,
      }, auth: true);
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _displayNumber(Object? value, {int digits = 1}) {
    final parsed = double.tryParse('$value');
    return parsed == null ? 'Chưa có' : parsed.toStringAsFixed(digits);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đặt mục tiêu')),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: green))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1E7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Số liệu từ hồ sơ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chiều cao: ${_displayNumber(profile['heightCm'])} cm',
                    ),
                    Text(
                      'Cân nặng hiện tại: ${_displayNumber(profile['weightKg'])} kg',
                    ),
                    Text('Số bữa mỗi ngày: $mealsPerDay'),
                    if (!_hasStats) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Cần bổ sung các số liệu còn thiếu trong hồ sơ.',
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: supplementProfile,
                          child: const Text('Bổ sung hồ sơ'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Bạn muốn duy trì hay thay đổi cân nặng?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              RadioGroup<String>(
                groupValue: goal,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    goal = value;
                    error = null;
                    showTargetValidation = false;
                    if (value == 'Giữ cân' && _weight != null) {
                      target.text = '$_weight';
                    }
                  });
                },
                child: Column(
                  children: [
                    for (final option in ['Giữ cân', 'Giảm cân', 'Tăng cân'])
                      Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: goal == option ? green : line,
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: option,
                          activeColor: green,
                          title: Text(option),
                        ),
                      ),
                  ],
                ),
              ),
              if (goal == 'Giữ cân')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Cân nặng mong muốn (kg): ${_displayNumber(_weight)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
              else
                TextField(
                  controller: target,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() => error = null),
                  decoration: InputDecoration(
                    labelText: 'Cân nặng mong muốn (kg)',
                    helperText: goal == 'Giảm cân'
                        ? 'Nhập số thấp hơn cân nặng hiện tại (${_displayNumber(_weight)} kg).'
                        : 'Nhập số cao hơn cân nặng hiện tại (${_displayNumber(_weight)} kg).',
                    errorText: showTargetValidation ? _targetError : null,
                  ),
                ),
              const SizedBox(height: 18),
              DropdownButtonFormField<int>(
                initialValue: mealsPerDay,
                decoration: const InputDecoration(
                  labelText: 'Số bữa ăn mỗi ngày',
                  helperText: 'Chọn 3, 4 hoặc 5 bữa mỗi ngày.',
                ),
                items: [3, 4, 5]
                    .map(
                      (count) => DropdownMenuItem<int>(
                        value: count,
                        child: Text('$count bữa'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => mealsPerDay = value);
                },
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<int>(
                initialValue: durationMonths,
                decoration: const InputDecoration(
                  labelText: 'Thời hạn mục tiêu',
                  helperText: 'Thời hạn tính từ ngày mục tiêu bắt đầu áp dụng.',
                ),
                items: List.generate(24, (index) => index + 1)
                    .map(
                      (months) => DropdownMenuItem<int>(
                        value: months,
                        child: Text('$months tháng'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => durationMonths = value);
                },
              ),
              if (error != null) _ErrorBox(error!),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: saving || !_hasStats ? null : saveGoal,
                child: Text(saving ? 'Đang lưu…' : 'Lưu mục tiêu'),
              ),
            ],
          ),
  );
}

String _newSessionGuid() {
  final random = math.Random.secure();
  final hex = List.generate(
    32,
    (_) => random.nextInt(16).toRadixString(16),
  ).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class GoalResultsPage extends StatelessWidget {
  const GoalResultsPage({super.key, required this.api, required this.profile});
  final ApiClient api;
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final weight = double.tryParse('${profile['weightKg'] ?? ''}');
    final height = double.tryParse('${profile['heightCm'] ?? ''}');
    final target = double.tryParse('${profile['targetWeightKg'] ?? ''}');
    final meals = int.tryParse('${profile['mealsPerDay'] ?? ''}') ?? 0;
    final allocations = (profile['mealAllocations'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final mealNames = allocations.isEmpty
        ? GoalMetrics.mealNames(meals)
        : allocations.map((x) => '${x['mealName']}').toList();
    final bmi = GoalMetrics.bmi(weightKg: weight, heightCm: height);
    final dailyCalorieTarget = double.tryParse(
      '${profile['dailyCalorieTarget'] ?? ''}',
    );
    final isAdultCalorieEstimate = profile['isAdultCalorieEstimate'] == true;
    final usesAverageSexEstimate = profile['usesAverageSexEstimate'] == true;
    String kg(double? value) =>
        value == null ? 'Ch\u01b0a c\u00f3' : '${value.toStringAsFixed(1)} kg';
    return Scaffold(
      appBar: AppBar(title: const Text('K\u1ebft qu\u1ea3 m\u1ee5c ti\u00eau')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BMI hi\u1ec7n t\u1ea1i',
                  style: TextStyle(color: Color(0xFFBFD7C5)),
                ),
                const SizedBox(height: 6),
                Text(
                  bmi == null
                      ? 'Ch\u01b0a \u0111\u1ee7 s\u1ed1 li\u1ec7u'
                      : bmi.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'T\u00ednh t\u1eeb c\u00e2n n\u1eb7ng hi\u1ec7n t\u1ea1i ${kg(weight)} v\u00e0 chi\u1ec1u cao ${profile['heightCm'] ?? 'Ch\u01b0a c\u00f3'} cm.',
                  style: const TextStyle(color: Color(0xFFE0EAE2)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            color: const Color(0xFFEAF4EB),
            child: ListTile(
              leading: const Icon(Icons.local_fire_department, color: green),
              title: const Text('Mức calo mục tiêu mỗi ngày'),
              subtitle: Text(
                dailyCalorieTarget == null
                    ? 'Bổ sung ngày sinh, giới tính và mức vận động để tính.'
                    : usesAverageSexEstimate
                    ? 'Giới tính Khác dùng mức trung bình; đây là ước tính tham khảo.'
                    : isAdultCalorieEstimate
                    ? 'Ước tính từ hồ sơ và mục tiêu cân nặng (điều chỉnh tham khảo 10%).'
                    : 'Nhu cầu ước tính theo tuổi; chưa điều chỉnh calo theo mục tiêu cân nặng.',
              ),
              trailing: dailyCalorieTarget == null
                  ? const Text('—')
                  : Text(
                      '${dailyCalorieTarget.toStringAsFixed(0)} kcal',
                      style: const TextStyle(
                        color: ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            color: Colors.white,
            child: ListTile(
              title: Text(
                'M\u1ee5c ti\u00eau: ${profile['goal'] ?? 'Ch\u01b0a ch\u1ecdn'}',
              ),
              subtitle: Text(
                'C\u00e2n n\u1eb7ng mong mu\u1ed1n: ${kg(target)}',
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'C\u00e1c b\u1eefa \u0103n',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chọn một bữa để tạo món AI từ công thức đã duyệt. Nếu chưa có chỉ tiêu dinh dưỡng cho bữa, app dùng khẩu phần chuẩn của công thức.',
          ),
          const SizedBox(height: 8),
          if (profile['targetStatus'] == 'NeedsNutritionTargets')
            const _InfoCard(
              icon: Icons.info_outline,
              title: 'Đang dùng khẩu phần chuẩn',
              text: 'Chỉ tiêu dinh dưỡng riêng cho từng bữa chưa được thiết lập. Món AI vẫn tạo được từ công thức đã duyệt, theo chế độ ăn và dị ứng trong hồ sơ.',
            ),
          for (var i = 0; i < mealNames.length; i++)
            Card(
              color: Colors.white,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEAF1E7),
                  child: Icon(Icons.restaurant_outlined, color: green),
                ),
                title: Text(mealNames[i]),
                subtitle: const Text(
                  'T\u1ea1o m\u00f3n AI cho b\u1eefa n\u00e0y',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: profile['id'] == null
                    ? null
                    : () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => MealGenerationPage(
                            api: api,
                            goalId: '${profile['id']}',
                            mealName: mealNames[i],
                            mealNames: mealNames,
                            mealDate: DateTime.now(),
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class MealGenerationPage extends StatefulWidget {
  const MealGenerationPage({
    super.key,
    required this.api,
    required this.goalId,
    required this.mealName,
    required this.mealNames,
    required this.mealDate,
  });
  final ApiClient api;
  final String goalId;
  final String mealName;
  final List<String> mealNames;
  final DateTime mealDate;

  @override
  State<MealGenerationPage> createState() => _MealGenerationPageState();
}

class _MealGenerationPageState extends State<MealGenerationPage> {
  String sessionId = _newSessionGuid();
  late DateTime selectedDate;
  late String selectedMealName;
  Map<String, dynamic>? suggestion;
  List<Map<String, dynamic>> portionItems = [];
  List<Map<String, dynamic>> foodCatalog = [];
  bool loading = true;
  bool confirming = false;
  bool loadingFoods = false;
  bool dirty = false;
  bool notesExpanded = true;
  String? message;

  static const _nutrientKeys = [
    'energy_kcal',
    'protein_g',
    'carbohydrate_g',
    'total_fat_g',
    'fiber_g',
    'total_sugars_g',
    'saturated_fat_g',
    'sodium_mg',
  ];

  List<String> get mealOptions {
    final names = widget.mealNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    return names.isEmpty ? [widget.mealName] : names;
  }

  String get dateLabel =>
      '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime(
      widget.mealDate.year,
      widget.mealDate.month,
      widget.mealDate.day,
    );
    selectedMealName = mealOptions.contains(widget.mealName)
        ? widget.mealName
        : mealOptions.first;
    _loadOrGenerate();
  }

  String get _dateIso =>
      '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

  void _adoptSuggestion(Map<String, dynamic> result) {
    if (!mounted) return;
    setState(() {
      suggestion = Map<String, dynamic>.from(result);
      portionItems = (result['ingredients'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      dirty = false;
      message = null;
    });
  }

  Future<void> _loadOrGenerate() async {
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final saved = await widget.api.get(
        '/api/me/meals/suggestion?date=$_dateIso&mealName=${Uri.encodeQueryComponent(selectedMealName)}',
        auth: true,
      );
      _adoptSuggestion(saved);
    } catch (_) {
      await generate(showLoading: false);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> generate({bool replace = false, bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        loading = true;
        message = null;
      });
    }
    try {
      final result = await widget.api.post(
        '/api/me/meals/generate',
        {
          'sessionId': sessionId,
          'mealDate': _dateIso,
          'mealName': selectedMealName,
          'replaceExisting': replace,
        },
        auth: true,
        timeout: const Duration(seconds: 60),
      );
      _adoptSuggestion(result);
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (showLoading && mounted) setState(() => loading = false);
    }
  }

  Future<void> _selectMeal(String name) async {
    if (name == selectedMealName || loading) return;
    setState(() {
      selectedMealName = name;
      sessionId = _newSessionGuid();
      suggestion = null;
      portionItems = [];
      dirty = false;
    });
    await _loadOrGenerate();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      selectedDate = DateTime(chosen.year, chosen.month, chosen.day);
      sessionId = _newSessionGuid();
      suggestion = null;
      portionItems = [];
    });
    await _loadOrGenerate();
  }

  double _grams(Map<String, dynamic> item) => item['grams'] is num
      ? (item['grams'] as num).toDouble()
      : double.tryParse('${item['grams']}') ?? 0;

  bool _hasCoreNutrition(Map<String, dynamic> food) {
    final values = _nutritionForFood(food);
    return [
      'energy_kcal',
      'protein_g',
      'carbohydrate_g',
      'total_fat_g',
    ].every((key) => values[key] is num);
  }

  Map<String, dynamic> _nutritionForFood(Map<String, dynamic> food) {
    final raw = food['nutrition'] is Map
        ? Map<String, dynamic>.from(food['nutrition'] as Map)
        : <String, dynamic>{};
    return {
      'energy_kcal': raw['energyKcal'] ?? raw['energy_kcal'],
      'protein_g': raw['proteinG'] ?? raw['protein_g'],
      'carbohydrate_g': raw['carbohydrateG'] ?? raw['carbohydrate_g'],
      'total_fat_g': raw['fatG'] ?? raw['totalFatG'] ?? raw['total_fat_g'],
      'fiber_g': raw['fiberG'] ?? raw['fiber_g'],
      'total_sugars_g':
          raw['sugarG'] ?? raw['totalSugarsG'] ?? raw['total_sugars_g'],
      'saturated_fat_g': raw['saturatedFatG'] ?? raw['saturated_fat_g'],
      'sodium_mg': raw['sodiumMg'] ?? raw['sodium_mg'],
    };
  }

  void _recalculateNutrition() {
    if (suggestion == null) return;
    final totals = <String, double?>{};
    for (final key in _nutrientKeys) {
      var total = 0.0;
      var complete = true;
      for (final item in portionItems) {
        final per100 = item['nutritionPer100g'];
        final value = per100 is Map ? per100[key] : null;
        if (value is! num) {
          complete = false;
          break;
        }
        total += value.toDouble() * _grams(item) / 100;
      }
      totals[key] = complete ? total : null;
    }
    suggestion = {...suggestion!, 'estimatedNutrients': totals};
  }

  void _adjustIngredient(int index, double delta) {
    if (suggestion?['isConfirmed'] == true) return;
    setState(() {
      final next = _grams(portionItems[index]) + delta;
      if (next <= 0) {
        portionItems.removeAt(index);
      } else {
        portionItems[index] = {...portionItems[index], 'grams': next};
      }
      dirty = true;
      _recalculateNutrition();
    });
  }

  Future<void> _addIngredient() async {
    if (suggestion?['isConfirmed'] == true || loadingFoods) return;
    if (foodCatalog.isEmpty) {
      setState(() => loadingFoods = true);
      try {
        final result = await widget.api.get('/api/foods');
        foodCatalog = (result['data'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .where(_hasCoreNutrition)
            .toList();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
        return;
      } finally {
        if (mounted) setState(() => loadingFoods = false);
      }
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final foods = foodCatalog
                .where(
                  (food) => '${food['name']}'.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
                )
                .toList();
            return Container(
              height: MediaQuery.of(context).size.height * .78,
              padding: EdgeInsets.fromLTRB(
                18,
                12,
                18,
                MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              decoration: const BoxDecoration(
                color: canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: line,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Thêm nguyên liệu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Tìm thực phẩm',
                    ),
                    onChanged: (value) =>
                        setSheetState(() => query = value.trim()),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: foods.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final food = foods[index];
                        final foodId = '${food['id']}';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _foodImage(
                            foodId,
                            food['hasImage'] == true,
                            46,
                          ),
                          title: Text('${food['name']}'),
                          trailing: const Icon(
                            Icons.add_circle_outline,
                            color: green,
                          ),
                          onTap: () => Navigator.pop(sheetContext, food),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (chosen == null || !mounted) return;
    final foodId = '${chosen['id']}';
    setState(() {
      final existing = portionItems.indexWhere(
        (item) => '${item['foodId']}' == foodId,
      );
      if (existing >= 0) {
        portionItems[existing] = {
          ...portionItems[existing],
          'grams': _grams(portionItems[existing]) + 50,
        };
      } else {
        portionItems.add({
          'foodId': foodId,
          'name': chosen['name'],
          'grams': 50.0,
          'inPantry': false,
          'hasImage': chosen['hasImage'] == true,
          'nutritionPer100g': _nutritionForFood(chosen),
        });
      }
      dirty = true;
      _recalculateNutrition();
    });
  }

  Future<void> _savePortions() async {
    final current = suggestion;
    if (current == null || !dirty) return;
    final result = await widget.api.put(
      '/api/me/meals/${current['id']}/portions',
      {
        'ingredients': portionItems
            .map(
              (item) => {'foodId': '${item['foodId']}', 'grams': _grams(item)},
            )
            .toList(),
      },
      auth: true,
    );
    _adoptSuggestion(result);
  }

  Future<void> _toggleMealLog() async {
    final current = suggestion;
    if (current == null) return;
    final wasConfirmed = current['isConfirmed'] == true;
    setState(() {
      confirming = true;
      message = null;
    });
    try {
      if (wasConfirmed) {
        await widget.api.delete(
          '/api/me/meals/${current['id']}/confirm',
          auth: true,
        );
      } else {
        await _savePortions();
        await widget.api.post(
          '/api/me/meals/${current['id']}/confirm',
          const {},
          auth: true,
        );
      }
      if (mounted) {
        setState(() {
          suggestion = {
            ...(suggestion ?? current),
            'isConfirmed': !wasConfirmed,
          };
          dirty = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => confirming = false);
    }
  }

  IconData _mealIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('sáng')) return Icons.wb_sunny_outlined;
    if (lower.contains('trưa')) return Icons.wb_sunny;
    if (lower.contains('chiều')) return Icons.wb_twilight;
    return Icons.dark_mode_outlined;
  }

  String _mealLabel(String name) {
    final index = mealOptions.indexOf(name);
    if (index < 0) return name;
    if (mealOptions.length == 4) return ['Sáng', 'Trưa', 'Chiều', 'Tối'][index];
    if (mealOptions.length == 3) return ['Sáng', 'Trưa', 'Tối'][index];
    return name;
  }

  Widget _mealTabs() => Container(
    margin: const EdgeInsets.fromLTRB(18, 10, 18, 12),
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(40),
      boxShadow: const [
        BoxShadow(
          color: Color(0x10000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: mealOptions.map((name) {
        final selected = name == selectedMealName;
        return Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () => _selectMeal(name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF138047) : Colors.transparent,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _mealIcon(_mealLabel(name)),
                    color: selected ? Colors.white : const Color(0xFF17633F),
                    size: 23,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _mealLabel(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : ink,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );

  Widget _dateCard() => Card(
    margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFEAF5EC),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.calendar_month_outlined, color: green),
      ),
      title: const Text(
        'Ngày bữa ăn',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(dateLabel, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(
        Icons.chevron_right,
        color: Color(0xFF17633F),
        size: 28,
      ),
      onTap: loading ? null : _chooseDate,
    ),
  );

  Widget _foodImage(String id, bool hasImage, double size) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.eco_outlined, color: green),
    );
    if (!hasImage || id.isEmpty || id == 'null') return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        '${ApiConfig.baseUrl}/api/foods/$id/image',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  Widget _dishImage(Map<String, dynamic> current) {
    final id = '${current['dishId'] ?? ''}';
    final fallback = Container(
      width: double.infinity,
      height: 132,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.restaurant_menu, size: 48, color: green),
    );
    if (current['hasImage'] != true || id.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        '${ApiConfig.baseUrl}/api/dishes/$id/image',
        headers: widget.api.accessToken == null
            ? null
            : {'Authorization': 'Bearer ${widget.api.accessToken}'},
        width: double.infinity,
        height: 132,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  double? _nutrient(Map<String, dynamic>? values, String key) {
    final value = values?[key];
    return value is num ? value.toDouble() : double.tryParse('$value');
  }

  String _formatNutrient(double? value) =>
      value == null ? '—' : value.toStringAsFixed(0);

  Widget _macro(IconData icon, String label, double? value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: const Color(0xFF178348), size: 16),
      const SizedBox(width: 3),
      Text(
        '$label: ${_formatNutrient(value)} g',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ],
  );

  Widget _dishCard(Map<String, dynamic> current) {
    final values = current['estimatedNutrients'] is Map
        ? Map<String, dynamic>.from(current['estimatedNutrients'] as Map)
        : null;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 132, child: _dishImage(current)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${current['dishName'] ?? 'Món ăn'}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF105D3E),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7F0),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: Color(0xFFFF9800),
                            size: 22,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '~ ${_formatNutrient(_nutrient(values, 'energy_kcal'))} kcal',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 9,
                        runSpacing: 5,
                        children: [
                          _macro(
                            Icons.restaurant,
                            'C',
                            _nutrient(values, 'carbohydrate_g'),
                          ),
                          _macro(
                            Icons.spa_outlined,
                            'P',
                            _nutrient(values, 'protein_g'),
                          ),
                          _macro(
                            Icons.circle_outlined,
                            'F',
                            _nutrient(values, 'total_fat_g'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _portionButton(IconData icon, VoidCallback? onPressed) => SizedBox(
    width: 34,
    height: 36,
    child: IconButton.filledTonal(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFEAF5EC),
        foregroundColor: green,
      ),
      icon: Icon(icon, size: 18),
    ),
  );

  Widget _ingredientRow(int index) {
    final item = portionItems[index];
    final id = '${item['foodId'] ?? ''}';
    final locked = suggestion?['isConfirmed'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _foodImage(id, item['hasImage'] == true, 54),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['name'] ?? 'Nguyên liệu'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${_grams(item).toStringAsFixed(1)} g',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          _portionButton(
            Icons.remove,
            locked ? null : () => _adjustIngredient(index, -5),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 68),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF7EF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              '${_grams(item).toStringAsFixed(1)} g',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          _portionButton(
            Icons.add,
            locked ? null : () => _adjustIngredient(index, 5),
          ),
        ],
      ),
    );
  }

  Widget _ingredientsCard() {
    final locked = suggestion?['isConfirmed'] == true;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFF16834A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Khẩu phần cá nhân',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton.icon(
                onPressed: locked || loadingFoods ? null : _addIngredient,
                icon: Icon(
                  loadingFoods ? Icons.hourglass_top : Icons.add,
                  size: 17,
                ),
                label: const Text('Thêm món'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF138047),
                  side: const BorderSide(color: Color(0xFF138047)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 38),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          if (portionItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Chưa có nguyên liệu trong khẩu phần.'),
            ),
          for (var i = 0; i < portionItems.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _ingredientRow(i),
          ],
        ],
      ),
    );
  }

  Widget _notesCard(Map<String, dynamic> current) {
    final notes = '${current['cookingNotes'] ?? ''}'.trim();
    if (notes.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F8F0),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => notesExpanded = !notesExpanded),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16834A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.soup_kitchen_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ghi chú (cách nấu)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(
                    notesExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF17633F),
                  ),
                ],
              ),
            ),
            if (notesExpanded) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  notes,
                  style: const TextStyle(color: ink, height: 1.5, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mealBody() {
    final current = suggestion;
    if (loading)
      return const Center(child: CircularProgressIndicator(color: green));
    if (current == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (message != null) _ErrorBox(message!),
          const Text(
            'Món được chọn từ công thức đã duyệt và lọc theo chế độ ăn, dị ứng.',
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => generate(),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Tạo món AI'),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        if (message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: _ErrorBox(message!),
          ),
        _dishCard(current),
        _ingredientsCard(),
        _notesCard(current),
        if (current['isConfirmed'] != true)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: OutlinedButton.icon(
              onPressed: loading ? null : () => generate(replace: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Đổi món'),
            ),
          ),
      ],
    );
  }

  Widget _bottomActions() {
    final saved = suggestion?['isConfirmed'] == true;
    final disabled = suggestion == null || loading || confirming;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: disabled ? null : _toggleMealLog,
            icon: Icon(
              confirming
                  ? Icons.hourglass_top
                  : saved
                  ? Icons.undo
                  : Icons.check_circle_outline,
            ),
            label: Text(
              confirming
                  ? saved
                        ? 'Đang hủy lưu...'
                        : 'Đang lưu...'
                  : saved
                  ? 'Hủy lưu bữa'
                  : 'Lưu bữa ăn',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: saved
                  ? const Color(0xFFB8453D)
                  : const Color(0xFF138047),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Ghi bữa ăn',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      backgroundColor: const Color(0xFF116A42),
      foregroundColor: Colors.white,
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'refresh') generate(replace: true);
            if (value == 'date') _chooseDate();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'refresh', child: Text('Đổi món')),
            PopupMenuItem(value: 'date', child: Text('Chọn ngày')),
          ],
        ),
      ],
    ),
    body: Column(
      children: [
        _mealTabs(),
        _dateCard(),
        Expanded(child: _mealBody()),
      ],
    ),
    bottomNavigationBar: _bottomActions(),
  );
}

class FridgePage extends StatefulWidget {
  const FridgePage({super.key, required this.api});
  final ApiClient api;
  @override
  State<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends State<FridgePage> {
  List<dynamic> items = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final r = await widget.api.get('/api/me/fridge', auth: true);
      items = r['data'] as List<dynamic>? ?? [];
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? item]) async {
    final c = TextEditingController(text: (item?['name'] as String?) ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: canvas,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          24,
          22,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item == null ? 'Thêm nguyên liệu' : 'Sửa nguyên liệu',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: c,
              autofocus: true,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Tên thực phẩm chưa chế biến',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                try {
                  if (item == null) {
                    await widget.api.post('/api/me/fridge', {
                      'name': c.text,
                      'foodId': null,
                    }, auth: true);
                  } else {
                    await widget.api.put('/api/me/fridge/${item['id']}', {
                      'name': c.text,
                      'foodId': null,
                    }, auth: true);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await load();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> chooseAddMethod() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: canvas,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search, color: green),
              title: const Text('Chọn từ danh mục thực phẩm'),
              onTap: () => Navigator.pop(ctx, 'catalog'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: green),
              title: const Text('Tự nhập tên nguyên liệu'),
              onTap: () => Navigator.pop(ctx, 'custom'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'catalog') {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => FoodDirectoryPage(api: widget.api, onAdded: load),
        ),
      );
      await load();
    } else if (choice == 'custom') {
      await edit();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (loading) {
      content = const Center(child: CircularProgressIndicator(color: green));
    } else if (error != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_outlined, size: 40, color: green),
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center),
              TextButton(onPressed: load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    } else if (items.isEmpty) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.kitchen_outlined, size: 52, color: green),
              SizedBox(height: 14),
              Text(
                'Tủ lạnh đang trống',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Thêm nguyên liệu chưa chế biến bạn đang có.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      content = ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text(
            '${items.length} nguyên liệu',
            style: const TextStyle(color: Color(0xFF65726A)),
          ),
          const SizedBox(height: 10),
          ...items.map((raw) {
            final x = raw as Map<String, dynamic>;
            return Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: line),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEAF1E7),
                  child: Icon(Icons.eco_outlined, color: green),
                ),
                title: Text('${x['name']}'),
                subtitle: Text(
                  x['foodId'] == null
                      ? 'Tên do bạn nhập'
                      : 'Danh mục đã xác minh',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      await edit(x);
                      if (!context.mounted) return;
                    }
                    if (v == 'delete') {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                          title: const Text('Xóa nguyên liệu?'),
                          content: Text('Xóa ${x['name']} khỏi tủ lạnh?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(d, false),
                              child: const Text('Hủy'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(d, true),
                              child: const Text('Xóa'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true) {
                        try {
                          await widget.api.delete(
                            '/api/me/fridge/${x['id']}',
                            auth: true,
                          );
                          await load();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('$e')));
                          }
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Sửa')),
                    PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tủ lạnh'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: chooseAddMethod,
        backgroundColor: ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm nguyên liệu'),
      ),
      body: content,
    );
  }
}

class PersonalPage extends StatefulWidget {
  const PersonalPage({
    super.key,
    required this.api,
    required this.profile,
    required this.onLogout,
    required this.onGoalHistory,
    required this.onProfileChanged,
    required this.onFavoritesChanged,
  });
  final ApiClient api;
  final Map<String, dynamic> profile;
  final VoidCallback onLogout;
  final VoidCallback onGoalHistory;
  final VoidCallback onFavoritesChanged;
  final ValueChanged<Map<String, dynamic>> onProfileChanged;
  @override
  State<PersonalPage> createState() => _PersonalPageState();
}

class _PersonalPageState extends State<PersonalPage> {
  Map<String, dynamic> contact = {};

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    try {
      final result = await widget.api.get('/api/me/security', auth: true);
      if (mounted) setState(() => contact = result);
    } catch (_) {
      // The profile remains usable if the contact endpoint is unavailable.
    }
  }

  Future<void> changeAvatar() async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AvatarEditorPage(api: widget.api, profile: widget.profile),
      ),
    );
    if (updated != null)
      widget.onProfileChanged({...widget.profile, ...updated});
  }

  Future<void> editProfile() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingPage(
          api: widget.api,
          step: 1,
          onComplete: () => Navigator.pop(context),
        ),
      ),
    );
    if (!mounted) return;
    try {
      final updated = await widget.api.get('/api/me/profile', auth: true);
      if (mounted) widget.onProfileChanged(updated);
    } catch (_) {}
  }

  Future<void> openSecurity() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SecurityPage(
        api: widget.api,
        onLogout: widget.onLogout,
        adminAccount: false,
        requirePasswordOtp: true,
      ),
    ),
  );

  String get _birthYear {
    final raw = '${widget.profile['birthDate'] ?? ''}';
    if (raw.isEmpty) return 'Chưa cập nhật';
    return DateTime.tryParse(raw)?.year.toString() ?? raw;
  }

  String get _mealSchedule {
    final count = int.tryParse('${widget.profile['mealsPerDay'] ?? ''}');
    return switch (count) {
      3 => 'Sáng, Trưa, Tối',
      4 => 'Sáng, Trưa, Chiều, Tối',
      5 => 'Sáng, Phụ sáng, Trưa, Phụ chiều, Tối',
      2 => '2 bữa mỗi ngày',
      1 => '1 bữa mỗi ngày',
      null => 'Chưa cập nhật',
      _ => '$count bữa mỗi ngày',
    };
  }

  String get _dietLabel {
    final value = '${widget.profile['diet'] ?? ''}';
    if (value.isEmpty) return 'Chưa cập nhật';
    if (value.toLowerCase().contains('bình thường')) return 'Thông thường';
    return value;
  }

  String get _allergyLabel {
    if (widget.profile['noAllergies'] == true) return 'Không có';
    try {
      final raw = widget.profile['allergiesJson'];
      final items = raw is String
          ? jsonDecode(raw) as List<dynamic>
          : <dynamic>[];
      return items.isEmpty ? 'Chưa khai báo' : items.join(', ');
    } catch (_) {
      return 'Chưa khai báo';
    }
  }

  String get _dislikeLabel {
    final raw = widget.profile['dislikes'];
    if (raw is List && raw.isNotEmpty) return raw.join(', ');
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return 'Chưa khai báo';
  }

  String get _activityLabel =>
      '${widget.profile['activityLevel'] ?? 'Chưa cập nhật'}';

  String _maskEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Chưa có email';
    final parts = value.trim().split('@');
    if (parts.length != 2) return value;
    final prefix = parts[0];
    final visible = prefix.length <= 2 ? prefix : prefix.substring(0, 2);
    return '$visible***@${parts[1]}';
  }

  String _maskPhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Chưa có số điện thoại';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 5) return value;
    return '${digits.substring(0, 2)}***${digits.substring(digits.length - 3)}';
  }

  Widget _factTile(String label, String value) => Container(
    constraints: const BoxConstraints(minHeight: 62),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F5F1),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF77827A), fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );

  Widget _sectionCard({required String title, required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: const Color(0xFFE8ECE7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                color: ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _habitRow(String label, String value, {bool last = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFE7EBE6))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF77827A)),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 12,
                  color: ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _settingsRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = green,
    Widget? trailing,
    bool destructive = false,
    bool last = false,
  }) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFE7EBE6))),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: destructive ? const Color(0xFFC85E58) : color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: destructive ? const Color(0xFFC85E58) : ink,
              ),
            ),
          ),
          if (trailing != null) ...[trailing, const SizedBox(width: 8)],
          Icon(
            Icons.chevron_right,
            color: destructive
                ? const Color(0xFFC85E58)
                : const Color(0xFF579178),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final height = widget.profile['heightCm'] == null
        ? 'Chưa cập nhật'
        : '${widget.profile['heightCm']} cm';
    final weight = widget.profile['weightKg'] == null
        ? 'Chưa cập nhật'
        : '${widget.profile['weightKg']} kg';
    final fullName = '${widget.profile['fullName'] ?? 'Hồ sơ của tôi'}';
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 62,
        leadingWidth: 108,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.eco, color: green, size: 24),
              const SizedBox(width: 3),
              const Text(
                'avora',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: green,
                ),
              ),
              const SizedBox(width: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE88C4D),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Cá nhân',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: editProfile,
            child: const Text(
              'Chỉnh sửa',
              style: TextStyle(color: green, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 9,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _ProfileAvatar(
                    api: widget.api,
                    profile: widget.profile,
                    radius: 43,
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: 0,
                  child: Material(
                    color: green,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: changeAvatar,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            fullName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_maskEmail(contact['email']?.toString())} · ${_maskPhone(contact['phone']?.toString())}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF7C8780)),
          ),
          const SizedBox(height: 20),
          _sectionCard(
            title: 'Hồ sơ cơ thể',
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio:
                  (MediaQuery.sizeOf(context).width - 79) / 2 / 82,
              children: [
                _factTile('Chiều cao', height),
                _factTile('Cân nặng', weight),
                _factTile('Năm sinh', _birthYear),
                _factTile('Vận động', _activityLabel),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            title: 'Thói quen ăn uống',
            child: Column(
              children: [
                _habitRow('Bữa thường dùng', _mealSchedule),
                _habitRow('Chế độ ăn', _dietLabel),
                _habitRow('Dị ứng', _allergyLabel),
                _habitRow('Không thích', _dislikeLabel, last: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: const Color(0xFFE8ECE7)),
            ),
            child: Column(
              children: [
                _settingsRow(
                  icon: Icons.track_changes_outlined,
                  title: 'Lịch sử mục tiêu',
                  onTap: widget.onGoalHistory,
                ),
                _settingsRow(
                  icon: Icons.favorite_border,
                  title: 'Món yêu thích',
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FavoritesPage(api: widget.api),
                      ),
                    );
                    if (mounted) widget.onFavoritesChanged();
                  },
                ),
                _settingsRow(
                  icon: Icons.lock_outline,
                  title: 'Đổi mật khẩu',
                  onTap: openSecurity,
                ),
                _settingsRow(
                  icon: Icons.delete_outline,
                  title: 'Xóa tài khoản',
                  onTap: openSecurity,
                  color: const Color(0xFFC85E58),
                  destructive: true,
                ),
                _settingsRow(
                  icon: Icons.logout,
                  title: 'Đăng xuất',
                  onTap: () async {
                    await widget.api.logout();
                    widget.onLogout();
                  },
                  color: const Color(0xFF77827A),
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AvatarEditorPage extends StatefulWidget {
  const AvatarEditorPage({super.key, required this.api, required this.profile});
  final ApiClient api;
  final Map<String, dynamic> profile;
  @override
  State<AvatarEditorPage> createState() => _AvatarEditorPageState();
}

class _AvatarEditorPageState extends State<AvatarEditorPage> {
  final picker = ImagePicker();
  Uint8List? preview;
  String? contentType;
  bool saving = false;
  String? error;

  Future<void> chooseImage() async {
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final mime =
          image.mimeType ??
          switch (image.name.split('.').last.toLowerCase()) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => 'image/jpeg',
          };
      if (mounted) {
        setState(() {
          preview = bytes;
          contentType = mime;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Không mở được ảnh: $e');
    }
  }

  Future<void> saveImage() async {
    if (preview == null || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await widget.api.uploadBytes(
        '/api/me/avatar',
        preview!,
        contentType: contentType ?? 'image/jpeg',
        auth: true,
      );
      final updated = Map<String, dynamic>.from(widget.profile)..addAll(result);
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đổi ảnh đại diện')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Center(
          child: preview == null
              ? _ProfileAvatar(
                  api: widget.api,
                  profile: widget.profile,
                  radius: 76,
                )
              : CircleAvatar(
                  radius: 76,
                  backgroundColor: const Color(0xFFE4EDE2),
                  backgroundImage: MemoryImage(preview!),
                ),
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: saving ? null : chooseImage,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Chọn ảnh từ điện thoại'),
        ),
        if (saving) ...[
          const SizedBox(height: 18),
          const LinearProgressIndicator(color: green),
          const SizedBox(height: 8),
          const Text('Đang lưu ảnh…', textAlign: TextAlign.center),
        ],
        if (error != null) _ErrorBox(error!),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: preview == null || saving ? null : saveImage,
          child: Text(saving ? 'Đang lưu…' : 'Lưu ảnh'),
        ),
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
      ],
    ),
  );
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool loading = true;
  String? error;
  List<dynamic> items = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await widget.api.get('/api/me/favorites', auth: true);
      items = r['data'] as List<dynamic>? ?? [];
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openDish(Map<String, dynamic> item) async {
    final id = '${item['id']}';
    final removed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FavoriteDishDetailPage(api: widget.api, dishId: id),
      ),
    );
    if (removed == true && mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Món yêu thích'),
      actions: [
        IconButton(
          tooltip: 'Làm mới danh sách',
          onPressed: load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: green))
        : error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                TextButton(onPressed: load, child: const Text('Thử lại')),
              ],
            ),
          )
        : items.isEmpty
        ? const Center(child: Text('Bạn chưa có món yêu thích.'))
        : ListView(
            children: items.map((item) {
              final x = item as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.favorite, color: green),
                title: Text('${x['name']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openDish(x),
              );
            }).toList(),
          ),
  );
}

class FavoriteDishDetailPage extends StatefulWidget {
  const FavoriteDishDetailPage({
    super.key,
    required this.api,
    required this.dishId,
  });
  final ApiClient api;
  final String dishId;
  @override
  State<FavoriteDishDetailPage> createState() => _FavoriteDishDetailPageState();
}

class _FavoriteDishDetailPageState extends State<FavoriteDishDetailPage> {
  Map<String, dynamic>? dish;
  String? error;
  bool loading = true, removing = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      dish = await widget.api.get('/api/dishes/${widget.dishId}', auth: true);
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> removeFavorite() async {
    setState(() => removing = true);
    try {
      await widget.api.delete('/api/me/favorites/${widget.dishId}', auth: true);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
          removing = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết món ăn')),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: green))
        : error != null
        ? Center(child: Text(error!, textAlign: TextAlign.center))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${dish?['name'] ?? 'Món ăn'}',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Nguyên liệu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              ...((dish?['ingredients'] as List<dynamic>? ?? []).map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.circle, size: 8, color: green),
                  title: Text('${item['name'] ?? ''}'),
                ),
              )),
              if ((dish?['cookingNotes'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Ghi chú / Cách nấu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text('${dish?['cookingNotes']}'),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: removing ? null : removeFavorite,
                icon: const Icon(Icons.favorite_border),
                label: Text(removing ? '?ang c?p nh?t?' : 'B? y?u th?ch'),
              ),
            ],
          ),
  );
}

class SecurityPage extends StatefulWidget {
  const SecurityPage({
    super.key,
    required this.api,
    required this.onLogout,
    required this.adminAccount,
    required this.requirePasswordOtp,
  });
  final ApiClient api;
  final VoidCallback onLogout;
  final bool adminAccount;
  final bool requirePasswordOtp;
  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final current = TextEditingController(),
      next = TextEditingController(),
      email = TextEditingController(),
      emailPassword = TextEditingController(),
      contactCode = TextEditingController(),
      phone = TextEditingController(),
      phoneCode = TextEditingController(),
      passwordCode = TextEditingController();
  bool loading = true,
      busy = false,
      otpSent = false,
      phoneOtpSent = false,
      passwordOtpSent = false;
  String? error;
  Map<String, dynamic> contact = {};
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    email.dispose();
    emailPassword.dispose();
    contactCode.dispose();
    phone.dispose();
    phoneCode.dispose();
    passwordCode.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      contact = await widget.api.get('/api/me/security', auth: true);
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void exitToLogin() {
    widget.onLogout();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> changePassword() async {
    if (!_isPasswordValid(next.text)) {
      setState(() => error = _passwordRequirement);
      return;
    }
    if (widget.requirePasswordOtp &&
        (!passwordOtpSent || passwordCode.text.trim().isEmpty)) {
      setState(
        () => error = 'Hãy nhận và nhập mã xác thực trước khi đổi mật khẩu.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post('/api/me/security/password', {
        'currentPassword': current.text,
        'newPassword': next.text,
        if (widget.requirePasswordOtp) 'code': passwordCode.text.trim(),
      }, auth: true);
      await widget.api.logout();
      exitToLogin();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> requestPasswordCode() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post(
        '/api/me/security/password/request',
        {},
        auth: true,
      );
      setState(() => passwordOtpSent = true);
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> requestEmailCode() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post('/api/me/security/email/request', {
        'newEmail': email.text.trim(),
        'password': emailPassword.text,
      }, auth: true);
      setState(() => otpSent = true);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirmEmail() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post('/api/me/security/email/confirm', {
        'newEmail': email.text.trim(),
        'code': contactCode.text.trim(),
      }, auth: true);
      await widget.api.clearSession();
      exitToLogin();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> requestPhoneCode() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post('/api/me/security/phone/request', {
        'newPhone': phone.text.trim(),
        'password': emailPassword.text,
      }, auth: true);
      setState(() => phoneOtpSent = true);
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirmPhone() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post('/api/me/security/phone/confirm', {
        'newPhone': phone.text.trim(),
        'code': phoneCode.text.trim(),
      }, auth: true);
      await widget.api.clearSession();
      exitToLogin();
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteAccount() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Xóa tài khoản?'),
        content: const Text(
          'Tài khoản và dữ liệu cá nhân liên quan sẽ bị xóa sau khi xác minh email. Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    try {
      await widget.api.post('/api/me/account/delete/request', {}, auth: true);
      if (!context.mounted) return;
      final code = TextEditingController();
      // The page is rechecked with context.mounted immediately before this dialog.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Nhập mã xác nhận'),
          content: TextField(
            controller: code,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Mã xác thực · 60 giây',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Xác nhận xóa'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        await widget.api.post('/api/me/account/delete/confirm', {
          'code': code.text.trim(),
        }, auth: true);
        await widget.api.clearSession();
        exitToLogin();
      }
      code.dispose();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: green)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Bảo mật tài khoản')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.mail_outline, color: green),
              title: Text('${contact['email'] ?? 'Chưa có email'}'),
              subtitle: Text(
                'Email ${contact['isEmailVerified'] == true ? 'đã xác minh' : 'chưa xác minh'} · Số điện thoại ${contact['phone'] ?? 'chưa có'}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu hiện tại để đổi thông tin liên hệ',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email mới'),
          ),
          if (otpSent) ...[
            const SizedBox(height: 10),
            TextField(
              controller: contactCode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mã xác thực · 60 giây',
              ),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton(
            onPressed: busy
                ? null
                : otpSent
                ? confirmEmail
                : requestEmailCode,
            child: Text(
              otpSent ? 'Xác minh email mới' : 'Gửi mã tới email mới',
            ),
          ),
          if (widget.requirePasswordOtp) ...[
            const Divider(height: 36),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại mới'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mã xác nhận số điện thoại sẽ được gửi tới email hiện tại.',
            ),
            if (phoneOtpSent) ...[
              const SizedBox(height: 10),
              TextField(
                controller: phoneCode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Mã xác thực · 60 giây',
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : phoneOtpSent
                  ? confirmPhone
                  : requestPhoneCode,
              child: Text(
                phoneOtpSent
                    ? 'Xác nhận số điện thoại'
                    : 'Gửi mã xác thực đổi số điện thoại',
              ),
            ),
          ],
          const Divider(height: 36),
          TextField(
            controller: current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: next,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
          ),
          const SizedBox(height: 6),
          const Text(_passwordRequirement),
          if (widget.adminAccount) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy || passwordOtpSent ? null : requestPasswordCode,
              child: Text(
                passwordOtpSent
                    ? 'Đã gửi mã xác thực tới email'
                    : 'Gửi mã xác thực đổi mật khẩu',
              ),
            ),
            TextField(
              controller: passwordCode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mã xác thực · 60 giây',
              ),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: busy ? null : changePassword,
            child: const Text('Đổi mật khẩu · đăng xuất phiên cũ'),
          ),
          if (error != null) _ErrorBox(error!),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: busy ? null : deleteAccount,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Xóa tài khoản'),
          ),
        ],
      ),
    );
  }
}

class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.api, required this.onLogout});
  final ApiClient api;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 72,
      centerTitle: true,
      title: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Avora AI'),
          Text(
            'Qu\u1ea3n tr\u1ecb vi\u00ean',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () async {
            await api.logout();
            onLogout();
          },
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'Khu vực quản trị',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 12),
        _EntryCard(
          icon: Icons.people_outline,
          title: 'Người dùng',
          description: 'Quản lý tài khoản và trạng thái',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminUsersPage(api: api)),
          ),
        ),
        _EntryCard(
          icon: Icons.eco_outlined,
          title: 'Quản lý thực phẩm',
          description:
              'Thêm, sửa, xóa, cập nhật ảnh và xác minh nguồn dinh dưỡng',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminFoodsPage(api: api, isSuperAdmin: false),
            ),
          ),
        ),
        _EntryCard(
          icon: Icons.menu_book_outlined,
          title: 'Qu\u1ea3n l\u00fd m\u00f3n \u0103n',
          description: 'Qu\u1ea3n l\u00fd nguy\u00ean li\u1ec7u v\u00e0 h\u01b0\u1edbng d\u1eabn ch\u1ebf bi\u1ebfn',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDishesPage(api: api, isSuperAdmin: false),
            ),
          ),
        ),
        _EntryCard(
          icon: Icons.rate_review_outlined,
          title: 'Đánh giá',
          description: 'Chưa có dữ liệu đánh giá',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminRatingsPage(api: api)),
          ),
        ),
        _EntryCard(
          icon: Icons.query_stats_outlined,
          title: 'Món yêu thích',
          description: 'Xếp hạng theo dữ liệu thực tế',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminFavoritesPage(api: api)),
          ),
        ),
        _EntryCard(
          icon: Icons.delete_outline,
          title: 'Th\u00f9ng R\u00e1c',
          description: 'Ng\u01b0\u1eddi d\u00f9ng, th\u1ef1c ph\u1ea9m v\u00e0 m\u00f3n \u0103n do t\u00e0i kho\u1ea3n n\u00e0y x\u00f3a',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TrashManagementPage(api: api, isSuperAdmin: false),
            ),
          ),
        ),
        _EntryCard(
          icon: Icons.person_outline,
          title: 'Cá nhân và bảo mật',
          description: 'Thông tin liên hệ, đổi mật khẩu',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SecurityPage(
                api: api,
                onLogout: onLogout,
                adminAccount: true,
                requirePasswordOtp: true,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class FirstLoginPasswordPage extends StatefulWidget {
  const FirstLoginPasswordPage({
    super.key,
    required this.api,
    required this.requireOtp,
    required this.onComplete,
  });
  final ApiClient api;
  final bool requireOtp;
  final VoidCallback onComplete;
  @override
  State<FirstLoginPasswordPage> createState() => _FirstLoginPasswordPageState();
}

class _FirstLoginPasswordPageState extends State<FirstLoginPasswordPage> {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  final code = TextEditingController();
  bool busy = false, otpSent = false;
  String? error;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> requestOtp() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post(
        '/api/me/security/password/request',
        {},
        auth: true,
      );
      if (mounted) setState(() => otpSent = true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changePassword() async {
    if (next.text != confirm.text) {
      setState(() => error = 'Mật khẩu xác nhận chưa khớp.');
      return;
    }
    if (!_isPasswordValid(next.text)) {
      setState(() => error = _passwordRequirement);
      return;
    }
    if (widget.requireOtp && (code.text.trim().isEmpty || !otpSent)) {
      setState(
        () => error = 'Hãy nhận và nhập mã xác thực trước khi đổi mật khẩu.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post('/api/me/security/password', {
        'currentPassword': current.text,
        'newPassword': next.text,
        if (widget.requireOtp) 'code': code.text.trim(),
      }, auth: true);
      await widget.api.clearSession();
      widget.onComplete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đổi mật khẩu. Hãy đăng nhập lại.')),
        );
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> logout() async {
    await widget.api.logout();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đổi mật khẩu bắt buộc')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.lock_reset, size: 54, color: green),
        const SizedBox(height: 16),
        const Text(
          'Đây là lần đăng nhập đầu tiên. Hãy xác minh mã xác thực qua email và đổi mật khẩu trước khi sử dụng khu vực quản trị.',
          style: TextStyle(color: ink, fontSize: 17),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: current,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mật khẩu ban đầu'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: next,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
        ),
        const SizedBox(height: 6),
        const Text(_passwordRequirement),
        const SizedBox(height: 12),
        TextField(
          controller: confirm,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới'),
        ),
        if (widget.requireOtp) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: busy || otpSent ? null : requestOtp,
            child: Text(
              otpSent
                  ? 'Đã gửi mã xác thực tới email'
                  : 'Gửi mã xác thực đổi mật khẩu',
            ),
          ),
          TextField(
            controller: code,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Mã xác thực · 60 giây',
            ),
          ),
        ],
        if (error != null) _ErrorBox(error!),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : changePassword,
          child: Text(busy ? 'Đang lưu…' : 'Đổi mật khẩu'),
        ),
        TextButton(
          onPressed: busy ? null : logout,
          child: const Text('Đăng xuất'),
        ),
      ],
    ),
  );
}

class SuperAdminPage extends StatelessWidget {
  const SuperAdminPage({super.key, required this.api, required this.onLogout});
  final ApiClient api;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 72,
      centerTitle: true,
      title: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Avora AI'),
          Text(
            'Qu\u1ea3n tr\u1ecb h\u1ec7 th\u1ed1ng',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () async {
            await api.logout();
            onLogout();
          },
          icon: const Icon(Icons.logout),
          tooltip: 'Đăng xuất',
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Quản trị hệ thống',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 14),
        _EntryCard(
          icon: Icons.restaurant_menu_outlined,
          title: 'Quản lý thực phẩm',
          description:
              'Thêm, sửa, xóa, cập nhật ảnh và xác minh nguồn dinh dưỡng',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminFoodsPage(api: api, isSuperAdmin: true),
            ),
          ),
        ),
        _EntryCard(
          icon: Icons.menu_book_outlined,
          title: 'Qu\u1ea3n l\u00fd m\u00f3n \u0103n',
          description: 'Qu\u1ea3n l\u00fd nguy\u00ean li\u1ec7u v\u00e0 h\u01b0\u1edbng d\u1eabn ch\u1ebf bi\u1ebfn',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDishesPage(api: api, isSuperAdmin: true),
            ),
          ),
        ),
        _EntryCard(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Quản lý quản trị viên',
          description: 'Tìm kiếm, thêm, khóa, khôi phục và xóa mềm',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SuperAdminAdminsPage(api: api)),
          ),
        ),
        _EntryCard(
          icon: Icons.people_outline,
          title: 'Qu\u1ea3n l\u00fd ng\u01b0\u1eddi d\u00f9ng',
          description: 'T\u00ecm ki\u1ebfm, xem h\u1ed3 s\u01a1, kh\u00f3a ho\u1eb7c x\u00f3a t\u00e0i kho\u1ea3n User',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminUsersPage(api: api)),
          ),
        ),
        _EntryCard(
          icon: Icons.history,
          title: 'Nhật ký quản trị',
          description:
              'Chọn quản trị viên để xem các thao tác của tài khoản đó',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SuperAdminAuditPage(api: api)),
          ),
        ),
        _EntryCard(
          icon: Icons.delete_outline,
          title: 'Th\u00f9ng R\u00e1c',
          description: 'Ng\u01b0\u1eddi d\u00f9ng, th\u1ef1c ph\u1ea9m v\u00e0 m\u00f3n \u0103n \u0111\u00e3 x\u00f3a',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrashManagementPage(api: api, isSuperAdmin: true),
            ),
          ),
        ),
        _EntryCard(
          icon: Icons.person_outline,
          title: 'Cá nhân và bảo mật',
          description: 'Thông tin liên hệ, đổi mật khẩu',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SecurityPage(
                api: api,
                onLogout: onLogout,
                adminAccount: true,
                requirePasswordOtp: true,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class TrashManagementPage extends StatelessWidget {
  const TrashManagementPage({
    super.key,
    required this.api,
    required this.isSuperAdmin,
  });
  final ApiClient api;
  final bool isSuperAdmin;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Th\u00f9ng R\u00e1c')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Ch\u1ecdn m\u1ee5c c\u1ea7n xem',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 12),
        _trashCategory(
          context,
          Icons.people_outline,
          'Ng\u01b0\u1eddi d\u00f9ng',
          'T\u00e0i kho\u1ea3n User \u0111\u00e3 x\u00f3a',
          () => DeletedUsersTrashPage(api: api, isSuperAdmin: isSuperAdmin),
        ),
        _trashCategory(
          context,
          Icons.restaurant_outlined,
          'Th\u1ef1c ph\u1ea9m',
          'Th\u1ef1c ph\u1ea9m \u0111\u00e3 x\u00f3a',
          () => AdminFoodsPage(
            api: api,
            isSuperAdmin: isSuperAdmin,
            trashOnly: true,
          ),
        ),
        _trashCategory(
          context,
          Icons.menu_book_outlined,
          'M\u00f3n \u0103n',
          'M\u00f3n \u0103n \u0111\u00e3 x\u00f3a',
          () => AdminDishesPage(
            api: api,
            isSuperAdmin: isSuperAdmin,
            trashOnly: true,
          ),
        ),
      ],
    ),
  );

  Widget _trashCategory(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget Function() page,
  ) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF0E8),
        child: Icon(icon, color: green),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page())),
    ),
  );
}

class DeletedUsersTrashPage extends StatefulWidget {
  const DeletedUsersTrashPage({
    super.key,
    required this.api,
    required this.isSuperAdmin,
  });
  final ApiClient api;
  final bool isSuperAdmin;
  @override
  State<DeletedUsersTrashPage> createState() => _DeletedUsersTrashPageState();
}

class _DeletedUsersTrashPageState extends State<DeletedUsersTrashPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> users = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await widget.api.get(
        widget.isSuperAdmin
            ? '/api/superadmin/users/trash'
            : '/api/admin/users/trash',
        auth: true,
      );
      users = ((response['data'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>();
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> restore(Map<String, dynamic> user) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kh\u00f4i ph\u1ee5c t\u00e0i kho\u1ea3n?'),
        content: Text(
          'T\u00e0i kho\u1ea3n ${user['fullName'] ?? user['email'] ?? user['phone'] ?? ''} s\u1ebd \u0111\u01b0\u1ee3c kh\u00f4i ph\u1ee5c v\u00e0 \u0111\u1eb7t v\u1ec1 tr\u1ea1ng th\u00e1i kh\u00f3a.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('H\u1ee7y'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kh\u00f4i ph\u1ee5c'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await widget.api.post(
        '/api/superadmin/users/${user['id']}/restore',
        {},
        auth: true,
      );
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Th\u00f9ng R\u00e1c - Ng\u01b0\u1eddi d\u00f9ng'),
      actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: green))
        : error != null
        ? Center(
            child: TextButton(
              onPressed: load,
              child: Text('Th\u1eed l\u1ea1i - $error'),
            ),
          )
        : users.isEmpty
        ? const Center(
            child: Text(
              'Kh\u00f4ng c\u00f3 t\u00e0i kho\u1ea3n User trong th\u00f9ng r\u00e1c.',
            ),
          )
        : RefreshIndicator(
            onRefresh: load,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final user = users[index];
                final displayName =
                    user['fullName'] ??
                    user['username'] ??
                    user['email'] ??
                    user['phone'] ??
                    'User';
                final actorLine = widget.isSuperAdmin
                    ? '\nX\u00f3a b\u1edfi: ${user['deletedByName'] ?? 'Kh\u00f4ng r\u00f5'}${user['deletedByEmail'] == null ? '' : ' \u00b7 ${user['deletedByEmail']}'}'
                    : '';
                return Card(
                  child: ListTile(
                    isThreeLine: true,
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(
                      '$displayName',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${user['email'] ?? user['phone'] ?? ''}$actorLine\nL\u00fd do: ${user['deletionReason'] ?? 'Kh\u00f4ng c\u00f3'}',
                    ),
                    trailing: widget.isSuperAdmin
                        ? IconButton(
                            tooltip: 'Kh\u00f4i ph\u1ee5c',
                            onPressed: () => restore(user),
                            icon: const Icon(Icons.restore, color: green),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
  );
}

class SuperAdminAdminsPage extends StatefulWidget {
  const SuperAdminAdminsPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<SuperAdminAdminsPage> createState() => _SuperAdminAdminsPageState();
}

class _SuperAdminAdminsPageState extends State<SuperAdminAdminsPage> {
  final search = TextEditingController();
  List<Map<String, dynamic>> admins = [];
  String status = 'all';
  int page = 1, pageSize = 10, total = 0;
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final q = <String, String>{
        'page': '$page',
        'pageSize': '$pageSize',
        'status': status,
      };
      if (search.text.trim().isNotEmpty) q['search'] = search.text.trim();
      final r = await widget.api.get(
        '/api/superadmin/admins?${Uri(queryParameters: q).query}',
        auth: true,
      );
      admins = (r['items'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      total = r['total'] as int? ?? 0;
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? admin]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SuperAdminAdminEditor(api: widget.api, admin: admin),
      ),
    );
    if (mounted) load();
  }

  Future<void> changeStatus(Map<String, dynamic> admin) async {
    final reason = TextEditingController();
    final makeActive = admin['isActive'] != true;
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(
          makeActive ? 'Mở khóa quản trị viên?' : 'Khóa quản trị viên?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Email: ${admin['email'] ?? 'Chưa có'}'),
            TextField(
              controller: reason,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Lý do (bắt buộc khi khóa)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(makeActive ? 'Mở khóa' : 'Khóa'),
          ),
        ],
      ),
    );
    if (yes == true && (makeActive || reason.text.trim().isNotEmpty)) {
      try {
        await widget.api.patch('/api/superadmin/admins/${admin['id']}/active', {
          'active': makeActive,
          'reason': reason.text.trim(),
        }, auth: true);
        await load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
    reason.dispose();
  }

  Future<void> softDelete(Map<String, dynamic> admin) async {
    final reason = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Xóa quản trị viên?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tài khoản ${admin['email'] ?? 'quản trị viên'} sẽ bị khóa và giữ lại lịch sử.',
            ),
            TextField(
              controller: reason,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Lý do xóa (bắt buộc)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Xóa mềm'),
          ),
        ],
      ),
    );
    if (yes == true && reason.text.trim().isNotEmpty) {
      try {
        await widget.api.post('/api/superadmin/admins/${admin['id']}/delete', {
          'reason': reason.text.trim(),
        }, auth: true);
        await load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }
    reason.dispose();
  }

  Future<void> restore(Map<String, dynamic> admin) async {
    try {
      await widget.api.post(
        '/api/superadmin/admins/${admin['id']}/restore',
        {},
        auth: true,
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> detail(Map<String, dynamic> admin) async {
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(
          '${admin['fullName'] ?? 'Quản trị viên'} · ${admin['email'] ?? 'Chưa có email'}',
        ),
        content: Text(
          'Email: ${admin['email'] ?? 'Ch\u01b0a c\u00f3'} \u00b7 ${admin['isEmailVerified'] == true ? '\u0110\u00e3 x\u00e1c minh' : 'Ch\u01b0a x\u00e1c minh'}\n\u0110i\u1ec7n tho\u1ea1i: ${admin['phone'] ?? 'Ch\u01b0a c\u00f3'} \u00b7 ${admin['isPhoneVerified'] == true ? '\u0110\u00e3 x\u00e1c minh' : 'Ch\u01b0a x\u00e1c minh'}\nTr\u1ea1ng th\u00e1i: ${admin['isDeleted'] == true
              ? '\u0110\u00e3 x\u00f3a'
              : admin['isActive'] == true
              ? '\u0110ang ho\u1ea1t \u0111\u1ed9ng'
              : '\u0110ang kh\u00f3a'}\nNg\u00e0y t\u1ea1o: ${admin['createdAtUtc']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Quản lý quản trị viên'),
      actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => edit(),
      icon: const Icon(Icons.add),
      label: const Text('Thêm quản trị viên'),
      backgroundColor: ink,
      foregroundColor: Colors.white,
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: search,
                onSubmitted: (_) {
                  page = 1;
                  load();
                },
                decoration: InputDecoration(
                  labelText: 'Tìm tên hoặc email',
                  suffixIcon: IconButton(
                    onPressed: () {
                      page = 1;
                      load();
                    },
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Lọc trạng thái'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                  DropdownMenuItem(
                    value: 'active',
                    child: Text('Đang hoạt động'),
                  ),
                  DropdownMenuItem(value: 'locked', child: Text('Đang khóa')),
                  DropdownMenuItem(value: 'deleted', child: Text('Đã xóa')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    status = v;
                    page = 1;
                    load();
                  }
                },
              ),
            ],
          ),
        ),
        if (loading)
          const Expanded(
            child: Center(child: CircularProgressIndicator(color: green)),
          )
        else if (error != null)
          Expanded(
            child: Center(
              child: TextButton(
                onPressed: load,
                child: Text('Thử lại · $error'),
              ),
            ),
          )
        else if (admins.isEmpty)
          const Expanded(
            child: Center(child: Text('Không có quản trị viên phù hợp.')),
          )
        else
          Expanded(
            child: ListView(
              children: admins
                  .map(
                    (a) => Card(
                      child: ListTile(
                        onTap: () => detail(a),
                        leading: CircleAvatar(
                          child: Icon(
                            a['isDeleted'] == true
                                ? Icons.delete_outline
                                : a['isActive'] == true
                                ? Icons.admin_panel_settings_outlined
                                : Icons.lock_outline,
                          ),
                        ),
                        title: Text(
                          '${a['fullName'] ?? a['email']} · ${a['email'] ?? 'Chưa có email'}',
                        ),
                        subtitle: Text(
                          '${a['email'] ?? a['phone'] ?? 'Ch\u01b0a c\u00f3 li\u00ean h\u1ec7'} \u00b7 ${a['isEmailVerified'] == true || a['isPhoneVerified'] == true ? '\u0110\u00e3 x\u00e1c minh' : 'Ch\u01b0a x\u00e1c minh'}\n${a['isDeleted'] == true
                              ? '\u0110\u00e3 x\u00f3a'
                              : a['isActive'] == true
                              ? '\u0110ang ho\u1ea1t \u0111\u1ed9ng'
                              : '\u0110ang kh\u00f3a'} \u00b7 ${a['createdAtUtc']}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') edit(a);
                            if (v == 'lock') changeStatus(a);
                            if (v == 'delete') softDelete(a);
                            if (v == 'restore') restore(a);
                          },
                          itemBuilder: (_) => [
                            if (a['isDeleted'] != true)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Chỉnh sửa'),
                              ),
                            if (a['isDeleted'] != true)
                              PopupMenuItem(
                                value: 'lock',
                                child: Text(
                                  a['isActive'] == true ? 'Khóa' : 'Mở khóa',
                                ),
                              ),
                            if (a['isDeleted'] != true)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Xóa mềm'),
                              ),
                            if (a['isDeleted'] == true)
                              const PopupMenuItem(
                                value: 'restore',
                                child: Text('Khôi phục'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (!loading)
          Padding(
            padding: const EdgeInsets.only(bottom: 82),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: page > 1
                      ? () {
                          page--;
                          load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Trang $page · $total quản trị viên'),
                IconButton(
                  onPressed: page * pageSize < total
                      ? () {
                          page++;
                          load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class SuperAdminAdminEditor extends StatefulWidget {
  const SuperAdminAdminEditor({super.key, required this.api, this.admin});
  final ApiClient api;
  final Map<String, dynamic>? admin;
  @override
  State<SuperAdminAdminEditor> createState() => _SuperAdminAdminEditorState();
}

class _SuperAdminAdminEditorState extends State<SuperAdminAdminEditor> {
  late final TextEditingController fullName,
      email,
      phone,
      password,
      confirm,
      emailCode;
  bool active = true, busy = false, emailOtpSent = false;
  String? error;
  bool get isEdit => widget.admin != null;
  @override
  void initState() {
    super.initState();
    final a = widget.admin;
    fullName = TextEditingController(text: '${a?['fullName'] ?? ''}');
    email = TextEditingController(text: '${a?['email'] ?? ''}');
    phone = TextEditingController(text: '${a?['phone'] ?? ''}');
    password = TextEditingController();
    confirm = TextEditingController();
    emailCode = TextEditingController();
    active = a == null ? true : a['isActive'] != false;
  }

  @override
  void dispose() {
    for (final c in [fullName, email, phone, password, confirm, emailCode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (fullName.text.trim().isEmpty ||
        (!isEdit && email.text.trim().isEmpty)) {
      setState(() => error = 'Nhập họ tên và email.');
      return;
    }
    if (!isEdit &&
        (password.text != confirm.text || !_isPasswordValid(password.text))) {
      setState(
        () => error = password.text != confirm.text
            ? 'Mật khẩu xác nhận chưa khớp.'
            : _passwordRequirement,
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (isEdit) {
        await widget.api.patch(
          '/api/superadmin/admins/${widget.admin!['id']}',
          {
            'fullName': fullName.text.trim(),
            'reason': 'Cập nhật hồ sơ quản trị viên',
          },
          auth: true,
        );
      } else {
        await widget.api.post('/api/superadmin/admins', {
          'fullName': fullName.text.trim(),
          'email': email.text.trim(),
          'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
          'password': password.text,
          'active': active,
        }, auth: true);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> requestEmail() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post(
        '/api/superadmin/admins/${widget.admin!['id']}/email/request',
        {'email': email.text.trim()},
        auth: true,
      );
      setState(() => emailOtpSent = true);
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirmEmail() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.post(
        '/api/superadmin/admins/${widget.admin!['id']}/email/confirm',
        {'email': email.text.trim(), 'code': emailCode.text.trim()},
        auth: true,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(isEdit ? 'Chỉnh sửa quản trị viên' : 'Thêm quản trị viên'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: fullName,
          decoration: const InputDecoration(labelText: 'Họ tên'),
        ),
        const SizedBox(height: 10),
        if (!isEdit) ...[
          const SizedBox(height: 10),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email (bắt buộc)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại (tùy chọn, chưa xác minh)',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Quản trị viên dùng email và mật khẩu ngay khi tài khoản được bật. Không cần xác minh email lúc tạo; mã xác thực chỉ dùng khi đổi mật khẩu hoặc thông tin liên hệ.',
          ),
          const SizedBox(height: 10),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu ban đầu'),
          ),
          const SizedBox(height: 6),
          const Text(_passwordRequirement),
          const SizedBox(height: 10),
          TextField(
            controller: confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu'),
          ),
          SwitchListTile(
            value: active,
            onChanged: (v) => setState(() => active = v),
            title: const Text('Quản trị viên cấp cao duyệt quyền hoạt động'),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Text(
            'Email hiện tại: ${widget.admin?['email'] ?? 'Chưa có'} · ${widget.admin?['isEmailVerified'] == true ? 'Đã xác minh' : 'Chưa xác minh'}',
          ),
          const SizedBox(height: 8),
          Text(
            'Điện thoại: ${widget.admin?['phone'] ?? 'Chưa có'} · ${widget.admin?['isPhoneVerified'] == true ? 'Đã xác minh' : 'Chưa xác minh'}',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email cần xác minh bằng mã xác thực',
            ),
          ),
          if (emailOtpSent) ...[
            const SizedBox(height: 10),
            TextField(
              controller: emailCode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mã xác thực · 60 giây',
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: busy
                ? null
                : emailOtpSent
                ? confirmEmail
                : requestEmail,
            child: Text(
              emailOtpSent
                  ? 'Xác minh và cập nhật email'
                  : 'Gửi mã xác thực xác minh email mới',
            ),
          ),
        ],
        if (error != null) _ErrorBox(error!),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Đang lưu…' : 'Lưu'),
        ),
      ],
    ),
  );
}

class SuperAdminAuditPage extends StatefulWidget {
  const SuperAdminAuditPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<SuperAdminAuditPage> createState() => _SuperAdminAuditPageState();
}

class _SuperAdminAuditPageState extends State<SuperAdminAuditPage> {
  final search = TextEditingController();
  List<Map<String, dynamic>> admins = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final q = <String, String>{
        'page': '1',
        'pageSize': '100',
        'status': 'all',
      };
      if (search.text.trim().isNotEmpty) q['search'] = search.text.trim();
      final r = await widget.api.get(
        '/api/superadmin/admins?${Uri(queryParameters: q).query}',
        auth: true,
      );
      admins = (r['items'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openAdmin(Map<String, dynamic> admin) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SuperAdminAdminAuditPage(api: widget.api, admin: admin),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Chọn quản trị viên'),
      actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: search,
            onSubmitted: (_) => load(),
            decoration: InputDecoration(
              labelText: 'Tìm quản trị viên theo tên hoặc email',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: load,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
        ),
        if (loading)
          const Expanded(
            child: Center(child: CircularProgressIndicator(color: green)),
          )
        else if (error != null)
          Expanded(
            child: Center(
              child: TextButton(
                onPressed: load,
                child: Text('Thử lại · $error'),
              ),
            ),
          )
        else if (admins.isEmpty)
          const Expanded(
            child: Center(child: Text('Chưa có quản trị viên phù hợp.')),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: admins.length,
              itemBuilder: (context, index) {
                final admin = admins[index];
                final name = '${admin['fullName'] ?? ''}'.trim();
                final email = '${admin['email'] ?? 'Chưa có email'}';
                final status = admin['isDeleted'] == true
                    ? 'Đã xóa'
                    : admin['isActive'] == true
                    ? 'Đang hoạt động'
                    : 'Đang khóa';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    title: Text(name.isEmpty ? email : name),
                    subtitle: Text('$email · $status'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openAdmin(admin),
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );
}

class SuperAdminAdminAuditPage extends StatefulWidget {
  const SuperAdminAdminAuditPage({
    super.key,
    required this.api,
    required this.admin,
  });
  final ApiClient api;
  final Map<String, dynamic> admin;

  @override
  State<SuperAdminAdminAuditPage> createState() =>
      _SuperAdminAdminAuditPageState();
}

class _SuperAdminAdminAuditPageState extends State<SuperAdminAdminAuditPage> {
  List<Map<String, dynamic>> logs = [];
  int page = 1, total = 0;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final q = <String, String>{
        'actorId': '${widget.admin['id']}',
        'page': '$page',
        'pageSize': '20',
      };
      final r = await widget.api.get(
        '/api/superadmin/audit-logs?${Uri(queryParameters: q).query}',
        auth: true,
      );
      logs = (r['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      total = r['total'] as int? ?? 0;
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = '${widget.admin['fullName'] ?? ''}'.trim();
    final email = '${widget.admin['email'] ?? 'Qu?n tr? vi?n'}';
    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? 'Nhật ký quản trị viên' : 'Nhật ký · $name'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                email,
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
          ),
          if (loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: green)),
            )
          else if (error != null)
            Expanded(
              child: Center(
                child: TextButton(
                  onPressed: load,
                  child: Text('Thử lại · $error'),
                ),
              ),
            )
          else if (logs.isEmpty)
            const Expanded(
              child: Center(
                child: Text('Quản trị viên này chưa có thao tác nào.'),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final x = logs[index];
                  return Card(
                    child: ExpansionTile(
                      title: Text(
                        '${_auditActionLabel(x['action'])} · ${_auditOutcomeLabel(x['outcome'])}',
                      ),
                      subtitle: Text(
                        '→ ${x['targetName'] ?? '—'}\n${x['createdAtUtc']}',
                      ),
                      childrenPadding: const EdgeInsets.all(14),
                      children: [
                        if ('${x['reason'] ?? ''}'.isNotEmpty)
                          ListTile(
                            title: const Text('Lý do'),
                            subtitle: Text('${x['reason']}'),
                          ),
                        if (x['beforeJson'] != null)
                          ListTile(
                            title: const Text('Trước'),
                            subtitle: SelectableText('${x['beforeJson']}'),
                          ),
                        if (x['afterJson'] != null)
                          ListTile(
                            title: const Text('Sau'),
                            subtitle: SelectableText('${x['afterJson']}'),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (!loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: page > 1
                        ? () {
                            page--;
                            load();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Trang $page · $total thao tác'),
                  IconButton(
                    onPressed: page * 20 < total
                        ? () {
                            page++;
                            load();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final search = TextEditingController();
  List<dynamic> users = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final suffix = search.text.trim().isEmpty
          ? ''
          : '?search=${Uri.encodeQueryComponent(search.text.trim())}';
      final r = await widget.api.get('/api/admin/users$suffix', auth: true);
      users = r['data'] as List<dynamic>? ?? [];
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> detail(String id) async {
    try {
      final x = await widget.api.get('/api/admin/users/$id', auth: true);
      if (!mounted) return;
      final profile = x['profile'];
      await showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(
            '${x['username'] ?? x['email'] ?? x['phone'] ?? 'Tài khoản'}',
          ),
          content: SingleChildScrollView(
            child: Text(
              'Vai trò: ${_roleLabel(x['role'])}\nTrạng thái: ${x['isActive'] == true ? 'Đang hoạt động' : 'Đã khóa'}\nEmail xác minh: ${x['isEmailVerified'] == true ? 'Rồi' : 'Chưa'}\nNgày tạo: ${x['createdAtUtc']}\nHồ sơ: ${profile == null ? 'Chưa khai báo' : profile['fullName'] ?? 'Đã khai báo'}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> setActive(Map<String, dynamic> u) async {
    try {
      await widget.api.patch('/api/admin/users/${u['id']}/active', {
        'active': u['isActive'] != true,
        'reason': 'Cập nhật từ giao diện quản trị',
      }, auth: true);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> remove(Map<String, dynamic> u) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Xóa tài khoản'),
        content: TextField(
          controller: reason,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Lý do xóa (bắt buộc)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || reason.text.trim().isEmpty) {
      reason.dispose();
      return;
    }
    try {
      await widget.api.delete(
        '/api/admin/users/${u['id']}',
        auth: true,
        body: {'reason': reason.text.trim()},
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      reason.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Người dùng'),
      actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: search,
            onSubmitted: (_) => load(),
            decoration: InputDecoration(
              labelText: 'Tìm email hoặc số điện thoại',
              suffixIcon: IconButton(
                onPressed: load,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
        ),
        if (loading)
          const Expanded(
            child: Center(child: CircularProgressIndicator(color: green)),
          )
        else if (error != null)
          Expanded(
            child: Center(
              child: TextButton(
                onPressed: load,
                child: Text('Thử lại · $error'),
              ),
            ),
          )
        else if (users.isEmpty)
          const Expanded(child: Center(child: Text('Chưa có tài khoản.')))
        else
          Expanded(
            child: ListView(
              children: users.map((raw) {
                final u = raw as Map<String, dynamic>;
                return ListTile(
                  onTap: () => detail('${u['id']}'),
                  leading: CircleAvatar(
                    child: Icon(
                      u['isActive'] == true
                          ? Icons.person_outline
                          : Icons.block,
                    ),
                  ),
                  title: Text(
                    '${u['username'] ?? u['email'] ?? u['phone'] ?? 'Chưa có liên hệ'}',
                  ),
                  subtitle: Text(
                    '${_roleLabel(u['role'])} · ${u['isActive'] == true ? 'Đang hoạt động' : 'Đã khóa'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'active') setActive(u);
                      if (v == 'delete') remove(u);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'active',
                        child: Text(u['isActive'] == true ? 'Khóa' : 'Mở khóa'),
                      ),
                      const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    ),
  );
}

const _nutritionFields = <(String, String)>[
  ('EnergyKcal', 'Năng lượng (Calories) · kcal'),
  ('ProteinG', 'Protein (Chất đạm) · g'),
  ('CarbohydrateG', 'Carbohydrate (Tinh bột và đường) · g'),
  ('FatG', 'Total Fat (Chất béo tổng) · g'),
  ('FiberG', 'Fiber (Chất xơ) · g'),
  ('SugarG', 'Total Sugars (Đường tổng) · g'),
  ('SaturatedFatG', 'Saturated Fat (Chất béo bão hòa) · g'),
  ('SodiumMg', 'Sodium (Natri) · mg'),
];

String _nutritionJsonKey(String fieldName) =>
    '${fieldName[0].toLowerCase()}${fieldName.substring(1)}';

class AdminDishesPage extends StatefulWidget {
  const AdminDishesPage({
    super.key,
    required this.api,
    required this.isSuperAdmin,
    this.trashOnly = false,
  });
  final ApiClient api;
  final bool isSuperAdmin;
  final bool trashOnly;
  @override
  State<AdminDishesPage> createState() => _AdminDishesPageState();
}

class _AdminDishesPageState extends State<AdminDishesPage> {
  final search = TextEditingController();
  List<Map<String, dynamic>> dishes = [];
  bool trash = false, loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    trash = widget.trashOnly;
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final query = Uri(
        queryParameters: {
          if (trash) 'status': 'Trash',
          if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
        },
      ).query;
      final response = await widget.api.get(
        '/api/admin/dishes?$query',
        auth: true,
      );
      dishes = ((response['data'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>();
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> edit([Map<String, dynamic>? dish]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDishEditorPage(api: widget.api, dish: dish),
      ),
    );
    if (saved == true) load();
  }

  Future<void> detail(Map<String, dynamic> dish) async {
    try {
      final result = await widget.api.get(
        '/api/admin/dishes/${dish['id']}',
        auth: true,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
            child: AdminDishDetail(dish: result),
          ),
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> deleteDish(Map<String, dynamic> dish) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Chuy\u1ec3n m\u00f3n v\u00e0o th\u00f9ng r\u00e1c?'),
        content: Text(
          '\u201c${dish['name']}\u201d s\u1ebd \u0111\u01b0\u1ee3c x\u00f3a m\u1ec1m.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('H\u1ee7y'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('X\u00f3a'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await widget.api.delete('/api/admin/dishes/${dish['id']}', auth: true);
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> restore(Map<String, dynamic> dish) async {
    try {
      await widget.api.post(
        '/api/admin/dishes/${dish['id']}/restore',
        {},
        auth: true,
      );
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(trash ? 'Thùng Rác - Món ăn' : 'Quản lý món ăn'),
      actions: [
        IconButton(
          tooltip: trash ? 'Danh sách món' : 'Thùng rác',
          onPressed: () {
            setState(() => trash = !trash);
            load();
          },
          icon: Icon(trash ? Icons.menu_book_outlined : Icons.delete_outline),
        ),
      ],
    ),
    floatingActionButton: trash
        ? null
        : FloatingActionButton.extended(
            onPressed: () => edit(),
            icon: const Icon(Icons.add),
            label: const Text('Thêm món ăn'),
          ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => load(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Tìm theo tên món',
              suffixIcon: IconButton(
                onPressed: load,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: load,
                        child: const Text('Th\u1eed l\u1ea1i'),
                      ),
                    ],
                  ),
                )
              : dishes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          size: 54,
                          color: green,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          trash ? 'Thùng rác đang trống' : 'Chưa có món ăn',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!trash) ...[
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: () => edit(),
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm món ăn'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                    itemCount: dishes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final d = dishes[index];
                      final ingredients =
                          (d['ingredients'] as List<dynamic>? ?? [])
                              .map((x) => '${x['name']}')
                              .toList();
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${d['name'] ?? ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ingredients.isEmpty
                                    ? 'Chưa có nguyên liệu liên kết'
                                    : ingredients.join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                d['isDeleted'] == true
                                    ? 'Thùng rác'
                                    : d['status'] == 'Published'
                                    ? 'Đã công bố'
                                    : 'Nháp',
                                style: const TextStyle(
                                  color: green,
                                  fontSize: 12,
                                ),
                              ),
                              if (trash && widget.isSuperAdmin) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'X\u00f3a b\u1edfi: ${d['deletedByName'] ?? 'Kh\u00f4ng r\u00f5'}${d['deletedByEmail'] == null ? '' : ' \u00b7 ${d['deletedByEmail']}'}${d['deletedAtUtc'] == null ? '' : ' \u00b7 ${d['deletedAtUtc']}'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 4,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => detail(d),
                                    icon: const Icon(Icons.visibility_outlined),
                                    label: const Text('Xem'),
                                  ),
                                  if (d['isDeleted'] == true) ...[
                                    if (widget.isSuperAdmin)
                                      TextButton.icon(
                                        onPressed: () => restore(d),
                                        icon: const Icon(Icons.restore),
                                        label: const Text(
                                          'Kh\u00f4i ph\u1ee5c',
                                        ),
                                      ),
                                  ] else ...[
                                    TextButton.icon(
                                      onPressed: () => edit(d),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('S\u1eeda'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => deleteDish(d),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      label: const Text(
                                        'X\u00f3a',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  );
}

class AdminDishEditorPage extends StatefulWidget {
  const AdminDishEditorPage({super.key, required this.api, this.dish});
  final ApiClient api;
  final Map<String, dynamic>? dish;
  @override
  State<AdminDishEditorPage> createState() => _AdminDishEditorPageState();
}

class _AdminDishEditorPageState extends State<AdminDishEditorPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(), notes = TextEditingController();
  List<Map<String, dynamic>> foods = [], selectedFoods = [];
  bool busy = true, saving = false;
  String? error;
  String? dishId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final d = widget.dish;
    if (d != null) {
      dishId = d['id']?.toString();
      name.text = d['name'] ?? '';
      notes.text = d['cookingNotes'] ?? '';
    }
    try {
      final result = await widget.api.get(
        '/api/admin/dishes/food-options',
        auth: true,
      );
      foods = ((result['data'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>();
      if (d != null) {
        final existing = ((d['ingredients'] as List<dynamic>?) ?? [])
            .cast<Map<String, dynamic>>();
        selectedFoods = existing.map((x) {
          final foodId = x['foodId'];
          final food = foods.where((f) => f['id'] == foodId).firstOrNull;
          return <String, dynamic>{
            ...?food,
            'id': foodId,
            'name':
                food?['name'] ??
                x['name'] ??
                'Nguy\u00ean li\u1ec7u ch\u01b0a kh\u1edbp',
            'groupName': food?['groupName'],
            'unmatched': foodId == null,
            'amountInstruction': '${x['amountInstruction'] ?? ''}',
          };
        }).toList();
      }
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    name.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> chooseFood({int? replaceIndex}) async {
    final search = TextEditingController();
    final selectedIds = selectedFoods.map((x) => x['id']).toSet();
    ModalRoute<dynamic>? pickerRoute;
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        pickerRoute = ModalRoute.of(sheetContext);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final q = search.text.trim().toLowerCase();
            final available = foods
                .where(
                  (f) =>
                      !selectedIds.contains(f['id']) &&
                      '${f['name']}'.toLowerCase().contains(q),
                )
                .toList();
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: search,
                        autofocus: true,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Tìm thực phẩm có sẵn',
                        ),
                      ),
                    ),
                    Expanded(
                      child: available.isEmpty
                          ? const Center(
                              child: Text(
                                'Không tìm thấy thực phẩm trong danh mục.',
                              ),
                            )
                          : ListView.builder(
                              itemCount: available.length,
                              itemBuilder: (_, i) => ListTile(
                                title: Text('${available[i]['name']}'),
                                subtitle: available[i]['groupName'] == null
                                    ? null
                                    : Text('${available[i]['groupName']}'),
                                onTap: () =>
                                    Navigator.pop(context, available[i]),
                              ),
                            ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (pickerRoute != null) await pickerRoute!.completed;
    search.dispose();
    if (chosen != null && mounted) {
      setState(() {
        if (replaceIndex == null) {
          selectedFoods.add({...chosen, 'amountInstruction': ''});
        } else {
          final amount = selectedFoods[replaceIndex]['amountInstruction'];
          selectedFoods[replaceIndex] = {
            ...chosen,
            'amountInstruction': amount,
          };
        }
      });
    }
  }

  String _amountWithGramUnit(Object? value) {
    final amount = '${value ?? ''}'.trim();
    if (amount.isEmpty ||
        RegExp(r'\s*g\s*$', caseSensitive: false).hasMatch(amount)) {
      return amount;
    }
    return '$amount g';
  }

  Future<void> save(String targetStatus) async {
    if (!formKey.currentState!.validate()) return;
    if (targetStatus == 'Published') {
      if (selectedFoods.isEmpty) {
        setState(() => error = 'Món công bố cần có nguyên liệu.');
        return;
      }
      if (selectedFoods.any((food) => food['id'] == null)) {
        setState(
          () => error = 'Hãy liên kết nguyên liệu chưa khớp với thực phẩm trước khi công bố.',
        );
        return;
      }
      final hasInvalidAmount = selectedFoods.any((food) {
        final text = '${food['amountInstruction'] ?? ''}'
            .replaceAll(RegExp(r'\s*g\s*$', caseSensitive: false), '')
            .trim()
            .replaceAll(',', '.');
        final grams = double.tryParse(text);
        return grams == null || grams <= 0;
      });
      if (hasInvalidAmount) {
        setState(
          () => error =
              'Nhập số gram lớn hơn 0 cho từng nguyên liệu trước khi công bố.',
        );
        return;
      }
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final payload = {
        'name': name.text.trim(),
        'ingredients': selectedFoods
            .map(
              (x) => {
                'foodId': x['id'],
                'amountInstruction': targetStatus == 'Published'
                    ? _amountWithGramUnit(x['amountInstruction'])
                    : '${x['amountInstruction'] ?? ''}'.trim(),
                'ingredientName': x['id'] == null ? x['name'] : null,
              },
            )
            .toList(),
        'cookingNotes': notes.text.trim(),
        'status': targetStatus,
      };
      if (dishId == null) {
        final result = await widget.api.post(
          '/api/admin/dishes',
          payload,
          auth: true,
        );
        dishId = (result['id'] ?? (result['data'] as Map?)?['id'])?.toString();
      } else {
        await widget.api.put('/api/admin/dishes/$dishId', payload, auth: true);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.dish == null ? 'Thêm món ăn' : 'Sửa món ăn'),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: saving ? null : () => Navigator.pop(context, false),
                child: const Text('H\u1ee7y'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: saving ? null : () => save('Draft'),
                child: const Text('L\u01b0u nh\u00e1p'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: saving ? null : () => save('Published'),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('C\u00f4ng b\u1ed1'),
              ),
            ),
          ],
        ),
      ),
    ),
    body: busy
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                TextFormField(
                  controller: name,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'T\u00ean m\u00f3n \u0103n *',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Vui l\u00f2ng nh\u1eadp t\u00ean m\u00f3n \u0103n.'
                      : null,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Nguy\u00ean li\u1ec7u',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ch\u1ecdn t\u1eeb danh m\u1ee5c th\u1ef1c ph\u1ea9m hi\u1ec7n c\u00f3.',
                ),
                const SizedBox(height: 8),
                if (selectedFoods.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Ch\u01b0a ch\u1ecdn nguy\u00ean li\u1ec7u.'),
                  ),
                ...selectedFoods.asMap().entries.map(
                  (entry) => Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.value['name']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (entry.value['groupName'] != null)
                                  Text(
                                    '${entry.value['groupName']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                if (entry.value['unmatched'] == true)
                                  const Text(
                                    'Ch\u01b0a kh\u1edbp FoodID \u00b7 ch\u1edd Admin r\u00e0 so\u00e1t',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.deepOrange,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  initialValue:
                                      '${entry.value['amountInstruction'] ?? ''}'
                                          .replaceAll(
                                            RegExp(
                                              r'\s*g\s*$',
                                              caseSensitive: false,
                                            ),
                                            '',
                                          ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Gram chu\u1ea9n cho 1 ng\u01b0\u1eddi',
                                    suffixText: 'g',
                                  ),
                                  onChanged: (value) =>
                                      selectedFoods[entry
                                          .key]['amountInstruction'] = value
                                          .trim(),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'L\u00ean th\u1ee9 t\u1ef1',
                                onPressed: entry.key == 0
                                    ? null
                                    : () => setState(() {
                                        final item = selectedFoods.removeAt(
                                          entry.key,
                                        );
                                        selectedFoods.insert(
                                          entry.key - 1,
                                          item,
                                        );
                                      }),
                                icon: const Icon(Icons.arrow_upward),
                              ),
                              IconButton(
                                tooltip: 'Xu\u1ed1ng th\u1ee9 t\u1ef1',
                                onPressed: entry.key == selectedFoods.length - 1
                                    ? null
                                    : () => setState(() {
                                        final item = selectedFoods.removeAt(
                                          entry.key,
                                        );
                                        selectedFoods.insert(
                                          entry.key + 1,
                                          item,
                                        );
                                      }),
                                icon: const Icon(Icons.arrow_downward),
                              ),
                              if (entry.value['unmatched'] == true)
                                IconButton(
                                  tooltip:
                                      'Gh\u00e9p v\u1edbi th\u1ef1c ph\u1ea9m',
                                  onPressed: () =>
                                      chooseFood(replaceIndex: entry.key),
                                  icon: const Icon(Icons.link),
                                ),
                              IconButton(
                                tooltip: 'B\u1ecf nguy\u00ean li\u1ec7u',
                                onPressed: () => setState(
                                  () => selectedFoods.removeAt(entry.key),
                                ),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: foods.isEmpty ? null : chooseFood,
                  icon: const Icon(Icons.add),
                  label: const Text('Th\u00eam nguy\u00ean li\u1ec7u'),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: notes,
                  minLines: 5,
                  maxLines: 12,
                  maxLength: 8000,
                  decoration: const InputDecoration(
                    labelText: 'Ghi ch\u00fa / C\u00e1ch n\u1ea5u',
                    alignLabelWithHint: true,
                    hintText: 'Nh\u1eadp h\u01b0\u1edbng d\u1eabn ch\u1ebf bi\u1ebfn...',
                  ),
                ),
                const SizedBox(height: 78),
              ],
            ),
          ),
  );
}

class AdminDishDetail extends StatelessWidget {
  const AdminDishDetail({super.key, required this.dish});
  final Map<String, dynamic> dish;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppBar(
        title: const Text('Chi tiết món ăn'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              '${dish['name'] ?? ''}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nguy\u00ean li\u1ec7u',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...((dish['ingredients'] as List<dynamic>? ?? []).map(
              (x) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle, size: 8, color: green),
                title: Text('${x['name'] ?? ''}'),
                trailing: Text('${x['amountInstruction'] ?? ''}'),
              ),
            )),
            if ((dish['cookingNotes'] ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Ghi ch\u00fa / C\u00e1ch n\u1ea5u',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text('${dish['cookingNotes']}'),
            ],
          ],
        ),
      ),
    ],
  );
}

class AdminFoodsPage extends StatefulWidget {
  const AdminFoodsPage({
    super.key,
    required this.api,
    required this.isSuperAdmin,
    this.trashOnly = false,
  });
  final ApiClient api;
  final bool isSuperAdmin;
  final bool trashOnly;
  @override
  State<AdminFoodsPage> createState() => _AdminFoodsPageState();
}

class _AdminFoodsPageState extends State<AdminFoodsPage> {
  bool loading = true;
  List<dynamic> foods = [];
  List<dynamic> allFoods = [];
  List<dynamic> trashFoods = [];
  List<dynamic> groups = [];
  String? selectedGroupId;
  String selectedView = 'all';
  final search = TextEditingController();
  String? error;
  @override
  void initState() {
    super.initState();
    if (widget.trashOnly) selectedView = 'trash';
    load();
  }

  bool hasCoreNutrition(Map<String, dynamic> food) {
    final nutrition = food['nutrition'];
    if (nutrition is! Map) return false;
    for (final field in const [
      'energyKcal',
      'proteinG',
      'carbohydrateG',
      'fatG',
    ]) {
      final value = nutrition[field];
      if (value is! num || value < 0) return false;
    }
    return true;
  }

  int nutritionCount(Map<String, dynamic> food) {
    final nutrition = food['nutrition'];
    if (nutrition is! Map) return 0;
    return _nutritionFields.where((field) {
      final value = nutrition[_nutritionJsonKey(field.$1)];
      return value is num && value >= 0;
    }).length;
  }

  bool hasCompleteNutrition(Map<String, dynamic> food) =>
      nutritionCount(food) == _nutritionFields.length;

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final responses = await Future.wait([
        widget.api.get('/api/admin/foods/pending', auth: true),
        widget.api.get('/api/admin/foods/verified', auth: true),
        widget.api.get('/api/admin/foods/trash', auth: true),
        widget.api.get('/api/admin/food-groups', auth: true),
      ]);
      allFoods = [
        ...(responses[0]['data'] as List<dynamic>? ?? []),
        ...(responses[1]['data'] as List<dynamic>? ?? []),
      ];
      trashFoods = responses[2]['data'] as List<dynamic>? ?? [];
      groups = responses[3]['data'] as List<dynamic>? ?? [];
      foods = switch (selectedView) {
        'unverified' =>
          allFoods
              .where((f) => !hasCompleteNutrition(f as Map<String, dynamic>))
              .toList(),
        'trash' => trashFoods,
        _ => allFoods,
      };
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verify(Map<String, dynamic> food) async {
    try {
      await widget.api.post(
        '/api/admin/foods/${food['id']}/verify',
        {},
        auth: true,
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> sourceCheck(
    Map<String, dynamic> food,
    Map<String, dynamic> source,
  ) async {
    try {
      final rows = (food['sources'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final targets = rows.where(
        (row) =>
            row['citation'] == source['citation'] &&
            row['url'] == source['url'],
      );
      for (final row in targets.isEmpty ? [source] : targets) {
        await widget.api.patch(
          '/api/admin/foods/${food['id']}/sources/${row['id']}',
          {'checked': source['isChecked'] != true},
          auth: true,
        );
      }
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> removeFood(Map<String, dynamic> food) async {
    var secondsLeft = 5;
    var countdownStarted = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!countdownStarted) {
            countdownStarted = true;
            unawaited(() async {
              while (secondsLeft > 0 && dialogContext.mounted) {
                await Future<void>.delayed(const Duration(seconds: 1));
                if (!dialogContext.mounted) return;
                setDialogState(() => secondsLeft--);
              }
            }());
          }
          return AlertDialog(
            title: const Text('Chuyển thực phẩm vào thùng rác?'),
            content: Text(
              '${food['name']} s\\u1ebd \u0111\\u01b0\\u1ee3c chuy\\u1ec3n v\\u00e0o th\\u00f9ng r\\u00e1c. SuperAdmin c\\u00f3 th\\u1ec3 kh\\u00f4i ph\\u1ee5c ho\\u1eb7c x\\u00f3a v\\u0129nh vi\\u1ec5n.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('H\\u1ee7y'),
              ),
              FilledButton(
                onPressed: secondsLeft == 0
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: Text(
                  secondsLeft == 0
                      ? 'Chuy\\u1ec3n v\\u00e0o th\\u00f9ng r\\u00e1c'
                      : 'Ch\\u1edd ${secondsLeft}s',
                ),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.delete('/api/admin/foods/${food['id']}', auth: true);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> restoreFood(Map<String, dynamic> food) async {
    try {
      await widget.api.post(
        '/api/admin/foods/${food['id']}/restore',
        {},
        auth: true,
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> permanentlyDeleteFood(Map<String, dynamic> food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('X\u00f3a v\u0129nh vi\u1ec5n?'),
        content: Text(
          'Th\u1ef1c ph\u1ea9m ${food['name']}, ngu\u1ed3n dinh d\u01b0\u1ee1ng v\u00e0 \u1ea3nh s\u1ebd b\u1ecb x\u00f3a ho\u00e0n to\u00e0n. Kh\u00f4ng th\u1ec3 kh\u00f4i ph\u1ee5c sau thao t\u00e1c n\u00e0y.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('H\u1ee7y'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('X\u00f3a v\u0129nh vi\u1ec5n'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.delete(
        '/api/admin/foods/${food['id']}/permanent',
        auth: true,
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> editor([Map<String, dynamic>? food]) async {
    var editableFood = food;
    if (food != null) {
      try {
        editableFood = await widget.api.get(
          '/api/admin/foods/${food['id']}',
          auth: true,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
        return;
      }
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminFoodEditor(
          api: widget.api,
          groups: groups,
          food: editableFood,
        ),
      ),
    );
    await load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<dynamic> get visibleFoods => foods.where((raw) {
    final f = raw as Map<String, dynamic>;
    final groupOk =
        selectedGroupId == null ||
        '${f['foodGroupId'] ?? ''}' == selectedGroupId;
    final query = search.text.trim().toLowerCase();
    return groupOk &&
        (query.isEmpty || '${f['name']}'.toLowerCase().contains(query));
  }).toList();

  int _countForSelectedGroup(Iterable<dynamic> rows) {
    if (selectedGroupId == null) return rows.length;
    return rows.where((raw) {
      final food = raw as Map<String, dynamic>;
      return '${food['foodGroupId'] ?? ''}' == selectedGroupId;
    }).length;
  }

  Widget _foodGroupCard(String? id, String title, String code, int count) {
    final active = selectedGroupId == id;
    return SizedBox(
      width: 154,
      child: Card(
        color: active ? green : Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => selectedGroupId = id),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(
                  id == null ? Icons.apps : Icons.restaurant,
                  color: active ? Colors.white : ink,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : ink,
                        ),
                      ),
                      Text(
                        '$code | $count',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: active ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> manageGroups() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) {
          Future<void> reloadGroups() async {
            final r = await widget.api.get(
              '/api/admin/food-groups',
              auth: true,
            );
            groups = r['data'] as List<dynamic>? ?? [];
            if (mounted) setState(() {});
            refresh(() {});
          }

          Future<void> editGroup(Map<String, dynamic> group) async {
            final controller = TextEditingController(text: '${group['name']}');
            final value = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sua t?n nh?m'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'T?n nh?m'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Huy'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                    child: const Text('Luu'),
                  ),
                ],
              ),
            );
            controller.dispose();
            if (value == null || value.isEmpty) return;
            await widget.api.put('/api/admin/food-groups/${group['id']}', {
              'name': value,
            }, auth: true);
            await reloadGroups();
          }

          Future<void> deleteGroup(Map<String, dynamic> group) async {
            try {
              await widget.api.delete(
                '/api/admin/food-groups/${group['id']}',
                auth: true,
              );
              if (selectedGroupId == '${group['id']}') selectedGroupId = null;
              await reloadGroups();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          }

          Future<void> addGroup() async {
            final code = TextEditingController(),
                name = TextEditingController();
            final result = await showDialog<(String, String)>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Them nhom thuc pham'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: code,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'M? nh?m',
                        helperText: 'M? nh?m gi? c? ??nh sau khi t?o',
                      ),
                    ),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'T?n nh?m'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Huy'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, (
                      code.text.trim(),
                      name.text.trim(),
                    )),
                    child: const Text('Th?m'),
                  ),
                ],
              ),
            );
            code.dispose();
            name.dispose();
            if (result == null) return;
            try {
              await widget.api.post('/api/admin/food-groups', {
                'code': result.$1,
                'name': result.$2,
              }, auth: true);
              await reloadGroups();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          }

          return AlertDialog(
            title: const Text('Quan ly nhom thuc pham'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Them nhom m?i, s?a t?n ho?c x?a nh?m tr?ng. M? nh?m gi? c? ??nh sau khi t?o.',
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: groups.map((raw) {
                        final g = raw as Map<String, dynamic>;
                        return ListTile(
                          title: Text('${g['name']}'),
                          subtitle: Text(
                            '${g['code']} | ${g['foodCount']} thuc pham',
                          ),
                          trailing: Wrap(
                            children: [
                              TextButton(
                                onPressed: () => editGroup(g),
                                child: const Text('Sua'),
                              ),
                              TextButton(
                                onPressed: () => deleteGroup(g),
                                child: const Text(
                                  'Xoa',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Dong'),
              ),
              FilledButton.icon(
                onPressed: addGroup,
                icon: const Icon(Icons.add),
                label: const Text('Them nhom'),
              ),
            ],
          );
        },
      ),
    );
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.trashOnly ? 'Thùng Rác - Thực phẩm' : 'Thực phẩm'),
      actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
    ),
    floatingActionButton: (widget.trashOnly || selectedView == 'trash')
        ? null
        : FloatingActionButton.extended(
            onPressed: () => editor(),
            backgroundColor: ink,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Thêm'),
          ),
    body: Column(
      children: [
        if (!widget.trashOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Nh\u00f3m th\u1ef1c ph\u1ea9m',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                  ),
                ),
                Text(
                  '${foods.length} th\u1ef1c ph\u1ea9m',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: manageGroups,
                  icon: const Icon(Icons.grid_view, size: 16),
                  label: const Text('Qu\u1ea3n l\u00fd nh\u00f3m'),
                ),
              ],
            ),
          ),
        if (!widget.trashOnly)
          SizedBox(
            height: 82,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _foodGroupCard(
                  null,
                  'T\u1ea5t c\u1ea3',
                  '${groups.length} nh\u00f3m',
                  foods.length,
                ),
                ...groups.map((raw) {
                  final g = raw as Map<String, dynamic>;
                  final count = foods
                      .where(
                        (f) =>
                            '${(f as Map<String, dynamic>)['foodGroupId'] ?? ''}' ==
                            '${g['id']}',
                      )
                      .length;
                  return _foodGroupCard(
                    '${g['id']}',
                    '${g['name']}',
                    '${g['code']}',
                    count,
                  );
                }),
              ],
            ),
          ),
        if (!widget.trashOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'all',
                  label: Text(
                    'T\u1ea5t c\u1ea3 (${_countForSelectedGroup(allFoods)})',
                  ),
                ),
                ButtonSegment(
                  value: 'unverified',
                  label: Text(
                    'X\u00e1c minh ho\u00e0n ch\u1ec9nh 8 ch\u1ec9 ti\u00eau (${_countForSelectedGroup(allFoods.where((f) => !hasCompleteNutrition(f as Map<String, dynamic>)))})',
                  ),
                ),
              ],
              selected: {selectedView},
              onSelectionChanged: (selection) => setState(() {
                selectedView = selection.first;
                foods = switch (selectedView) {
                  'unverified' =>
                    allFoods
                        .where(
                          (f) =>
                              !hasCompleteNutrition(f as Map<String, dynamic>),
                        )
                        .toList(),
                  'trash' => trashFoods,
                  _ => allFoods,
                };
              }),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'T\u00ecm theo t\u00ean ho\u1eb7c m\u00e3 th\u1ef1c ph\u1ea9m...',
              isDense: true,
            ),
          ),
        ),
        if (loading)
          const Expanded(
            child: Center(child: CircularProgressIndicator(color: green)),
          )
        else if (error != null)
          Expanded(
            child: Center(
              child: TextButton(
                onPressed: load,
                child: Text('Thử lại · $error'),
              ),
            ),
          )
        else if (visibleFoods.isEmpty)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: green,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    selectedView == 'trash'
                        ? 'Th\u00f9ng r\u00e1c tr\u1ed1ng'
                        : selectedView == 'unverified'
                        ? 'Kh\u00f4ng c\u00f3 th\u1ef1c ph\u1ea9m c\u1ea7n ho\u00e0n ch\u1ec9nh x\u00e1c minh 8 ch\u1ec9 ti\u00eau'
                        : foods.isEmpty
                        ? 'Danh muc dang cho nguyen lieu dau tien'
                        : 'Khong co thuc pham phu hop',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  if (foods.isEmpty && selectedView != 'trash')
                    FilledButton.icon(
                      onPressed: groups.isEmpty ? null : () => editor(),
                      icon: const Icon(Icons.add),
                      label: const Text('Them thuc pham dau tien'),
                    ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              children: visibleFoods.map((raw) {
                final f = raw as Map<String, dynamic>;
                final nutritionFieldNames = _nutritionFields
                    .map((field) => field.$1)
                    .toSet();
                final sourceRows = (f['sources'] as List<dynamic>? ?? [])
                    .cast<Map<String, dynamic>>()
                    .where(
                      (source) =>
                          nutritionFieldNames.contains(source['fieldName']) ||
                          source['fieldName'] == 'FoodInfo',
                    )
                    .toList();
                final sharedSources = sourceRows
                    .where((source) => source['fieldName'] == 'FoodInfo')
                    .toList();
                final sources = sharedSources.isNotEmpty
                    ? [sharedSources.first]
                    : (sourceRows.isNotEmpty
                          ? [sourceRows.first]
                          : <Map<String, dynamic>>[]);
                final count = nutritionCount(f);
                return ExpansionTile(
                  showTrailingIcon: false,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: f['hasImage'] == true
                        ? Image.network(
                            '${ApiConfig.baseUrl}/api/admin/foods/${f['id']}/image',
                            headers: {
                              'Authorization':
                                  'Bearer ${widget.api.accessToken ?? ''}',
                            },
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(
                                Icons.restaurant_outlined,
                                color: green,
                              ),
                            ),
                          )
                        : const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              Icons.restaurant_outlined,
                              color: green,
                            ),
                          ),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text('${f['name']}')),
                      if (selectedView != 'trash') ...[
                        PopupMenuButton<String>(
                          tooltip:
                              'S\u1eeda ho\u1eb7c x\u00f3a th\u1ef1c ph\u1ea9m',
                          icon: const Icon(Icons.edit_outlined),
                          onSelected: (action) {
                            if (action == 'edit') {
                              editor(f);
                            } else if (action == 'delete') {
                              removeFood(f);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('S\u1eeda'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('X\u00f3a'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  subtitle: selectedView == 'unverified'
                      ? Text(
                          '$count/8 ch\u1ec9 ti\u00eau, c\u1ea7n ho\u00e0n thi\u1ec7n',
                        )
                      : null,
                  children: [
                    if (selectedView != 'trash')
                      ...sources.map((s) {
                        final citation = '${s['citation'] ?? ''}'.trim();
                        return CheckboxListTile(
                          value: s['isChecked'] == true,
                          title: Text(
                            citation.isEmpty
                                ? 'Nguon trich dan chung'
                                : citation,
                          ),
                          subtitle: Text('${s['url']}'),
                          onChanged: (_) => sourceCheck(f, s),
                        );
                      }),
                    if (selectedView == 'trash' && widget.isSuperAdmin) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Ng\u01b0\u1eddi x\u00f3a: ${f['deletedByName'] ?? f['deletedByRole'] ?? 'Admin'}${f['deletedByEmail'] == null ? '' : ' \u00b7 ${f['deletedByEmail']}'} \u00b7 ${f['deletedAtUtc'] ?? ''}',
                        ),
                      ),
                      if (widget.isSuperAdmin)
                        Wrap(
                          children: [
                            TextButton.icon(
                              onPressed: () => restoreFood(f),
                              icon: const Icon(Icons.restore),
                              label: const Text('Kh\u00f4i ph\u1ee5c'),
                            ),
                            TextButton.icon(
                              onPressed: () => permanentlyDeleteFood(f),
                              icon: const Icon(
                                Icons.delete_forever,
                                color: Colors.red,
                              ),
                              label: const Text(
                                'X\u00f3a v\u0129nh vi\u1ec5n',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Ch\u1ec9 SuperAdmin c\u00f3 th\u1ec3 kh\u00f4i ph\u1ee5c ho\u1eb7c x\u00f3a v\u0129nh vi\u1ec5n.',
                          ),
                        ),
                    ] else if (selectedView != 'trash' &&
                        !hasCoreNutrition(f) &&
                        f['isVerified'] != true)
                      TextButton(
                        onPressed: () => verify(f),
                        child: const Text('X\u00e1c minh'),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    ),
  );
}

class AdminFoodEditor extends StatefulWidget {
  const AdminFoodEditor({
    super.key,
    required this.api,
    required this.groups,
    this.food,
  });
  final ApiClient api;
  final List<dynamic> groups;
  final Map<String, dynamic>? food;
  @override
  State<AdminFoodEditor> createState() => _AdminFoodEditorState();
}

class _AdminFoodEditorState extends State<AdminFoodEditor> {
  final picker = ImagePicker();
  late final TextEditingController name, basisGrams, foodSource;
  late final List<TextEditingController> values;
  Uint8List? selectedImage;
  String? selectedImageType, savedFoodId;
  bool removeCurrentImage = false;
  String? selectedGroupId;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    selectedGroupId =
        widget.food?['foodGroupId']?.toString() ??
        (widget.groups.isNotEmpty
            ? '${(widget.groups.first as Map<String, dynamic>)['id']}'
            : null);
    name = TextEditingController(text: '${widget.food?['name'] ?? ''}');
    final basis = '${widget.food?['basis'] ?? '100 g phần ăn được'}';
    final basisValue =
        RegExp(r'^[0-9]+(?:[.,][0-9]+)?').firstMatch(basis)?.group(0) ?? '100';
    basisGrams = TextEditingController(text: basisValue.replaceAll(',', '.'));
    final nutrition = widget.food?['nutrition'] as Map<String, dynamic>?;
    final sources = (widget.food?['sources'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final commonSources = sources
        .where((s) => s['fieldName'] == 'FoodInfo')
        .toList();
    final source = commonSources.isNotEmpty
        ? commonSources.first
        : (sources.isNotEmpty ? sources.first : null);
    final citation = '${source?['citation'] ?? ''}'.trim();
    final url = '${source?['url'] ?? ''}'.trim();
    foodSource = TextEditingController(
      text: [citation, url].where((x) => x.isNotEmpty).join('\n'),
    );

    values = _nutritionFields
        .map(
          (f) => TextEditingController(
            text: '${nutrition?[_nutritionJsonKey(f.$1)] ?? ''}',
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    name.dispose();
    basisGrams.dispose();
    foodSource.dispose();
    for (final c in values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> chooseFoodImage() async {
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final mime =
          image.mimeType ??
          switch (image.name.split('.').last.toLowerCase()) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => 'image/jpeg',
          };
      if (!mounted) return;
      setState(() {
        selectedImage = bytes;
        selectedImageType = mime;
        removeCurrentImage = false;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = 'Không mở được ảnh: $e');
    }
  }

  Widget imagePlaceholder() => Container(
    color: const Color(0xFFEAF3ED),
    alignment: Alignment.center,
    child: const Icon(Icons.restaurant_outlined, size: 52, color: green),
  );

  Widget foodImagePreview() {
    if (selectedImage != null) {
      return Image.memory(
        selectedImage!,
        width: 170,
        height: 150,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => imagePlaceholder(),
      );
    }
    final id = savedFoodId ?? widget.food?['id']?.toString();
    if (id == null || removeCurrentImage || widget.food?['hasImage'] != true) {
      return imagePlaceholder();
    }
    return Image.network(
      '${ApiConfig.baseUrl}/api/admin/foods/$id/image',
      headers: {'Authorization': 'Bearer ${widget.api.accessToken ?? ''}'},
      width: 170,
      height: 150,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => imagePlaceholder(),
    );
  }

  ({String citation, String url}) parseFoodSource() {
    final lines = foodSource.text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final urlIndex = lines.indexWhere((line) {
      final uri = Uri.tryParse(line);
      return uri != null && uri.hasScheme && uri.host.isNotEmpty;
    });
    final url = urlIndex < 0 ? '' : lines[urlIndex];
    final citation = lines
        .asMap()
        .entries
        .where((entry) => entry.key != urlIndex)
        .map((entry) => entry.value)
        .join('\n');
    return (citation: citation, url: url);
  }

  Future<void> save({required bool isDraft}) async {
    final parsedBasisGrams = double.tryParse(
      basisGrams.text.trim().replaceAll(',', '.'),
    );
    if (parsedBasisGrams == null || parsedBasisGrams <= 0) {
      setState(() => error = 'Nhập khối lượng cơ sở lớn hơn 0 g.');
      return;
    }
    final parsed = <double?>[];
    for (var i = 0; i < values.length; i++) {
      final c = values[i];
      if (c.text.trim().isEmpty) {
        if (i < 4 && !isDraft) {
          setState(
            () => error = '\u0043\u1ea7n nh\u1eadp \u0111\u1ee7 4 ch\u1ec9 ti\u00eau dinh d\u01b0\u1ee1ng \u0111\u1ea7u.',
          );
          return;
        }
        parsed.add(null);
      } else {
        final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
        if (v == null || v < 0) {
          setState(
            () => error = 'Mỗi chỉ tiêu cần là số không âm hoặc để trống.',
          );
          return;
        }
        parsed.add(v);
      }
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final sharedSource = parseFoodSource();
      final sources = List.generate(
        _nutritionFields.length,
        (i) => {
          'fieldName': _nutritionFields[i].$1,
          'citation': sharedSource.citation,
          'url': sharedSource.url,
        },
      );
      if (sharedSource.citation.isNotEmpty || sharedSource.url.isNotEmpty) {
        sources.add({
          'fieldName': 'FoodInfo',
          'citation': sharedSource.citation,
          'url': sharedSource.url,
        });
      }
      final body = {
        'name': name.text.trim(),
        'basisGrams': parsedBasisGrams,
        'values': parsed,
        'sources': sources,
        'groupId': selectedGroupId,
        'isDraft': isDraft,
      };
      var id = savedFoodId ?? widget.food?['id']?.toString();
      if (id == null) {
        final created = await widget.api.post(
          '/api/admin/foods',
          body,
          auth: true,
        );
        id = '${created['id']}';
        if (id == 'null') {
          throw StateError('Không nhận được mã thực phẩm sau khi lưu.');
        }
        savedFoodId = id;
      } else {
        await widget.api.put('/api/admin/foods/$id', body, auth: true);
      }
      if (selectedImage != null) {
        await widget.api.uploadBytes(
          '/api/admin/foods/$id/image',
          selectedImage!,
          contentType: selectedImageType ?? 'image/jpeg',
          auth: true,
        );
      } else if (removeCurrentImage) {
        await widget.api.delete('/api/admin/foods/$id/image', auth: true);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.food == null ? 'Thêm thực phẩm' : 'Sửa thực phẩm'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(width: 170, height: 150, child: foodImagePreview()),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : chooseFoodImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Chọn ảnh sản phẩm'),
            ),
            if (selectedImage != null ||
                widget.food != null ||
                savedFoodId != null)
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        selectedImage = null;
                        selectedImageType = null;
                        removeCurrentImage = true;
                      }),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Bỏ ảnh'),
              ),
          ],
        ),
        const Text(
          'Ảnh JPG, PNG hoặc WebP · tối đa 5 MB',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7770), fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextField(
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Tên thực phẩm chưa chế biến',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: selectedGroupId,
          decoration: const InputDecoration(labelText: 'Nhom thuc pham'),
          items: widget.groups.map((raw) {
            final group = raw as Map<String, dynamic>;
            return DropdownMenuItem(
              value: '${group['id']}',
              child: Text('${group['name']} - ${group['code']}'),
            );
          }).toList(),
          onChanged: busy
              ? null
              : (value) => setState(() => selectedGroupId = value),
        ),
        const SizedBox(height: 12),
        TextField(
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          controller: basisGrams,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Khối lượng cơ sở của số liệu dinh dưỡng (g)',
            helperText: 'Nhập đúng số gram mà các chỉ tiêu dinh dưỡng bên dưới áp dụng.',
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          _nutritionFields.length,
          (i) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (i == 0 || i == 8)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                  child: Text(
                    i == 0
                        ? '1. 4 ch\u1ec9 ti\u00eau \u0111\u1ea7u (b\u1eaft bu\u1ed9c)'
                        : '2. 8 ch\u1ec9 ti\u00eau b\u1ed5 sung',
                    style: const TextStyle(
                      color: ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      TextField(
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        controller: values[i],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _nutritionFields[i].$2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (error != null) _ErrorBox(error!),
        Text(
          'Nguồn chung của thực phẩm',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: ink, fontWeight: FontWeight.w700),
        ),
        TextField(
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          controller: foodSource,
          minLines: 3,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            labelText: 'Nguon trich dan va URL (moi muc mot dong)',
            hintText: 'Ten tai lieu va URL tren cac dong rieng',
            helperText:
                'Dung mot trang nguon chung cho cac chi tieu dinh duong.',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : () => save(isDraft: true),
                child: const Text('Luu nhap'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : () => save(isDraft: false),
                child: Text(busy ? 'Dang luu...' : 'Luu thuc pham'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class AdminRatingsPage extends StatefulWidget {
  const AdminRatingsPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<AdminRatingsPage> createState() => _AdminRatingsPageState();
}

class _AdminRatingsPageState extends State<AdminRatingsPage> {
  bool loading = true;
  String? error;
  List<dynamic> items = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await widget.api.get('/api/admin/ratings', auth: true);
      items = r['data'] as List<dynamic>? ?? [];
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> remove(Map<String, dynamic> r) async {
    try {
      await widget.api.delete(
        '/api/admin/ratings/${r['userId']}/${r['dishId']}',
        auth: true,
      );
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đánh giá')),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: green))
        : error != null
        ? Center(
            child: TextButton(onPressed: load, child: Text('Thử lại · $error')),
          )
        : items.isEmpty
        ? const Center(child: Text('Chưa có đánh giá.'))
        : ListView(
            children: items.map((raw) {
              final r = raw as Map<String, dynamic>;
              return ListTile(
                title: Text('${r['name']} · ${r['stars']}/5'),
                subtitle: Text(
                  '${r['comment'] ?? 'Không có nhận xét'}\n${r['updatedAtUtc']}',
                ),
                trailing: IconButton(
                  onPressed: () => remove(r),
                  icon: const Icon(Icons.delete_outline),
                ),
              );
            }).toList(),
          ),
  );
}

class AdminFavoritesPage extends StatefulWidget {
  const AdminFavoritesPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<AdminFavoritesPage> createState() => _AdminFavoritesPageState();
}

class _AdminFavoritesPageState extends State<AdminFavoritesPage> {
  bool loading = true;
  String? error;
  List<dynamic> items = [];
  @override
  void initState() {
    super.initState();
    widget.api
        .get('/api/admin/statistics/favorites', auth: true)
        .then((r) {
          items = r['data'] as List<dynamic>? ?? [];
          if (mounted) setState(() => loading = false);
        })
        .catchError((e) {
          error = '$e';
          if (mounted) setState(() => loading = false);
        });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thống kê yêu thích')),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: green))
        : error != null
        ? Center(child: Text(error!))
        : items.isEmpty
        ? const Center(child: Text('Chưa có dữ liệu yêu thích.'))
        : ListView(
            children: items.asMap().entries.map((entry) {
              final x = entry.value as Map<String, dynamic>;
              return ListTile(
                leading: Text('${entry.key + 1}'),
                title: Text('${x['name']}'),
                trailing: Text('${x['favoriteCount']} lượt'),
              );
            }).toList(),
          ),
  );
}

class _AuthProviderButton extends StatelessWidget {
  const _AuthProviderButton({
    required this.label,
    required this.mark,
    required this.onPressed,
  });

  final String label;
  final Widget mark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 68,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        side: const BorderSide(color: Color(0xFFE2E8E3)),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 28, child: Center(child: mark)),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.spa_outlined, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 10),
      const Text(
        'avora',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -1,
        ),
      ),
      const Text(
        '  AI',
        style: TextStyle(
          fontSize: 13,
          color: green,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    ],
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
  final IconData icon;
  final String title, description;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: line),
    ),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF1E7),
        child: Icon(icon, color: green),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
      ),
      subtitle: Text(description),
      trailing: Icon(
        onTap == null ? Icons.lock_outline : Icons.arrow_forward_ios,
        size: 15,
        color: green,
      ),
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEDEA),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: const TextStyle(color: Color(0xFF8D3327))),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title, text;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF1E7),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
              const SizedBox(height: 4),
              Text(text),
            ],
          ),
        ),
      ],
    ),
  );
}
