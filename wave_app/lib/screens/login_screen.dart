import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // Added provider
import '../theme/app_theme.dart'; // Added AppTheme
import '../providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Dynamic Background
          Positioned.fill(
            child: _buildBackground(),
          ),
          
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    
                    // Logo / Icon
                    _buildLogo(),
                    
                    const SizedBox(height: 40),
                    
                    // Text Content
                    _buildHeroText(),
                    
                    const SizedBox(height: 100),
                    
                    // Login Card
                    _buildLoginCard(context),
                    
                    if (context.watch<AuthProvider>().isAuthenticated)
                      _buildGoogleWalletInfo(context),
                    
                    const SizedBox(height: 48),
                    
                    // Footer
                    _buildFooter(),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        // Base dark color
        Container(color: AppTheme.bg),
        
        // Animated-like static gradients
        Positioned(
          top: -100,
          right: -100,
          child: _CircleGradient(
            size: 400,
            color: AppTheme.accent.withOpacity(0.15),
          ),
        ),
        Positioned(
          bottom: -50,
          left: -50,
          child: _CircleGradient(
            size: 300,
            color: AppTheme.accent2.withOpacity(0.1),
          ),
        ),
        
        // Glassmorphism Blur
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildHeroText() {
    return Column(
      children: [
        Text(
          'wave.',
          style: GoogleFonts.syne(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your music, redefined with Web3.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 16,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            auth.isAuthenticated ? 'Welcome Back' : 'Get Started',
            style: GoogleFonts.syne(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            auth.isAuthenticated 
                ? 'Your secure Monad wallet is ready.\nStart predicting and earning.'
                : 'Sign in with Google to automatically\ngenerate your Monad testnet wallet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 32),
          
          if (!auth.isAuthenticated)
            _buildGoogleButton(context),
          
          if (auth.isAuthenticated) ...[
            _buildGoogleWalletInfo(context),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => auth.signOut(),
              child: Text('Sign Out', style: GoogleFonts.dmSans(color: Colors.redAccent.shade100, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoogleButton(BuildContext context) {
    final auth = context.read<AuthProvider>();
    
    return GestureDetector(
      onTap: () => auth.signInWithGoogle(),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                height: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Continue with Google',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleWalletInfo(BuildContext context) {
    final auth = context.read<AuthProvider>();
    
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_wallet_rounded, color: Colors.blueAccent, size: 16),
          const SizedBox(width: 8),
          Text(
            'Google Wallet: ${auth.derivedAddress?.substring(0, 8)}...${auth.derivedAddress?.substring(36)}',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blueAccent.shade100,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Powered by Reown AppKit',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted.withOpacity(0.4),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dot(),
            _dot(),
            _dot(),
          ],
        ),
      ],
    );
  }

  Widget _dot() {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.textMuted.withOpacity(0.2),
      ),
    );
  }
}

class _CircleGradient extends StatelessWidget {
  final double size;
  final Color color;

  const _CircleGradient({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0),
          ],
        ),
      ),
    );
  }
}
