import 'package:flutter/material.dart';

/// Brand gold from the design guide (#D6AD07) — matches the native launch splash
/// so the handover is seamless.
const Color kSplashGold = Color(0xFFD6AD07);

/// The Flutter-drawn splash: gold field with the glossy circle mark centred and the
/// "DPOS · Powered by PT DIKA" wordmark in the bottom-right (per the design). Shown
/// briefly on cold start, then cross-faded into login/POS by the root gate.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: kSplashGold,
      body: Stack(
        children: [
          // Circle mark — centred, nudged slightly above the middle. The PNG carries
          // its own soft shadow + transparent margin, so it's sized a touch larger.
          Align(
            alignment: const Alignment(0, -0.06),
            child: Image.asset(
              'assets/images/splash_circle.png',
              width: w * 0.52,
              fit: BoxFit.contain,
            ),
          ),
          // Wordmark — bottom-right.
          Positioned(
            right: 20,
            bottom: 32,
            child: Image.asset(
              'assets/images/splash_wordmark.png',
              width: w * 0.42,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
