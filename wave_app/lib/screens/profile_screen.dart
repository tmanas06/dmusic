import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Premium Header
          SliverAppBar(
            expandedHeight: 280,
            backgroundColor: AppTheme.bg,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blueAccent.withOpacity(0.15),
                      AppTheme.bg,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // Avatar with Glassmorphism
                    _buildAvatar(user?.photoURL),
                    const SizedBox(height: 16),
                    Text(
                      user?.displayName ?? 'Anonymous User',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.syne(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      user?.email ?? 'No email associated',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _buildSectionHeader('SOCIAL WALLET (MONAD)'),
                  const SizedBox(height: 16),
                  _buildWalletCard(auth),
                  const SizedBox(height: 32),
                  _buildSectionHeader('ACCOUNT STATS'),
                  const SizedBox(height: 16),
                  _buildStatsGrid(auth),
                  const SizedBox(height: 48),
                  
                  // Sign Out
                  Center(
                    child: TextButton.icon(
                      onPressed: () => auth.signOut(),
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      label: Text(
                        'SIGN OUT',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: Colors.redAccent,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        backgroundColor: Colors.redAccent.withOpacity(0.05),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 120), // Bottom space for mini player
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 2),
      ),
      child: CircleAvatar(
        radius: 50,
        backgroundColor: AppTheme.surface,
        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
        child: photoUrl == null ? const Icon(Icons.person_outline_rounded, size: 40, color: AppTheme.textMuted) : null,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: AppTheme.textMuted,
      ),
    );
  }

  Widget _buildWalletCard(AuthProvider auth) {
    final addr = auth.derivedAddress ?? '0x...';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance',
                      style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Text(
                            '${auth.balance.toStringAsFixed(4)} MON',
                            style: GoogleFonts.syne(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (auth.isFetchingBalance)
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                          else
                            GestureDetector(
                              onTap: () => auth.fetchBalance(),
                              child: Icon(Icons.refresh_rounded, size: 20, color: AppTheme.textMuted.withOpacity(0.5)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.waves_rounded, color: Colors.blueAccent, size: 32),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    addr,
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.copy_rounded, size: 16, color: AppTheme.textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(AuthProvider auth) {
    return Row(
      children: [
        Expanded(child: _buildStatItem('PREDICTIONS', auth.totalPredictions.toString(), Colors.blueAccent)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatItem('STREAK', '0 DAYS', Colors.orangeAccent)),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
