import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

import '../models/user_profile.dart';
import '../utils/auth_storage.dart';
import 'app_shell.dart';
import '../views/forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isLoginMode = true;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://acta-production.up.railway.app',
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLoginMode) {
        // --- LOGIN FLOW ---
        final response = await _dio.post(
          '/api/v1/auth/login',
          data: {
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
          },
        );

        final token = response.data['access_token'] as String;
        final userData = response.data['user'] as Map<String, dynamic>;

        // Persist token so session survives page refresh
        await AuthStorage.saveToken(token);

        // Set state in provider
        ref.read(authUserProvider.notifier).state = UserProfile.fromJson(
          userData,
          token,
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AppShell()),
          );
        }
      } else {
        // --- REGISTER FLOW ---
        await _dio.post(
          '/api/v1/auth/register',
          data: {
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
          },
        );

        // Auto-login after successful registration
        final response = await _dio.post(
          '/api/v1/auth/login',
          data: {
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
          },
        );

        final token = response.data['access_token'] as String;
        final userData = response.data['user'] as Map<String, dynamic>;

        // Persist token so session survives page refresh
        await AuthStorage.saveToken(token);

        ref.read(authUserProvider.notifier).state = UserProfile.fromJson(
          userData,
          token,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Logged in.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AppShell()),
          );
        }
      }
    } on DioException catch (e) {
      final errorMsg =
          e.response?.data?['detail']?.toString() ??
          'Connection error: ${e.message}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Custom light theme to match the white login page mockup 1:1
    final lightTheme = ThemeData.light().copyWith(
      scaffoldBackgroundColor: Colors.white,
      primaryColor: const Color(0xFF13587A),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF13587A), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: GoogleFonts.inter(
          color: const Color(0xFF9CA3AF),
          fontSize: 14,
        ),
        prefixIconColor: const Color(0xFF6B7280),
        suffixIconColor: const Color(0xFF111827),
      ),
    );

    return Theme(
      data: lightTheme,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // Top-Left Logo: logo-2.png (ACTA logo with "forecast into action" text)
              Positioned(
                top: 0,
                left: 0,
                child: Image.asset(
                  'lib/assets/logo-2.png',
                  height: 130,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shield,
                          color: Color(0xFF13587A),
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'ACTA',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF13587A),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Centered Main Content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Central Shield-Owl Logo: logo-1.png
                          Image.asset(
                            'lib/assets/logo-1.png',
                            height: 72,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.shield,
                                color: Color(0xFF13587A),
                                size: 72,
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // Title
                          Text(
                            _isLoginMode ? 'Command Access' : 'Create Account',
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF111827),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Subtitle
                          Text(
                            _isLoginMode
                                ? 'Please log in to continue'
                                : 'Please register to continue',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Register Only Fields: First Name & Last Name
                          if (!_isLoginMode) ...[
                            TextFormField(
                              controller: _firstNameController,
                              keyboardType: TextInputType.name,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF111827),
                              ),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  size: 20,
                                ),
                                hintText: 'First Name',
                              ),
                              validator: (value) {
                                if (!_isLoginMode &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Please enter your first name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _lastNameController,
                              keyboardType: TextInputType.name,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF111827),
                              ),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  size: 20,
                                ),
                                hintText: 'Last Name',
                              ),
                              validator: (value) {
                                if (!_isLoginMode &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Please enter your last name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Username / Email input field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF111827),
                            ),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                              hintText: 'juan.reyes@gmail.com',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(
                                r'^[^@]+@[^@]+\.[^@]+$',
                              ).hasMatch(value.trim())) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password input field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF111827),
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                size: 20,
                              ),
                              hintText: '••••••••••',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (!_isLoginMode && value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Remember Me & Forgot Password Row (Only shown in Login Mode)
                          if (_isLoginMode) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Remember me checkbox
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        activeColor: const Color(0xFF13587A),
                                        checkColor: Colors.white,
                                        side: const BorderSide(
                                          color: Color(0xFF111827),
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            _rememberMe = val ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Remember Me',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: const Color(0xFF374151),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),

                                // Forgot password link
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Forgot password?',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF2B8BB1),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ] else ...[
                            const SizedBox(height: 8),
                          ],

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF13587A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: _isLoading ? null : _handleSubmit,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _isLoginMode ? 'Sign in' : 'Register',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.arrow_forward,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Login / Register Mode Toggle Link
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isLoginMode = !_isLoginMode;
                                _formKey.currentState?.reset();
                              });
                            },
                            child: Text(
                              _isLoginMode
                                  ? "Don't have an account? Sign up"
                                  : "Already have an account? Sign in",
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF2B8BB1),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Security Footer Note
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                size: 16,
                                color: Color(0xFF111827),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Authorized disaster operations personnel only',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF111827),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
