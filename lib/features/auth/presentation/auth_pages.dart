import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_controller.dart';
import '../data/auth_repository.dart';
import '../../../app/router/app_route_guard.dart';
import '../../../app/router/app_route_paths.dart';
import 'login_captcha_policy.dart';
import '../../../data/models/auth/captcha.dart';
import '../../../data/models/auth/security_question.dart';
import '../../../data/models/auth/security_question_catalog.dart';
import '../../cart/presentation/commerce_widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();
  Captcha? _captcha;
  bool _captchaLoading = false;
  String? _captchaError;
  bool _obscurePassword = true;
  bool _agreed = false;

  bool _requiresCaptcha = false;
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _initializeCaptchaPolicy(),
    );
  }

  Future<void> _initializeCaptchaPolicy() async {
    final preferences = await SharedPreferences.getInstance();
    final requiresCaptcha = await LoginCaptchaPolicy(
      preferences,
    ).requiresCaptcha();
    if (!mounted) return;
    setState(() => _requiresCaptcha = requiresCaptcha);
    if (requiresCaptcha) {
      await _refreshCaptcha();
    }
  }

  Future<void> _refreshCaptcha() async {
    if (!mounted || !_requiresCaptcha) return;
    setState(() {
      _captchaLoading = true;
      _captchaError = null;
      _captchaController.clear();
    });
    try {
      final captcha = await ref
          .read(authControllerProvider.notifier)
          .loadCaptcha();
      if (!mounted) return;
      setState(() => _captcha = captcha);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captcha = null;
        _captchaError = '验证码加载失败，请点击刷新重试';
      });
    } finally {
      if (mounted) setState(() => _captchaLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_agreed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先阅读并同意服务条款与隐私政策')));
      return;
    }
    Captcha? captcha;
    if (_requiresCaptcha) {
      captcha = _captcha;
      if (captcha == null) {
        await _refreshCaptcha();
        return;
      }
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final preferences = await SharedPreferences.getInstance();
    final policy = LoginCaptchaPolicy(preferences);
    await policy.recordSubmission();
    final requiresCaptchaAfterSubmission = await policy.requiresCaptcha();
    final success = await ref
        .read(authControllerProvider.notifier)
        .login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          captchaId: captcha?.captchaId,
          captchaCode: _requiresCaptcha ? _captchaController.text.trim() : null,
        );
    var refreshedCaptchaForNextAttempt = false;
    if (mounted && requiresCaptchaAfterSubmission != _requiresCaptcha) {
      setState(() => _requiresCaptcha = requiresCaptchaAfterSubmission);
      if (requiresCaptchaAfterSubmission) {
        await _refreshCaptcha();
        refreshedCaptchaForNextAttempt = true;
      }
    }
    final session = ref.read(authControllerProvider).session;
    if (success && mounted && session != null) {
      context.go(destinationForRole(session.role));
    } else if (mounted && _requiresCaptcha && !refreshedCaptchaForNextAttempt) {
      await _refreshCaptcha();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    return AuthFrame(
      eyebrow: 'BOOKSTORE  ·  ONLINE CATALOG',
      headline: '让每一次阅读都有迹可循',
      description: '收藏值得反复翻阅的书，也把下一本好书留给正在寻找它的人。',
      bullets: const [],
      card: AuthCard(
        title: '欢迎回来',
        subtitle: '登录你的账户，继续探索书页。',
        form: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                controller: _usernameController,
                label: '用户名',
                hintText: '请输入用户名',
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入用户名';
                  }
                  if (value.trim().length < 3) {
                    return '用户名至少需要 3 个字符';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthField(
                controller: _passwordController,
                label: '密码',
                hintText: '请输入密码',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }
                  if (value.length < 6) {
                    return '密码至少需要 6 个字符';
                  }
                  return null;
                },
              ),
              if (_requiresCaptcha) ...[
                const SizedBox(height: 16),
                CaptchaField(
                  captcha: _captcha,
                  controller: _captchaController,
                  loading: _captchaLoading,
                  errorMessage: _captchaError,
                  onRefresh: _refreshCaptcha,
                ),
                const SizedBox(height: 10),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go(AppRoutePaths.forgotPassword),
                  style: TextButton.styleFrom(
                    foregroundColor: AuthColors.ink,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('忘记密码？'),
                ),
              ),
              if (authState.errorMessage != null) ...[
                const SizedBox(height: 8),
                AuthErrorBanner(message: authState.errorMessage!),
              ],
              const SizedBox(height: 16),
              AuthPrimaryButton(
                label: '登录',
                icon: Icons.login_rounded,
                loading: authState.status == AuthStatus.loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 22),
              AuthAgreement(
                agreed: _agreed,
                onChanged: (value) => setState(() => _agreed = value),
              ),
              const SizedBox(height: 22),
              AuthSwitchLine(
                prompt: '还没有账户？',
                actionLabel: '立即注册',
                onPressed: () => context.go('/register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _answerControllers = List.generate(2, (_) => TextEditingController());
  List<SecurityQuestion> _questions = const [];
  List<String?> _selectedKeys = [null, null];
  String? _error;
  bool _loadingQuestions = false;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (final controller in _answerControllers) controller.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _error = '请输入用户名');
      return;
    }
    setState(() {
      _loadingQuestions = true;
      _error = null;
    });
    try {
      final questions = await ref
          .read(authRepositoryProvider)
          .fetchSecurityQuestions(username);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _selectedKeys = [null, null];
      });
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _loadingQuestions = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.length < 3 || _selectedKeys.any((key) => key == null)) {
      setState(() => _error = '请先获取密保问题，并回答两个不同的问题');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .forgotPassword(
            username: _usernameController.text.trim(),
            answers: [
              for (var index = 0; index < 2; index++)
                SecurityAnswer(
                  questionKey: _selectedKeys[index]!,
                  answer: _answerControllers[index].text.trim(),
                ),
            ],
            newPassword: _newPasswordController.text,
            confirmPassword: _confirmPasswordController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('密码重置成功，请使用新密码登录')));
        context.go(AppRoutePaths.login);
      }
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      eyebrow: 'BOOKSTORE  ·  ACCOUNT RECOVERY',
      headline: '通过密保问题找回密码',
      headlineOnly: true,
      description: '回答已设置的两个密保问题，验证身份后即可设置新密码。',
      bullets: const ['答案仅用于身份验证', '每次需要回答两个不同的问题', '没有密保记录的账户无法找回密码'],
      card: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: '用户名'),
              validator: (v) => (v ?? '').trim().isEmpty ? '请输入用户名' : null,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadingQuestions ? null : _loadQuestions,
              icon: _loadingQuestions
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.quiz_outlined),
              label: const Text('获取密保问题'),
            ),
            if (_questions.isNotEmpty) ...[
              const SizedBox(height: 18),
              for (var index = 0; index < 2; index++) ...[
                DropdownButtonFormField<String>(
                  value: _selectedKeys[index],
                  decoration: InputDecoration(labelText: '密保问题 ${index + 1}'),
                  items: _questions
                      .map(
                        (q) => DropdownMenuItem(
                          value: q.key,
                          child: Text(q.question),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedKeys[index] = value),
                  validator: (v) => v == null ? '请选择问题' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _answerControllers[index],
                  decoration: const InputDecoration(labelText: '密保答案'),
                  validator: (v) => (v ?? '').trim().isEmpty ? '请输入答案' : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密码'),
                validator: (v) => (v ?? '').length < 6 ? '新密码至少需要 6 个字符' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认新密码'),
                validator: (v) =>
                    v != _newPasswordController.text ? '两次输入的新密码不一致' : null,
              ),
              const SizedBox(height: 18),
              AuthPrimaryButton(
                label: _submitting ? '正在重置' : '重置密码',
                icon: Icons.lock_reset_rounded,
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              AuthErrorBanner(message: _error!),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(AppRoutePaths.login),
              child: const Text('返回登录'),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _securityAnswerControllers = List.generate(
    3,
    (_) => TextEditingController(),
  );
  final _securityQuestionKeys = ['Q1', 'Q2', 'Q3'];
  final _captchaController = TextEditingController();
  Captcha? _captcha;
  bool _captchaLoading = false;
  String? _captchaError;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreed = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (final controller in _securityAnswerControllers) controller.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCaptcha());
  }

  Future<void> _refreshCaptcha() async {
    if (!mounted) return;
    setState(() {
      _captchaLoading = true;
      _captchaError = null;
      _captchaController.clear();
    });
    try {
      final captcha = await ref
          .read(authControllerProvider.notifier)
          .loadCaptcha();
      if (!mounted) return;
      setState(() => _captcha = captcha);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captcha = null;
        _captchaError = '验证码加载失败，请点击刷新重试';
      });
    } finally {
      if (mounted) setState(() => _captchaLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_agreed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先阅读并同意服务条款与隐私政策')));
      return;
    }
    final captcha = _captcha;
    if (captcha == null) {
      await _refreshCaptcha();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final success = await ref
        .read(authControllerProvider.notifier)
        .register(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          nickname: _nicknameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          captchaId: captcha.captchaId,
          captchaCode: _captchaController.text.trim(),
          securityQuestions: [
            for (var index = 0; index < 3; index++)
              SecurityAnswer(
                questionKey: _securityQuestionKeys[index],
                answer: _securityAnswerControllers[index].text.trim(),
              ),
          ],
        );
    final session = ref.read(authControllerProvider).session;
    if (success && mounted && session != null) {
      context.go(destinationForRole(session.role));
    } else if (mounted) {
      await _refreshCaptcha();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    return AuthFrame(
      eyebrow: 'BOOKSTORE  ·  YOUR READING SPACE',
      headline: '从今天开始，建立自己的书架',
      description: '注册一个轻量的阅读账户，把喜欢的书、订单和收货地址都放在手边。',
      bullets: const [],
      card: AuthCard(
        title: '创建账户',
        subtitle: '只需要几步，就能开始你的书店之旅。',
        form: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                controller: _usernameController,
                label: '用户名',
                hintText: '3-30 位字母、数字或下划线',
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return '请输入用户名';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(text)) {
                    return '只能使用 3-30 位字母、数字或下划线';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AuthField(
                controller: _nicknameController,
                label: '昵称',
                hintText: '展示给其他人的名字（可选）',
                prefixIcon: Icons.badge_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              AuthField(
                controller: _emailController,
                label: '邮箱',
                hintText: 'name@example.com（可选）',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isNotEmpty &&
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                    return '请输入正确的邮箱地址';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AuthField(
                controller: _phoneController,
                label: '手机号',
                hintText: '11 位手机号（可选）',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isNotEmpty &&
                      !RegExp(r'^1[3-9]\d{9}$').hasMatch(text)) {
                    return '请输入正确的手机号';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              const Text(
                '设置三个密保问题',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '找回密码时需要答对其中两个，请选择自己能记住答案的问题。',
                style: TextStyle(color: AuthColors.muted, fontSize: 12),
              ),
              for (var index = 0; index < 3; index++) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _securityQuestionKeys[index],
                  decoration: InputDecoration(labelText: '密保问题 ${index + 1}'),
                  items: securityQuestionCatalog
                      .where(
                        (item) => !_securityQuestionKeys.asMap().entries.any(
                          (entry) =>
                              entry.key != index && entry.value == item.key,
                        ),
                      )
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.key,
                          child: Text(item.question),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => _securityQuestionKeys[index] =
                        value ?? _securityQuestionKeys[index],
                  ),
                ),
                const SizedBox(height: 8),
                AuthField(
                  controller: _securityAnswerControllers[index],
                  label: '密保答案 ${index + 1}',
                  hintText: '请输入答案',
                  prefixIcon: Icons.shield_outlined,
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? '请输入密保答案' : null,
                ),
              ],
              const SizedBox(height: 16),
              AuthField(
                controller: _passwordController,
                label: '密码',
                hintText: '至少 6 个字符',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return '密码至少需要 6 个字符';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AuthField(
                controller: _confirmPasswordController,
                label: '确认密码',
                hintText: '再次输入密码',
                prefixIcon: Icons.verified_user_outlined,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                suffixIcon: IconButton(
                  tooltip: _obscureConfirmPassword ? '显示密码' : '隐藏密码',
                  onPressed: () {
                    setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    );
                  },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) {
                  if (value != _passwordController.text) {
                    return '两次输入的密码不一致';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CaptchaField(
                captcha: _captcha,
                controller: _captchaController,
                loading: _captchaLoading,
                errorMessage: _captchaError,
                onRefresh: _refreshCaptcha,
              ),
              if (authState.errorMessage != null) ...[
                const SizedBox(height: 14),
                AuthErrorBanner(message: authState.errorMessage!),
              ],
              const SizedBox(height: 22),
              AuthPrimaryButton(
                label: '注册并进入书店',
                icon: Icons.arrow_forward_rounded,
                loading: authState.status == AuthStatus.loading,
                onPressed: _submit,
              ),
              const SizedBox(height: 18),
              AuthAgreement(
                agreed: _agreed,
                onChanged: (value) => setState(() => _agreed = value),
              ),
              const SizedBox(height: 20),
              AuthSwitchLine(
                prompt: '已经有账户？',
                actionLabel: '返回登录',
                onPressed: () => context.go('/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthFrame extends StatelessWidget {
  const AuthFrame({
    required this.eyebrow,
    required this.headline,
    required this.description,
    required this.bullets,
    this.headlineOnly = false,
    required this.card,
    super.key,
  });

  final String eyebrow;
  final String headline;
  final String description;
  final List<String> bullets;
  final bool headlineOnly;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 20 : 48,
                vertical: compact ? 20 : 28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (compact ? 40 : 56),
                ),
                child: Column(
                  children: [
                    _AuthTopBar(compact: compact),
                    const SizedBox(height: 28),
                    if (compact)
                      card
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 11,
                            child: _EditorialPanel(
                              eyebrow: eyebrow,
                              headline: headline,
                              description: description,
                              bullets: bullets,
                              headlineOnly: headlineOnly,
                            ),
                          ),
                          const SizedBox(width: 72),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: card,
                          ),
                        ],
                      ),
                    if (compact) ...[
                      const SizedBox(height: 30),
                      _EditorialPanel(
                        eyebrow: eyebrow,
                        headline: headline,
                        description: description,
                        bullets: bullets,
                        headlineOnly: headlineOnly,
                        compact: true,
                      ),
                    ],
                    const SizedBox(height: 28),
                    const _AuthFooter(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthTopBar extends StatelessWidget {
  const _AuthTopBar({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BookstoreBrand(color: AuthColors.ink, fontSize: 21),
        const Spacer(),
        if (!compact)
          TextButton.icon(
            onPressed: () => context.go('/books'),
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: const Text('返回书店'),
            style: TextButton.styleFrom(foregroundColor: AuthColors.muted),
          ),
        const SizedBox(width: 14),
        const Text(
          'CN  中文',
          style: TextStyle(
            color: AuthColors.muted,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AuthColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '册',
        style: TextStyle(
          color: AuthColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EditorialPanel extends StatelessWidget {
  const _EditorialPanel({
    required this.eyebrow,
    required this.headline,
    required this.description,
    required this.bullets,
    required this.headlineOnly,
    this.compact = false,
  });

  final String eyebrow;
  final String headline;
  final String description;
  final List<String> bullets;
  final bool headlineOnly;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!headlineOnly) ...[
          Text(
            eyebrow,
            style: const TextStyle(
              color: AuthColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.7,
            ),
          ),
          SizedBox(height: compact ? 18 : 32),
          if (!compact)
            SizedBox(
              height: 92,
              child: CustomPaint(
                painter: _EditorialLinePainter(),
                child: const SizedBox.expand(),
              ),
            ),
          SizedBox(height: compact ? 0 : 40),
        ],
        Text(
          headline,
          style: TextStyle(
            color: AuthColors.ink,
            fontFamily: 'serif',
            fontSize: compact ? 36 : 64,
            height: .98,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (!headlineOnly) ...[
          const SizedBox(height: 24),
          Text(
            description,
            style: TextStyle(
              color: AuthColors.muted,
              fontSize: compact ? 15 : 18,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 32),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: AuthColors.muted,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    bullet,
                    style: const TextStyle(
                      color: AuthColors.muted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EditorialLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AuthColors.line
      ..strokeWidth = 1;
    final darkPaint = Paint()
      ..color = AuthColors.muted
      ..strokeWidth = 2;
    final centerY = size.height * .55;
    canvas.drawLine(
      Offset.zero.translate(0, centerY),
      Offset(size.width, centerY),
      linePaint,
    );
    for (var index = 1; index < 5; index++) {
      final x = size.width * index / 5;
      canvas.drawLine(
        Offset(x - 5, centerY - 36),
        Offset(x - 13, centerY + 36),
        linePaint,
      );
    }
    canvas.drawLine(
      Offset(size.width * .72, centerY),
      Offset(size.width * .82, centerY),
      darkPaint,
    );
    canvas.drawCircle(
      Offset(size.width * .84, centerY),
      4,
      Paint()..color = AuthColors.ink,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AuthCard extends StatelessWidget {
  const AuthCard({
    required this.title,
    required this.subtitle,
    required this.form,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(42, 42, 42, 34),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AuthColors.line),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          const BookstoreBrand(color: AuthColors.ink, fontSize: 21),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: AuthColors.ink,
              fontFamily: 'serif',
              fontSize: 31,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AuthColors.muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          form,
        ],
      ),
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AuthColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          style: const TextStyle(color: AuthColors.ink, fontSize: 15),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(prefixIcon, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFFCFCFB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            hintStyle: const TextStyle(
              color: AuthColors.placeholder,
              fontSize: 14,
            ),
            prefixIconColor: AuthColors.muted,
            suffixIconColor: AuthColors.muted,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AuthColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AuthColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AuthColors.ink, width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFB74D42)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFB74D42),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CaptchaField extends StatelessWidget {
  const CaptchaField({
    required this.captcha,
    required this.controller,
    required this.loading,
    required this.onRefresh,
    this.errorMessage,
    super.key,
  });

  final Captcha? captcha;
  final TextEditingController controller;
  final bool loading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final imageBytes = _imageBytes(captcha?.imageBase64);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AuthColors.canvas,
                border: Border.all(color: AuthColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : imageBytes == null
                  ? const Text(
                      '验证码不可用',
                      style: TextStyle(
                        color: AuthColors.placeholder,
                        fontSize: 12,
                      ),
                    )
                  : Image.memory(
                      imageBytes,
                      width: 140,
                      height: 48,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const Text(
                        '验证码不可用',
                        style: TextStyle(
                          color: AuthColors.placeholder,
                          fontSize: 12,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '刷新验证码',
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            errorMessage!,
            style: const TextStyle(color: Color(0xFFB74D42), fontSize: 11),
          ),
        ],
        const SizedBox(height: 12),
        AuthField(
          controller: controller,
          label: '验证码',
          hintText: '请输入图片中的字符',
          prefixIcon: Icons.verified_outlined,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入验证码';
            }
            return null;
          },
        ),
      ],
    );
  }

  Uint8List? _imageBytes(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    final value = encoded.startsWith('data:image/png;base64,')
        ? encoded.substring('data:image/png;base64,'.length)
        : encoded;
    try {
      return base64Decode(value);
    } on FormatException {
      return null;
    }
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 19),
        label: Text(
          loading ? '请稍候' : label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AuthColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AuthColors.ink.withValues(alpha: .55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class AuthAgreement extends StatelessWidget {
  const AuthAgreement({
    required this.agreed,
    required this.onChanged,
    super.key,
  });

  final bool agreed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!agreed),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: agreed,
              onChanged: (value) => onChanged(value ?? false),
              activeColor: AuthColors.ink,
              side: const BorderSide(color: AuthColors.muted),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text.rich(
              TextSpan(
                text: '我已阅读并同意 ',
                children: [
                  TextSpan(
                    text: '服务条款',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                  TextSpan(text: '、'),
                  TextSpan(
                    text: '隐私政策',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                  TextSpan(text: ' 和相关服务说明'),
                ],
              ),
              style: TextStyle(
                color: AuthColors.muted,
                fontSize: 12,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthSwitchLine extends StatelessWidget {
  const AuthSwitchLine({
    required this.prompt,
    required this.actionLabel,
    required this.onPressed,
    super.key,
  });

  final String prompt;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prompt,
          style: const TextStyle(color: AuthColors.muted, fontSize: 13),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AuthColors.ink,
            padding: const EdgeInsets.only(left: 6),
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F0),
        border: Border.all(color: const Color(0xFFF0C8C1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFB74D42),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8B3B33),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthFooter extends StatelessWidget {
  const _AuthFooter();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '隐私  ·  透明  ·  一念可达',
      style: TextStyle(
        color: AuthColors.placeholder,
        fontSize: 12,
        letterSpacing: 2,
      ),
    );
  }
}

abstract final class AuthColors {
  static const canvas = Color(0xFFF7F6F2);
  static const ink = Color(0xFF171717);
  static const muted = Color(0xFF777570);
  static const placeholder = Color(0xFFA7A49D);
  static const line = Color(0xFFE5E3DE);
}
