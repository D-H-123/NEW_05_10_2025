import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/auth_service.dart';
import 'package:go_router/go_router.dart';

void main() {
  runApp(const SignupPage());
}

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Receipt Auth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _heroController;
  late AnimationController _bannerController;
  late AnimationController _cardsController;
  late AnimationController _bottomController;
  late AnimationController _cardExpansionController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _heroAnimation;
  late Animation<Offset> _bannerAnimation;
  late Animation<Offset> _cardsAnimation;
  late Animation<Offset> _bottomAnimation;
  late Animation<double> _cardExpansionAnimation;
  
  bool _isLoading = false;
  bool _oauthInProgress = false;
  bool _isSignInExpanded = false;
  bool _isSignUpExpanded = false;
  
  final _signUpFormKey = GlobalKey<FormState>();
  final _signInFormKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Main animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    // Staggered animation controllers
    _heroController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _bannerController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _cardsController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _bottomController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _cardExpansionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // Animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _heroAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOutCubic,
    ));
    
    _bannerAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bannerController,
      curve: Curves.easeOutCubic,
    ));
    
    _cardsAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardsController,
      curve: Curves.easeOutCubic,
    ));
    
    _bottomAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bottomController,
      curve: Curves.easeOutCubic,
    ));
    
    _cardExpansionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardExpansionController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start staggered animations
    _startStaggeredAnimations();
  }
  
  void _startStaggeredAnimations() {
    _heroController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      _bannerController.forward();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      _cardsController.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      _bottomController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _heroController.dispose();
    _bannerController.dispose();
    _cardsController.dispose();
    _bottomController.dispose();
    _cardExpansionController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    HapticFeedback.mediumImpact();
    
    final form = _signUpFormKey;
    if (!form.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // TODO: Replace with actual API call
      await _authenticateUser();
      
      // Navigate to home page on success
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
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

  Future<void> _authenticateUser() async {
    final authService = AuthService();
    
    // Sign Up
    await authService.signUp(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  void _handleSkip() {
    HapticFeedback.lightImpact();
    context.go('/home');
  }
  
  void _expandSignInCard() {
    setState(() {
      _isSignInExpanded = true;
      _isSignUpExpanded = false;
    });
    _cardExpansionController.forward();
  }
  
  void _expandSignUpCard() {
    setState(() {
      _isSignUpExpanded = true;
      _isSignInExpanded = false;
    });
    _cardExpansionController.forward();
  }
  
  void _collapseCards() {
    setState(() {
      _isSignInExpanded = false;
      _isSignUpExpanded = false;
    });
    _cardExpansionController.reverse();
  }

  void _handleGoogleSignIn() async {
    if (_oauthInProgress || _isLoading) return;
    HapticFeedback.lightImpact();
    setState(() { _oauthInProgress = true; });
    try {
      final userCredential = await AuthService().signInWithGoogle();
      if (!mounted) return;
      if (userCredential != null) {
        context.go('/home');
      }
    } on Exception catch (e) {
      final message = e.toString();
      if (!message.contains('web-context-already-presented')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Sign-In failed')),
          );
        }
      }
    } finally {
      if (mounted) setState(() { _oauthInProgress = false; });
    }
  }

  void _handleAppleSignIn() {
    HapticFeedback.lightImpact();
    // TODO: Implement Apple Sign In
    print('Apple Sign In pressed');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 768;
    final isDesktop = screenWidth > 1024;
    final horizontalPadding = isTablet ? 32.0 : 20.0;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4169E1), // Royal Blue
              Color(0xFF6B46C1), // Purple
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(horizontalPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 440 : double.infinity,
                  minWidth: 0,
                ),
                child: Column(
                    children: [
                      // Hero Section (Top 30% of screen)
                      SlideTransition(
                        position: _heroAnimation,
                        child: FadeTransition(
                          opacity: _heroController,
                          child: _buildHeroSection(),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Social Proof Banner
                      SlideTransition(
                        position: _bannerAnimation,
                        child: FadeTransition(
                          opacity: _bannerController,
                          child: _buildSocialProofBanner(),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Primary Action Cards
                      SlideTransition(
                        position: _cardsAnimation,
                        child: FadeTransition(
                          opacity: _cardsController,
                          child: _buildActionCards(),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Bottom Section
                      SlideTransition(
                        position: _bottomAnimation,
                        child: FadeTransition(
                          opacity: _bottomController,
                          child: _buildBottomSection(),
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

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App logo/icon only
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.receipt_long,
              size: 40,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialProofBanner() {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.95),
            Colors.white.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            blurRadius: 1,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // User avatars (overlapping)
          SizedBox(
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 0,
                  child: _buildUserAvatar('👩‍💼', 'Sarah'),
                ),
                Positioned(
                  left: 24,
                  child: _buildUserAvatar('👨‍💻', 'Mike'),
                ),
                Positioned(
                  left: 48,
                  child: _buildUserAvatar('👩‍🎓', 'Emma'),
                ),
                Positioned(
                  left: 72,
                  child: _buildUserAvatar('👨‍🏫', 'David'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Main text
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              children: [
                const TextSpan(text: 'Join 127,000+ users saving '),
                TextSpan(
                  text: '\$847/month',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
                const TextSpan(text: ' on average'),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⭐⭐⭐⭐⭐', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Text(
                '4.9/5 from 23,847 reviews',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String emoji, String name) {
    return Tooltip(
      message: name,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCards() {
    return Column(
      children: [
        // Sign In Card
        AnimatedBuilder(
          animation: _cardExpansionAnimation,
          builder: (context, child) {
            return _isSignInExpanded 
                ? _buildExpandedSignInCard()
                : _buildSignInCard();
          },
        ),
        
        const SizedBox(height: 16),
        
        // Sign Up Card
        AnimatedBuilder(
          animation: _cardExpansionAnimation,
          builder: (context, child) {
            return _isSignUpExpanded 
                ? _buildExpandedSignUpCard()
                : _buildSignUpCard();
          },
        ),
      ],
    );
  }

  Widget _buildSignInCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFF8FAFC),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const Text('📧', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          const Text(
            'Already tracking your money?',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Sign In with Email button
          _buildPrimaryButton(
            text: 'Sign In with Email',
            onPressed: _expandSignInCard,
          ),
          
          const SizedBox(height: 16),
          
          // Divider
          _buildDivider('or'),
          
          const SizedBox(height: 16),
          
          // Social buttons
          Row(
            children: [
              Expanded(
                child: _buildSocialButton(
                  icon: '🔍',
                  label: 'Google',
                  onPressed: _handleGoogleSignIn,
                  backgroundColor: Colors.white,
                  textColor: const Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSocialButton(
                  icon: '🍎',
                  label: 'Apple',
                  onPressed: _handleAppleSignIn,
                  backgroundColor: Colors.black,
                  textColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFF8FAFC),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                'Start Free Trial',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Benefits
          Column(
            children: [
              _buildBenefitItem('📊 Track unlimited receipts'),
              _buildBenefitItem('💳 No credit card required'),
              _buildBenefitItem('🔒 Bank-level security'),
              _buildBenefitItem('📱 Works on all devices'),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Start Tracking Free button
          _buildPrimaryButton(
            text: 'Start Tracking Free',
            onPressed: _expandSignUpCard,
            isLoading: _isLoading,
          ),
          
          const SizedBox(height: 16),
          
          // Divider
          _buildDivider('or'),
          
          const SizedBox(height: 16),
          
          // Social buttons
          Row(
            children: [
              Expanded(
                child: _buildSocialButton(
                  icon: '🔍',
                  label: 'Google',
                  onPressed: _handleGoogleSignIn,
                  backgroundColor: Colors.white,
                  textColor: const Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSocialButton(
                  icon: '🍎',
                  label: 'Apple',
                  onPressed: _handleAppleSignIn,
                  backgroundColor: Colors.black,
                  textColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedSignInCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFF8FAFC),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Form(
        key: _signInFormKey,
        child: Column(
          children: [
            // Header with back button
            Row(
              children: [
                GestureDetector(
                  onTap: _collapseCards,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('📧', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Enter your credentials',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Email input
            _buildInputField(
              controller: _emailController,
              label: 'Email Address',
              icon: Icons.email_outlined,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Email is required';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Password input
            _buildInputField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Password is required';
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Remember me checkbox
            Row(
              children: [
                _buildCheckbox(false, (value) {}),
                const SizedBox(width: 12),
                const Text(
                  'Remember me for 30 days',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Sign In button
            _buildPrimaryButton(
              text: 'Sign In Securely',
              onPressed: _handleSubmit,
              isLoading: _isLoading,
            ),
            
            const SizedBox(height: 16),
            
            // Forgot password link
            GestureDetector(
              onTap: () {
                // TODO: Implement forgot password
              },
              child: const Text(
                'Forgot your password?',
                style: TextStyle(
                  color: Color(0xFF8B5CF6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedSignUpCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFF8FAFC),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Form(
        key: _signUpFormKey,
        child: Column(
          children: [
            // Header with back button
            Row(
              children: [
                GestureDetector(
                  onTap: _collapseCards,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('✨', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Text(
                  'Start Free Trial',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Create your free account',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Name input (optional)
            _buildInputField(
              controller: _nameController,
              label: 'Full Name (Optional)',
              icon: Icons.person_outline,
            ),
            
            const SizedBox(height: 16),
            
            // Email input
            _buildInputField(
              controller: _emailController,
              label: 'Email Address',
              icon: Icons.email_outlined,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Email is required';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Password input
            _buildInputField(
              controller: _passwordController,
              label: 'Create Password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Password is required';
                if (value!.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Terms checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCheckbox(false, (value) {}),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms & Privacy Policy',
                          style: TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Create Account button
            _buildPrimaryButton(
              text: 'Create Account',
              onPressed: _handleSubmit,
              isLoading: _isLoading,
            ),
            
            const SizedBox(height: 16),
            
            // Sign In link
            GestureDetector(
              onTap: _expandSignInCard,
              child: const Text(
                'Already have an account? Sign In',
                style: TextStyle(
                  color: Color(0xFF8B5CF6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Text('•', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isFocused = false;
        bool obscureText = isPassword;
        
        return Focus(
          onFocusChange: (focused) {
            setState(() {
              isFocused = focused;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isFocused 
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFFE5E7EB),
                width: isFocused ? 2 : 1.5,
              ),
            ),
            child: TextFormField(
              controller: controller,
              obscureText: obscureText,
              validator: validator,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: isFocused 
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFF6B7280),
                  fontSize: isFocused ? 12 : 15,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  icon,
                  color: isFocused 
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFF9CA3AF),
                  size: 20,
                ),
                suffixIcon: isPassword
                    ? IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off : Icons.visibility,
                          color: const Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureText = !obscureText;
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                floatingLabelBehavior: FloatingLabelBehavior.auto,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckbox(bool value, ValueChanged<bool?> onChanged) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isPressed = false;
        
        return GestureDetector(
          onTapDown: (_) {
            setState(() {
              isPressed = true;
            });
          },
          onTapUp: (_) {
            setState(() {
              isPressed = false;
            });
            onChanged(!value);
          },
          onTapCancel: () {
            setState(() {
              isPressed = false;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value 
                  ? const Color(0xFF8B5CF6)
                  : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value 
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFFD1D5DB),
                width: 2,
              ),
              boxShadow: isPressed
                  ? [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            transform: Matrix4.identity()..scale(isPressed ? 0.95 : 1.0),
            child: value
                ? const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isPressed = false;
        
        return GestureDetector(
          onTapDown: (_) {
            if (!isLoading) {
              setState(() {
                isPressed = true;
              });
            }
          },
          onTapUp: (_) {
            if (!isLoading) {
              setState(() {
                isPressed = false;
              });
              onPressed();
            }
          },
          onTapCancel: () {
            if (!isLoading) {
              setState(() {
                isPressed = false;
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF8B5CF6),
                  const Color(0xFF3B82F6),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(isPressed ? 0.4 : 0.3),
                  blurRadius: isPressed ? 8 : 12,
                  offset: Offset(0, isPressed ? 2 : 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            transform: Matrix4.identity()..scale(isPressed ? 0.98 : 1.0),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDivider(String text) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFFE5E7EB),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFFE5E7EB),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required String icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isPressed = false;
        
        return GestureDetector(
          onTapDown: (_) {
            setState(() {
              isPressed = true;
            });
          },
          onTapUp: (_) {
            setState(() {
              isPressed = false;
            });
            onPressed();
          },
          onTapCancel: () {
            setState(() {
              isPressed = false;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            height: 48,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: backgroundColor == Colors.white 
                    ? const Color(0xFFE5E7EB) 
                    : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    backgroundColor == Colors.white 
                        ? (isPressed ? 0.08 : 0.04) 
                        : (isPressed ? 0.15 : 0.1)
                  ),
                  blurRadius: isPressed ? 4 : 6,
                  offset: Offset(0, isPressed ? 1 : 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            transform: Matrix4.identity()..scale(isPressed ? 0.98 : 1.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  icon,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        // Skip button
        StatefulBuilder(
          builder: (context, setState) {
            bool isPressed = false;
            
            return GestureDetector(
              onTapDown: (_) {
                setState(() {
                  isPressed = true;
                });
              },
              onTapUp: (_) {
                setState(() {
                  isPressed = false;
                });
                _handleSkip();
              },
              onTapCancel: () {
                setState(() {
                  isPressed = false;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(isPressed ? 0.1 : 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(isPressed ? 0.3 : 0.1),
                    width: 1,
                  ),
                ),
                transform: Matrix4.identity()..scale(isPressed ? 0.98 : 1.0),
                child: Text(
                  'Skip for now - Try without account',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8B5CF6).withOpacity(isPressed ? 0.8 : 1.0),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 16),
        
        // Security badge
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🔒', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  'Your data is encrypted & secure',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTrustIndicator('🛡️', 'GDPR Compliant'),
                const SizedBox(width: 16),
                _buildTrustIndicator('✓', '256-bit SSL'),
                const SizedBox(width: 16),
                _buildTrustIndicator('🔐', 'Data Never Sold'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustIndicator(String icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}