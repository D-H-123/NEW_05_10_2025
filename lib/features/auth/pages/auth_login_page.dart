import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

class AuthLoginPage extends StatefulWidget {
  const AuthLoginPage({super.key});

  @override
  State<AuthLoginPage> createState() => _AuthLoginPageState();
}

class _AuthLoginPageState extends State<AuthLoginPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Form keys
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Login failed';
        
        if (e.toString().contains('invalid-credential')) {
          errorMessage = '❌ Invalid email or password. Please check and try again.';
        } else if (e.toString().contains('user-not-found')) {
          errorMessage = '❌ No account found with this email. Please sign up first.';
        } else if (e.toString().contains('wrong-password')) {
          errorMessage = '❌ Incorrect password. Please try again.';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = '❌ Invalid email format. Please check your email.';
        } else if (e.toString().contains('user-disabled')) {
          errorMessage = '❌ This account has been disabled.';
        } else if (e.toString().contains('too-many-requests')) {
          errorMessage = '❌ Too many failed attempts. Please try again later.';
        } else if (e.toString().contains('network-request-failed')) {
          errorMessage = '❌ Network error. Please check your internet connection.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignup() async {
    if (!_signupFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService().signUp(
        name: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Account created successfully! Welcome!'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Sign up failed';
        
        if (e.toString().contains('email-already-in-use')) {
          errorMessage = '❌ This email is already registered. Please log in instead.';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = '❌ Invalid email format. Please check your email.';
        } else if (e.toString().contains('weak-password')) {
          errorMessage = '❌ Password is too weak. Use at least 6 characters.';
        } else if (e.toString().contains('network-request-failed')) {
          errorMessage = '❌ Network error. Please check your internet connection.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await AuthService().signInWithGoogle();
      if (userCredential != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Signed in with Google successfully!'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
          ),
        );
        context.go('/home');
      } else if (mounted) {
        // User cancelled the sign-in
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ℹ️ Google Sign-In was cancelled'),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Google Sign-In failed';
        
        if (e.toString().contains('network-request-failed')) {
          errorMessage = '❌ Network error. Please check your internet connection.';
        } else if (e.toString().contains('account-exists-with-different-credential')) {
          errorMessage = '❌ This email is already registered with a different method.';
        } else if (e.toString().contains('popup-closed-by-user')) {
          errorMessage = 'ℹ️ Sign-in popup was closed';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSkip() {
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button - top right
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 8),
                child: TextButton(
                  onPressed: _handleSkip,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    splashFactory: NoSplash.splashFactory, // Remove splash delay
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Color(0xFF16213e),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF16213e),
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  indicatorColor: const Color(0xFF16213e),
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Login'),
                    Tab(text: 'Sign up'),
                  ],
                ),
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginTab(),
                  _buildSignupTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Email field
            _buildInputField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Email is required';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Password field
            _buildInputField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              isPassword: true,
              obscureText: _obscurePassword,
              onTogglePassword: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Password is required';
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Login button
            _buildPrimaryButton(
              text: 'Login',
              onPressed: _handleLogin,
            ),

            const SizedBox(height: 16),

            // Sign up link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                GestureDetector(
                  onTap: () => _tabController.animateTo(1),
                  child: const Text(
                    'Sign up',
                    style: TextStyle(
                      color: Color(0xFF16213e),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Or divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'or',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),

            const SizedBox(height: 24),

            // Apple Sign In
            _buildSocialButton(
              text: 'Sign in with Apple',
              icon: Icons.apple,
              onPressed: () {
                // TODO: Implement Apple Sign In
              },
            ),

            const SizedBox(height: 12),

            // Google Sign In
            _buildSocialButton(
              text: 'Sign in with Google',
              icon: Icons.g_mobiledata,
              onPressed: _handleGoogleSignIn,
              isGoogle: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _signupFormKey,
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Username field
            _buildInputField(
              controller: _usernameController,
              label: 'Username',
              icon: Icons.person_outline,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Username is required';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Email field
            _buildInputField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Email is required';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Password field
            _buildInputField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              isPassword: true,
              obscureText: _obscurePassword,
              onTogglePassword: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Password is required';
                if (value!.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Confirm Password field
            _buildInputField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.lock_outline,
              isPassword: true,
              obscureText: _obscureConfirmPassword,
              onTogglePassword: () {
                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
              },
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Confirm password is required';
                if (value != _passwordController.text) return 'Passwords do not match';
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Create Account button
            _buildPrimaryButton(
              text: 'Create Account',
              onPressed: _handleSignup,
            ),

            const SizedBox(height: 16),

            // Login link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                GestureDetector(
                  onTap: () => _tabController.animateTo(0),
                  child: const Text(
                    'Log in',
                    style: TextStyle(
                      color: Color(0xFF16213e),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && obscureText,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF16213e),
                ),
                onPressed: onTogglePassword,
              )
            : Icon(icon, color: const Color(0xFF16213e)),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF16213e), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16213e),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    bool isGoogle = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFF16213e),
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF16213e)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isGoogle ? 32 : 24),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

