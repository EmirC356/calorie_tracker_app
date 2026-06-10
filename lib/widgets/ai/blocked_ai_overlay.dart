import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/ai_service.dart';
import '../../screens/settings/api_key_screen.dart';
import '../../theme/app_theme.dart';

/// Renders [child] and, when [isBlocked], overlays a 70% black scrim + a lock
/// card with an "Open Settings" CTA. The scrim absorbs taps to the underlying
/// child (via a ModalBarrier) while keeping the card's button tappable. Wrap a
/// Scaffold *body* (not the whole Scaffold) so the AppBar back button and system
/// gestures stay free.
///
/// Convenience: `myBody.lockedWhenNoKey(context)` (see [ScreenLock]) blocks the
/// body whenever the active AI provider has no key, reacting live via Provider.
class BlockedAiOverlay extends StatelessWidget {
  final Widget child;
  final bool isBlocked;
  final String? message;

  const BlockedAiOverlay({
    required this.child,
    required this.isBlocked,
    this.message,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!isBlocked) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Stack(
            children: [
              // Absorbs pointer events meant for the child below.
              const ModalBarrier(
                dismissible: false,
                color: Color(0xB3000000), // black @ 70%
              ),
              Center(child: _LockCard(message: message)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LockCard extends StatelessWidget {
  final String? message;
  const _LockCard({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAmber, width: 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_outline, color: kAmber, size: 52, shadows: [
          Shadow(color: kAmber.withValues(alpha: 0.6), blurRadius: 16),
        ]),
        const SizedBox(height: 16),
        const Text('AI features locked',
            style: TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          message ?? 'You need to add your API key to use this feature.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: kTextDim, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ApiKeyScreen())),
            style: ElevatedButton.styleFrom(
                backgroundColor: kAmber,
                foregroundColor: kBg,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

/// Wraps any widget (typically a Scaffold body) so it locks behind the overlay
/// whenever the active AI provider has no key. Uses `Provider.of<AiService>`
/// (watch) so the lock disappears the instant a key is configured.
extension ScreenLock on Widget {
  Widget lockedWhenNoKey(BuildContext context, {String? message}) {
    final hasKey = context.watch<AiService>().hasValidKey;
    return BlockedAiOverlay(isBlocked: !hasKey, message: message, child: this);
  }
}
