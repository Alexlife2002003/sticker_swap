import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme.dart';
import '../providers/app_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;

  static const Color _background = AppTheme.warmBackground;
  static const Color _card = AppTheme.cardWhite;
  static const Color _navy = AppTheme.primaryNavy;
  static const Color _deepNavy = AppTheme.ink;
  static const Color _muted = AppTheme.subtext;
  static const Color _border = AppTheme.goldBorder;
  static const Color _fieldFill = AppTheme.inputBackground;
  static const Color _gold = AppTheme.gold;
  static const Color _error = AppTheme.danger;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authRepo = ref.read(authRepositoryProvider);

    try {
      if (_isSignUp) {
        await authRepo.signUp(
          _emailController.text.trim(),
          _passwordController.text,
          _usernameController.text.trim().isEmpty
              ? _emailController.text.trim().split('@')[0]
              : _usernameController.text.trim(),
        );
      } else {
        await authRepo.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _errorMessage = null;
      _confirmPasswordController.clear();
    });
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: _muted,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      floatingLabelStyle: const TextStyle(
        color: _navy,
        fontWeight: FontWeight.w900,
      ),
      prefixIcon: Icon(
        icon,
        color: _navy,
        size: 20,
      ),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppTheme.line,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: _navy,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: _error,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: _error,
          width: 1.5,
        ),
      ),
      errorStyle: const TextStyle(
        color: _error,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: -62,
              top: -54,
              child: Icon(
                Icons.sports_soccer,
                size: 220,
                color: _navy.withValues(alpha: 0.055),
              ),
            ),
            Positioned(
              left: -48,
              bottom: -42,
              child: Container(
                height: 160,
                width: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withValues(alpha: 0.12),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PremiumAuthHeader(),
                      const SizedBox(height: 28),
                      _buildAuthCard(),
                      const SizedBox(height: 18),
                      _buildBottomToggle(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModeSelector(),
            const SizedBox(height: 22),
            Text(
              _isSignUp ? 'Create your album account' : 'Welcome back',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _deepNavy,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isSignUp
                  ? 'Start collecting, opening packs, and completing teams.'
                  : 'Sign in to continue collecting stickers.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            if (_errorMessage != null) ...[
              _buildErrorCard(),
              const SizedBox(height: 16),
            ],
            if (_isSignUp) ...[
              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                style: const TextStyle(
                  color: _deepNavy,
                  fontWeight: FontWeight.w700,
                ),
                cursorColor: _navy,
                decoration: _inputDecoration(
                  label: 'Username',
                  icon: Icons.person_outline,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(
                color: _deepNavy,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: _navy,
              decoration: _inputDecoration(
                label: 'Email Address',
                icon: Icons.email_outlined,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter your email';
                }
                final emailReg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailReg.hasMatch(val.trim())) {
                  return 'Please enter a valid email format';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              textInputAction:
                  _isSignUp ? TextInputAction.next : TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) {
                if (!_isSignUp) _submit();
              },
              style: const TextStyle(
                color: _deepNavy,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: _navy,
              decoration: _inputDecoration(
                label: 'Password',
                icon: Icons.lock_outline,
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Please enter a password';
                }
                if (val.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            if (_isSignUp) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _submit(),
                style: const TextStyle(
                  color: _deepNavy,
                  fontWeight: FontWeight.w700,
                ),
                cursorColor: _navy,
                decoration: _inputDecoration(
                  label: 'Confirm Password',
                  icon: Icons.lock_reset,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (val != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 420.milliseconds).slideY(
          begin: 0.06,
          end: 0,
          duration: 420.milliseconds,
          curve: Curves.easeOut,
        );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppTheme.progressTrack,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.line,
        ),
      ),
      child: Row(
        children: [
          _ModeChip(
            label: 'Sign In',
            selected: !_isSignUp,
            onTap: () {
              if (_isSignUp) _toggleMode();
            },
          ),
          const SizedBox(width: 6),
          _ModeChip(
            label: 'Create Account',
            selected: _isSignUp,
            onTap: () {
              if (!_isSignUp) _toggleMode();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.dangerLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _error.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: _error,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: _error,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submit,
        icon: _isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(
                _isSignUp ? Icons.auto_awesome : Icons.login_rounded,
                size: 18,
              ),
        label: Text(
          _isLoading
              ? (_isSignUp ? 'Creating Account…' : 'Signing In…')
              : (_isSignUp ? 'Create Account' : 'Sign In'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _navy,
          disabledBackgroundColor: _navy.withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToggle() {
    return TextButton(
      onPressed: _toggleMode,
      style: TextButton.styleFrom(
        foregroundColor: _navy,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        _isSignUp
            ? 'Already have an account? Sign In'
            : "Don't have an account? Create one",
        style: const TextStyle(
          color: _navy,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PremiumAuthHeader extends StatelessWidget {
  const _PremiumAuthHeader();

  static const Color _navy = AppTheme.primaryNavy;
  static const Color _deepNavy = AppTheme.ink;
  static const Color _muted = AppTheme.subtext;
  static const Color _border = AppTheme.goldBorder;
  static const Color _gold = AppTheme.gold;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 94,
          width: 94,
          decoration: BoxDecoration(
            color: _navy,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _gold,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.sports_soccer,
                size: 48,
                color: Colors.white.withValues(alpha: 0.94),
              ),
              Positioned(
                right: 15,
                top: 14,
                child: Container(
                  height: 12,
                  width: 12,
                  decoration: const BoxDecoration(
                    color: _gold,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scaleXY(
              begin: 0.97,
              end: 1.04,
              duration: 1500.milliseconds,
              curve: Curves.easeInOut,
            ),
        const SizedBox(height: 18),
        const Text(
          'STICKER SWAP',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _deepNavy,
            fontSize: 30,
            height: 1,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _border,
            ),
          ),
          child: const Text(
            'PARODY WORLD CUP ALBUM',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color _navy = AppTheme.primaryNavy;
  static const Color _muted = AppTheme.subtext;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? _navy : _muted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}