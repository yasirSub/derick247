import 'package:flutter/material.dart';
import 'dart:math';

class HomeCounterData {
  final CounterRange inventory;
  final CounterRange earnings;

  const HomeCounterData({required this.inventory, required this.earnings});

  factory HomeCounterData.fromJson(Map<String, dynamic> json) {
    final inventoryJson = json['inventoryTotal'] ?? {};
    final earningsJson = json['earningsTotal'] ?? {};

    return HomeCounterData(
      inventory: CounterRange.fromJson(inventoryJson),
      earnings: CounterRange.fromJson(earningsJson),
    );
  }
}

class CounterRange {
  final double minValue;
  final double maxValue;

  const CounterRange({required this.minValue, required this.maxValue});

  factory CounterRange.fromJson(Map<String, dynamic> json) {
    return CounterRange(
      minValue: (json['min_value'] ?? 0).toDouble(),
      maxValue: (json['max_value'] ?? 0).toDouble(),
    );
  }
}

class HomeCounterSection extends StatelessWidget {
  final HomeCounterData data;

  const HomeCounterSection({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive sizing based on screen width
        final screenWidth = constraints.maxWidth;
        final isSmallScreen = screenWidth < 360;
        final isMediumScreen = screenWidth < 400;

        // Compact sizing for all screens
        final horizontalSpacing = isSmallScreen
            ? 8.0
            : isMediumScreen
            ? 10.0
            : 12.0;
        final cardHeight = isSmallScreen
            ? 70.0
            : isMediumScreen
            ? 75.0
            : 80.0;
        final contentPadding = EdgeInsets.all(isSmallScreen ? 8.0 : 10.0);
        final numberFontSize = isSmallScreen
            ? 14.0
            : isMediumScreen
            ? 16.0
            : 18.0;
        final labelFontSize = isSmallScreen ? 10.0 : 11.0;
        final gap = isSmallScreen ? 4.0 : 6.0;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen
                ? 10
                : isMediumScreen
                ? 12
                : 14,
            vertical: isSmallScreen ? 6 : 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: AnimatedCounterCard(
                  label: 'Inventory Value',
                  minValue: data.inventory.minValue,
                  maxValue: data.inventory.maxValue,
                  colors: const [Color(0xFF6A00F4), Color(0xFF2680EB)],
                  cardHeight: cardHeight,
                  contentPadding: contentPadding,
                  numberFontSize: numberFontSize,
                  labelFontSize: labelFontSize,
                  labelGap: gap,
                ),
              ),
              SizedBox(width: horizontalSpacing),
              Expanded(
                child: AnimatedCounterCard(
                  label: 'Total Earnings',
                  minValue: data.earnings.minValue,
                  maxValue: data.earnings.maxValue,
                  colors: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                  cardHeight: cardHeight,
                  contentPadding: contentPadding,
                  numberFontSize: numberFontSize,
                  labelFontSize: labelFontSize,
                  labelGap: gap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AnimatedCounterCard extends StatefulWidget {
  final String label;
  final double minValue;
  final double maxValue;
  final List<Color> colors;
  final Duration cycleDuration;
  final double cardHeight;
  final EdgeInsetsGeometry contentPadding;
  final double numberFontSize;
  final double labelFontSize;
  final double labelGap;

  const AnimatedCounterCard({
    Key? key,
    required this.label,
    required this.minValue,
    required this.maxValue,
    required this.colors,
    this.cycleDuration = const Duration(
      seconds: 1209600,
    ), // Ultra slow animation (~14 days)
    this.cardHeight = 90,
    this.contentPadding = const EdgeInsets.all(12),
    this.numberFontSize = 22,
    this.labelFontSize = 12,
    this.labelGap = 8,
  }) : super(key: key);

  @override
  State<AnimatedCounterCard> createState() => _AnimatedCounterCardState();
}

class _AnimatedCounterCardState extends State<AnimatedCounterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<int>? _decimalAnimation;
  Animation<double>? _fullValueAnimation;
  bool _isForward = true;
  late int _staticIntegerPart;
  late int _minDecimalMicro;
  late int _maxDecimalMicro;
  late int _decimalPrecision; // Actual decimal precision from API
  int _displayPrecision = 6;
  bool _useFullValueAnimation = false;
  bool _hasAnimation = false; // Only animate when range differs
  bool _animationReady = false;
  double? _minValue;
  double? _maxValue;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.cycleDuration,
    );
    _setupBounds();
    if (_hasAnimation) {
      _setupAnimation();
    } else {
      _animationReady = true;
    }
  }

  void _setupBounds() {
    final minValueStr = widget.minValue.toString();
    final maxValueStr = widget.maxValue.toString();

    int minPrecision = 0;
    int maxPrecision = 0;

    if (minValueStr.contains('.')) {
      minPrecision = minValueStr.split('.')[1].length;
    }
    if (maxValueStr.contains('.')) {
      maxPrecision = maxValueStr.split('.')[1].length;
    }

    _displayPrecision = max(minPrecision, maxPrecision);
    if (_displayPrecision == 0) {
      _displayPrecision = 2;
    }

    final minInt = widget.minValue.truncate();
    final maxInt = widget.maxValue.truncate();

    _useFullValueAnimation = minInt != maxInt;
    _minValue = widget.minValue;
    _maxValue = widget.maxValue;

    if (_useFullValueAnimation) {
      _hasAnimation = (_minValue != _maxValue);
      return;
    }

    // Integers are identical, animate only decimal part
    _staticIntegerPart = minInt;

    final minDecimal =
        widget.minValue - widget.minValue.truncate(); // Fractional part only
    final maxDecimal = widget.maxValue - widget.maxValue.truncate();

    _decimalPrecision = _displayPrecision;
    final precisionFactor = pow(10, _decimalPrecision).toInt();

    _minDecimalMicro = (minDecimal * precisionFactor).round();
    _maxDecimalMicro = (maxDecimal * precisionFactor).round();

    _hasAnimation = _minDecimalMicro != _maxDecimalMicro;

    if (!_hasAnimation) {
      _minDecimalMicro = _maxDecimalMicro;
    }
  }

  void _setupAnimation() {
    if (!_hasAnimation) {
      _animationReady = true;
      return;
    }

    _animationReady = false;

    if (_useFullValueAnimation) {
      final begin = _isForward ? _minValue! : _maxValue!;
      final end = _isForward ? _maxValue! : _minValue!;
      _fullValueAnimation =
          Tween<double>(begin: begin, end: end).animate(
            CurvedAnimation(parent: _controller, curve: Curves.linear),
          )..addStatusListener((status) {
            if (status == AnimationStatus.completed ||
                status == AnimationStatus.dismissed) {
              _isForward = !_isForward;
              _controller.forward(from: 0);
            }
          });
    } else {
      final begin = _isForward ? _minDecimalMicro : _maxDecimalMicro;
      final end = _isForward ? _maxDecimalMicro : _minDecimalMicro;
      _decimalAnimation =
          IntTween(begin: begin, end: end).animate(
            CurvedAnimation(parent: _controller, curve: Curves.linear),
          )..addStatusListener((status) {
            if (status == AnimationStatus.completed ||
                status == AnimationStatus.dismissed) {
              _isForward = !_isForward;
              _controller.forward(from: 0);
            }
          });
    }

    _animationReady = true;
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant AnimatedCounterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minValue != widget.minValue ||
        oldWidget.maxValue != widget.maxValue) {
      _controller.duration = widget.cycleDuration;
      _setupBounds();
      _isForward = true;
      _setupAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDecimalValue(int decimalMicroValue) {
    final decimalStr = decimalMicroValue.abs().toString().padLeft(
      _decimalPrecision,
      '0',
    );
    return '$_staticIntegerPart.$decimalStr';
  }

  String _formatFullValue(double value) {
    return value.toStringAsFixed(_displayPrecision);
  }

  @override
  Widget build(BuildContext context) {
    if (!_animationReady) {
      return _buildSkeleton();
    }

    // If no animation needed, show static value
    if (!_hasAnimation) {
      return _buildStaticCard();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final valueText = _useFullValueAnimation
            ? _formatFullValue(_fullValueAnimation!.value)
            : _formatDecimalValue(_decimalAnimation!.value);
        return Container(
          height: widget.cardHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: widget.colors.last.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: widget.contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      painter: _GridPainter(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Text(
                            valueText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF7CF3FF),
                              fontSize: widget.numberFontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: widget.labelGap),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.labelFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: widget.cardHeight,
      decoration: BoxDecoration(
        color: widget.colors.last.withOpacity(0.2),
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  Widget _buildStaticCard() {
    final valueText = _useFullValueAnimation
        ? _formatFullValue(_minValue ?? widget.minValue)
        : _formatDecimalValue(_minDecimalMicro);
    return Container(
      height: widget.cardHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: widget.colors.last.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: widget.contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: _GridPainter(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        valueText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF7CF3FF),
                          fontSize: widget.numberFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: widget.labelGap),
            Text(
              widget.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.labelFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    const cellSize = 18.0;
    for (double x = 0; x <= size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
