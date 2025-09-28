import 'package:flutter/material.dart';

/// User-friendly loading components that hide technical complexity
/// Inspired by successful apps like Adobe Scan, CamScanner, and Expensify

class UserFriendlyLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final double progress;
  final Widget child;

  const UserFriendlyLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.message,
    this.progress = 0.0,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: _buildLoadingCard(context),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAnimatedIcon(),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (progress > 0) ...[
            _buildProgressBar(),
            const SizedBox(height: 12),
            Text(
              '${(progress * 100).toInt()}% complete',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ] else ...[
            _buildPulsingDots(),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.camera_alt,
        size: 40,
        color: Colors.blue,
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      width: 200,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 600 + (index * 200)),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

/// Step-by-step processing pipeline with user-friendly messages
class ProcessingPipeline extends StatefulWidget {
  final List<ProcessingStep> steps;
  final int currentStep;
  final bool isCompleted;

  const ProcessingPipeline({
    super.key,
    required this.steps,
    required this.currentStep,
    this.isCompleted = false,
  });

  @override
  State<ProcessingPipeline> createState() => _ProcessingPipelineState();
}

class _ProcessingPipelineState extends State<ProcessingPipeline>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Current step
          FadeTransition(
            opacity: _fadeAnimation,
            child: _buildCurrentStep(),
          ),
          const SizedBox(height: 24),
          // Progress indicator
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (widget.isCompleted) {
      return _buildCompletedStep();
    }

    final currentStepData = widget.steps[widget.currentStep];
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            currentStepData.icon,
            size: 50,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          currentStepData.message,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          currentStepData.subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCompletedStep() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 50,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Perfect! Found your receipt',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap to see the details',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return const SizedBox.shrink(); // Completely remove progress indicator
  }
}

/// Individual processing step data
class ProcessingStep {
  final String message;
  final String subtitle;
  final IconData icon;
  final Color color;

  const ProcessingStep({
    required this.message,
    required this.subtitle,
    required this.icon,
    this.color = Colors.blue,
  });
}

/// Predefined processing steps for receipt scanning
class ReceiptProcessingSteps {
  static const List<ProcessingStep> steps = [
    ProcessingStep(
      message: 'Scanning your receipt...',
      subtitle: 'Getting ready to read',
      icon: Icons.camera_alt,
    ),
    ProcessingStep(
      message: 'Getting ready to read...',
      subtitle: 'Almost there!',
      icon: Icons.auto_fix_high,
    ),
    ProcessingStep(
      message: 'Reading the text...',
      subtitle: 'Just a moment',
      icon: Icons.text_fields,
    ),
    ProcessingStep(
      message: 'Almost done!',
      subtitle: 'Final touches',
      icon: Icons.touch_app,
    ),
  ];
}

/// Simple success feedback widget
class ReceiptScanSuccess extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final String subtitle;

  const ReceiptScanSuccess({
    super.key,
    required this.onTap,
    this.title = 'Perfect! Found your receipt',
    this.subtitle = 'Tap to see the details',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }
}
