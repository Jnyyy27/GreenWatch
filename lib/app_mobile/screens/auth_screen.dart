import 'dart:ui';

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.toString().replaceAll('Exception: ', ''),
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFFEF5350),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
    _slideController.reset();
    _slideController.forward();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4CAF50);
    const primaryDark = Color(0xFF388E3C);
    const accent = Color(0xFF66BB6A);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/images/pclogin.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Animated background elements
            _buildBackgroundCircle(
              top: -120,
              right: -80,
              size: 280,
              color: primary.withOpacity(0.08),
            ),
            _buildBackgroundCircle(
              bottom: -100,
              left: -60,
              size: 240,
              color: accent.withOpacity(0.06),
            ),
            _buildBackgroundCircle(
              top: 200,
              left: -100,
              size: 300,
              color: primary.withOpacity(0.04),
            ),
            
            // Main content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLogo(),
                          const SizedBox(height: 48),
                          _buildAuthCard(primary, accent),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundCircle({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, const Color.fromARGB(0, 235, 235, 235)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Hero(
          tag: 'app_logo',
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4CAF50),
                  Color(0xFF66BB6A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF4CAF50).withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.eco_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'GreenWatch',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -1,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pulau Pinang',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color.fromARGB(255, 255, 254, 254).withOpacity(0.7),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard(Color primary, Color accent) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildFormFields(primary),
                    const SizedBox(height: 28),
                    _buildSubmitButton(primary, accent),
                    const SizedBox(height: 20),
                    _buildToggleButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          _isLogin ? 'Welcome Back' : 'Get Started',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLogin
              ? 'Sign in to continue monitoring'
              : 'Create your account to begin',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.65),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields(Color primary) {
    return Column(
      children: [
        if (!_isLogin) ...[
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
            validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
            primary: primary,
          ),
          const SizedBox(height: 16),
        ],
        _buildTextField(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) => value!.contains('@') ? null : 'Enter a valid email',
          primary: primary,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          validator: (value) => value!.length < 6 ? 'Minimum 6 characters required' : null,
          primary: primary,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.white.withOpacity(0.6),
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color primary,
    String? Function(String?)? validator,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 12, left: 12),
          child: Icon(icon, color: Colors.white.withOpacity(0.7), size: 22),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Color(0xFFEF5350), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Color(0xFFEF5350), width: 2),
        ),
        errorStyle: TextStyle(
          color: Color(0xFFFFCDD2),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      validator: validator,
    );
  }

  Widget _buildSubmitButton(Color primary, Color accent) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [primary, accent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _submit,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? 'Sign In' : 'Create Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isLogin ? Icons.login_rounded : Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isLogin ? "Don't have an account?" : "Already have an account?",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: _toggleMode,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _isLogin ? 'Sign Up' : 'Sign In',
              style: TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
