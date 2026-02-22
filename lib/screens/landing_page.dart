import 'package:flutter/material.dart';
import 'login_screen.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C12),
      body: Stack(
        children: [
          // 1. ELEVATED BACKGROUND AMBIENCE
          Positioned(
            top: -150,
            right: -100,
            child: _buildGlow(400, Colors.blueAccent.withAlpha(25)),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _buildGlow(350, Colors.blueAccent.withAlpha(15)),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    // Forces the content to at least fill the screen height
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(flex: 1),

                            // 2. REFINED LOGO PRESENTATION
                            _buildAnimatedEntry(
                              delay: 200,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white.withAlpha(10)),
                                  borderRadius: BorderRadius.circular(24),
                                  color: Colors.white.withAlpha(5),
                                ),
                                child: Image.asset(
                                  'assets/images/akie_logo.png', // Updated to match pubspec
                                  width: 280,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            const SizedBox(height: 48),

                            // 3. TYPOGRAPHY & VALUE PROPOSITION
                            _buildAnimatedEntry(
                              delay: 400,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "AKIE BARBERSHOP",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                      letterSpacing: -1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Text(
                                    "Welcome to your all-in-one solution for effortless financial management. Track daily sales, monitor expenses, and calculate staff commissions with ease.",
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(130),
                                      fontSize: 16,
                                      height: 1.8,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(flex: 2),

                            // 4. THE ACTION AREA
                            _buildAnimatedEntry(
                              delay: 800,
                              child: const ShimmerButton(),
                            ),

                            // Bottom spacing for visual balance
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
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

  // --- UI Helpers ---
  Widget _buildAnimatedEntry({required int delay, required Widget child}) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: delay + 900),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _buildGlow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 130, spreadRadius: 50),
        ],
      ),
    );
  }
}

/// Premium Glass-Shimmer Button
class ShimmerButton extends StatefulWidget {
  const ShimmerButton({super.key});
  @override
  State<ShimmerButton> createState() => _ShimmerButtonState();
}

class _ShimmerButtonState extends State<ShimmerButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: double.infinity,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2979FF),
                Color(0xFF1C63D9),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withAlpha(80),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [
                        _controller.value - 0.25,
                        _controller.value,
                        _controller.value + 0.25,
                      ],
                      colors: [
                        Colors.white.withAlpha(100),
                        Colors.white,
                        Colors.white.withAlpha(100),
                      ],
                    ).createShader(bounds);
                  },
                  child: child,
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "GET STARTED",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 2.0,
                    ),
                  ),
                  SizedBox(width: 14),
                  Icon(Icons.arrow_forward_ios_rounded, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}