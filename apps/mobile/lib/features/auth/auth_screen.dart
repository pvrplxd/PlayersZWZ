import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/playerszwz_app.dart';
import 'auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.createAccount = false, this.authService});

  final bool createAccount;
  final AuthService? authService;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Keep typed text and hints consistent instead of inheriting Material tracking.
  // The font family stays platform-native (SF on iOS).
  static const _inputTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  late final _auth = widget.authService ?? AuthService();
  late bool _isCreatingAccount = widget.createAccount;
  bool _isBusy = false;
  bool _googleBusy = false;
  bool _submitted = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isBusy) return;
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      if (_isCreatingAccount) {
        await _auth.createAccount(
          email: _email.text,
          password: _password.text,
          displayName: '${_firstName.text.trim()} ${_lastName.text.trim()}',
        );
      } else {
        await _auth.signIn(email: _email.text, password: _password.text);
      }
    } catch (error) {
      if (mounted) setState(() => _error = readableAuthError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _googleBusy = false;
        });
      }
    }
  }

  Future<void> _googleSignIn() async {
    if (_isBusy) return;
    _googleBusy = true;
    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await _auth.signInWithGoogle();
    } on GoogleSignInException catch (error) {
      if (mounted && error.code != GoogleSignInExceptionCode.canceled) {
        setState(() =>
            _error = 'Google sign-in could not finish. Please try again.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = readableAuthError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _googleBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = _isCreatingAccount;
    final compact = MediaQuery.sizeOf(context).height < 760;
    final gap = compact ? 8.0 : 12.0;
    return Scaffold(
      backgroundColor: appBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
                24, compact ? 12 : 28, 24, compact ? 12 : 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight:
                      math.max(0, constraints.maxHeight - (compact ? 24 : 56))),
              child: Form(
                key: _formKey,
                autovalidateMode: _submitted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BrandMark(size: compact && isCreate ? 40 : 78),
                    SizedBox(height: compact && isCreate ? 8 : 26),
                    Text(
                      isCreate ? 'Create your\naccount' : 'Login',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compact && isCreate ? 26 : 34,
                        fontWeight: FontWeight.w700,
                        height: 1.12,
                        letterSpacing: -.8,
                      ),
                    ),
                    SizedBox(height: compact && isCreate ? 12 : 34),
                    if (isCreate) ...[
                      _field(_firstName, 'First name', validator: _required),
                      SizedBox(height: gap),
                      _field(_lastName, 'Last name', validator: _required),
                      SizedBox(height: gap),
                    ],
                    _field(
                      _email,
                      'Email address',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your email address.';
                        }
                        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(value.trim())) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: gap),
                    _passwordField(
                      _password,
                      'Password',
                      isHidden: _hidePassword,
                      onToggle: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter your password.';
                        }
                        if (isCreate && value.length < 6) {
                          return 'Use at least 6 characters.';
                        }
                        return null;
                      },
                    ),
                    if (isCreate) ...[
                      SizedBox(height: gap),
                      _passwordField(
                        _confirmPassword,
                        'Confirm password',
                        isHidden: _hideConfirmPassword,
                        onToggle: () => setState(
                          () => _hideConfirmPassword = !_hideConfirmPassword,
                        ),
                        validator: (value) => value != _password.text
                            ? 'Passwords do not match.'
                            : null,
                      ),
                    ],
                    if (_error != null) ...[
                      SizedBox(height: gap),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: Color(0xFFFF6666), fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _PrimaryButton(
                      label: isCreate ? 'Create account' : 'Login',
                      busy: _isBusy && !_googleBusy,
                      disabled: _isBusy,
                      onPressed: _submit,
                    ),
                    SizedBox(height: gap),
                    const _OrDivider(),
                    SizedBox(height: gap),
                    _GoogleButton(
                        busy: _googleBusy && _isBusy,
                        disabled: _isBusy,
                        onPressed: _googleSignIn),
                    SizedBox(height: gap),
                    Text(
                      isCreate
                          ? 'Already have an account?'
                          : 'Don’t have an account?',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 15),
                    ),
                    TextButton(
                      onPressed: _isBusy
                          ? null
                          : () => setState(() {
                                _isCreatingAccount = !isCreate;
                                _error = null;
                                _submitted = false;
                                _password.clear();
                                _confirmPassword.clear();
                                _hidePassword = true;
                                _hideConfirmPassword = true;
                                _formKey.currentState?.reset();
                              }),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        minimumSize: const Size(48, 48),
                      ),
                      child: Text(
                        isCreate ? 'Log in' : 'Sign up',
                        style: const TextStyle(
                            decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  Widget _field(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isBusy,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: keyboardType,
      textCapitalization: keyboardType == TextInputType.emailAddress
          ? TextCapitalization.none
          : TextCapitalization.words,
      autofillHints: [
        keyboardType == TextInputType.emailAddress
            ? AutofillHints.email
            : (controller == _firstName
                ? AutofillHints.givenName
                : AutofillHints.familyName)
      ],
      textInputAction: TextInputAction.next,
      validator: validator,
      style: _inputTextStyle,
      cursorColor: appAccent,
      cursorWidth: 1.5,
      decoration: _inputDecoration(hint),
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String hint, {
    required bool isHidden,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isBusy,
      autocorrect: false,
      enableSuggestions: false,
      obscureText: isHidden,
      autofillHints: [
        _isCreatingAccount ? AutofillHints.newPassword : AutofillHints.password
      ],
      textInputAction: _isCreatingAccount && controller == _password
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: (_) {
        if (!_isCreatingAccount || controller == _confirmPassword) _submit();
      },
      validator: validator,
      style: _inputTextStyle,
      cursorColor: appAccent,
      cursorWidth: 1.5,
      decoration: _inputDecoration(hint).copyWith(
        suffixIcon: IconButton(
          tooltip: isHidden ? 'Show $hint' : 'Hide $hint',
          onPressed: _isBusy ? null : onToggle,
          color: Colors.white,
          icon: Icon(isHidden
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        errorMaxLines: 3,
        isDense: true,
        hintStyle: _inputTextStyle.copyWith(color: Colors.white54),
        filled: true,
        fillColor: appSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: appAccent, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF6666)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF6666)),
        ),
      );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(
      {required this.label,
      required this.busy,
      required this.disabled,
      required this.onPressed});

  final String label;
  final bool busy;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white70,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          shape: const StadiumBorder(),
        ),
        child: Row(
          children: [
            const SizedBox(width: 42),
            Expanded(
              child: Center(
                child: busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: appAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: const Icon(Icons.arrow_forward, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton(
      {required this.busy, required this.disabled, required this.onPressed});

  final bool busy;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton.icon(
        onPressed: disabled ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: appSurface,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: busy
            ? const SizedBox.square(
                dimension: 18,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: appAccent),
              )
            : SvgPicture.asset(
                'assets/branding/google-icon.svg',
                width: 24,
                height: 24,
                excludeFromSemantics: true,
              ),
        label: const Text('Continue with Google',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFF333333))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or',
              style: TextStyle(color: Colors.white.withValues(alpha: .45))),
        ),
        const Expanded(child: Divider(color: Color(0xFF333333))),
      ],
    );
  }
}
