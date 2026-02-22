import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/counter_provider.dart';
import 'counter_screen.dart';
import 'dart:ui';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  bool _isVerifying = false;
  
  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Smooth pulse for dots during verification
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Shake animation for error feedback
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // --- Premium Alert Logic ---

  void _showErrorOverlay() {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        child: const _PremiumTopAlert(),
      ),
    );

    overlay.insert(overlayEntry);
    // Automatically remove the alert after 2 seconds
    Future.delayed(const Duration(seconds: 2), () => overlayEntry.remove());
  }

  void _handleIncorrectPin() {
    // 1. Tactile Feedback
    HapticFeedback.vibrate();
    
    // 2. Visual Feedback (Shake the dots)
    _shakeController.forward(from: 0).then((_) => _shakeController.reverse());

    // 3. UI Alert (Floating top bar)
    _showErrorOverlay();

    setState(() {
      _pinController.text = "";
      _isVerifying = false;
    });
  }

  void _handlePinInput(String value) async {
    if (_isVerifying) return; 

    if (_pinController.text.length < 4) {
      setState(() => _pinController.text += value);
    }

    if (_pinController.text.length == 4) {
      setState(() => _isVerifying = true);
      final provider = context.read<CounterProvider>();
      
      try {
        await provider.fetchAppPin(); 
        await Future.delayed(const Duration(milliseconds: 300));

        if (_pinController.text == provider.appPin) {
          HapticFeedback.mediumImpact();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CounterScreen()),
            );
          }
        } else {
          _handleIncorrectPin();
        }
      } catch (e) {
        _handleIncorrectPin();
      }
    }
  }

  // --- UI Builders ---

  Widget _buildGlow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 100, spreadRadius: 50),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C12),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -50,
            child: _buildGlow(300, Colors.blueAccent.withAlpha(20)),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildGlow(250, Colors.blueAccent.withAlpha(15)),
          ),

          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                
                const Icon(Icons.lock_person_rounded, size: 60, color: Colors.blueAccent),
                const SizedBox(height: 24),
                const Text(
                  "AKIE BARBERSHOP",
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 22, 
                    fontWeight: FontWeight.w900, 
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Secure Access Required", 
                  style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 14),
                ),
                
                const SizedBox(height: 60),
                
                // PIN DOTS with Shake Transformation
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value * ( (_shakeController.value > 0.5) ? -1 : 1), 0),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      bool isFilled = _pinController.text.length > index;
                      return ScaleTransition(
                        scale: _isVerifying && isFilled 
                            ? Tween(begin: 1.0, end: 1.15).animate(_pulseController) 
                            : const AlwaysStoppedAnimation(1.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? Colors.blueAccent : Colors.white.withAlpha(10),
                            boxShadow: isFilled ? [
                              BoxShadow(
                                color: Colors.blueAccent.withAlpha(_isVerifying ? 150 : 80), 
                                blurRadius: _isVerifying ? 20 : 10,
                              )
                            ] : [],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                
                const Spacer(flex: 2),
                _buildKeypad(),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 50),
        crossAxisCount: 3,
        mainAxisSpacing: 25,
        crossAxisSpacing: 25,
        children: [
          ...List.generate(9, (index) => _buildKey("${index + 1}")),
          const SizedBox.shrink(),
          _buildKey("0"),
          _buildBackspace(),
        ],
      ),
    );
  }

  Widget _buildKey(String label) {
    return InkWell(
      onTap: () => _handlePinInput(label),
      borderRadius: BorderRadius.circular(50),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(5),
          border: Border.all(color: Colors.white.withAlpha(5)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBackspace() {
    return IconButton(
      icon: Icon(Icons.backspace_rounded, color: Colors.white.withAlpha(100), size: 24),
      onPressed: () {
        if (_pinController.text.isNotEmpty && !_isVerifying) {
          setState(() => _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1));
        }
      },
    );
  }
}

/// A high-end floating top alert component
class _PremiumTopAlert extends StatelessWidget {
  const _PremiumTopAlert();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: -100, end: 0),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, value),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Center( // Centers the pill horizontally
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // The "Glass" blur
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  // Semi-transparent dark fill
                  color: Colors.black.withOpacity(0.4), 
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1), // Subtle light border
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A slightly more "Apple" styled error icon
                    const Icon(
                      Icons.warning_amber_rounded, 
                      color: Colors.redAccent, 
                      size: 22
                    ),
                    const SizedBox(width: 12),
                    const Flexible(
                      child: Text(
                        "Invalid Access Pin",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2, // Tighter tracking like SF Pro
                        ),
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
}