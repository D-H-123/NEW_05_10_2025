import 'package:flutter/material.dart';

/// Simple camera guidance overlay inspired by successful receipt scanning apps
class CameraGuidanceOverlay extends StatelessWidget {
  final bool showPositioningHints;
  final bool showQualityMeter;
  final bool showStabilityIndicator;
  final VoidCallback? onOptimalPosition;
  final String message;
  final String hint;

  const CameraGuidanceOverlay({
    super.key,
    this.showPositioningHints = true,
    this.showQualityMeter = false,
    this.showStabilityIndicator = false,
    this.onOptimalPosition,
    this.message = 'Point camera at your receipt',
    this.hint = 'Keep it flat and well-lit',
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showStabilityIndicator) ...[
              _buildStabilityIndicator(),
              const SizedBox(height: 16),
            ],
            _buildMainMessage(),
            const SizedBox(height: 8),
            _buildHint(),
            if (showQualityMeter) ...[
              const SizedBox(height: 16),
              _buildQualityMeter(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStabilityIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 16,
          ),
          SizedBox(width: 8),
          Text(
            'Perfect position!',
            style: TextStyle(
              color: Colors.green,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainMessage() {
    return Text(
      message,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildHint() {
    return Text(
      hint,
      style: TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 14,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildQualityMeter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility,
            color: Colors.white.withOpacity(0.8),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Good quality',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ready to scan button with engaging animation
class ReadyToScanButton extends StatefulWidget {
  final VoidCallback onTap;
  final String text;
  final bool isEnabled;

  const ReadyToScanButton({
    super.key,
    required this.onTap,
    this.text = 'Tap to scan',
    this.isEnabled = true,
  });

  @override
  State<ReadyToScanButton> createState() => _ReadyToScanButtonState();
}

class _ReadyToScanButtonState extends State<ReadyToScanButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (widget.isEnabled) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ReadyToScanButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled && !oldWidget.isEnabled) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isEnabled && oldWidget.isEnabled) {
      _pulseController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isEnabled ? _pulseAnimation.value : 1.0,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isEnabled
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              border: Border.all(
                color: widget.isEnabled ? Colors.blue : Colors.grey,
                width: 3,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isEnabled ? widget.onTap : null,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isEnabled
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: widget.isEnabled ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.text,
                          style: TextStyle(
                            color: widget.isEnabled ? Colors.blue : Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
      },
    );
  }
}

/// Simple positioning hints
class PositioningHints extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;

  const PositioningHints({
    super.key,
    required this.message,
    required this.icon,
    this.color = Colors.orange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
