import 'package:flutter/material.dart';

class CustomBottomNavigationBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigationBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  State<CustomBottomNavigationBar> createState() =>
      _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar>
    with TickerProviderStateMixin {
  Map<int, bool> _pressedTabs = {};
  Map<int, AnimationController> _glowControllers = {};
  Map<int, Animation<double>> _glowAnimations = {};

  @override
  void initState() {
    super.initState();
    // Initialize controllers for all tabs
    for (int i = 0; i < 4; i++) {
      _glowControllers[i] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 80), // Was 180ms, now ultra fast
      );
      _glowAnimations[i] = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _glowControllers[i]!, curve: Curves.easeOut),
      );
      _pressedTabs[i] = false;
    }
  }

  @override
  void dispose() {
    for (var controller in _glowControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTabTap(int index) {
    widget.onTap(index);

    // Trigger glow animation on tap
    setState(() {
      _pressedTabs[index] = true;
    });

    _glowControllers[index]!.forward().then((_) {
      // Keep glow visible briefly, then fade out
      Future.delayed(const Duration(milliseconds: 35), () {
        // Was 80ms, now ultra fast
        if (mounted) {
          _glowControllers[index]!.reverse().then((_) {
            if (mounted) {
              setState(() {
                _pressedTabs[index] = false;
              });
            }
          });
        }
      });
    });
  }

  void _onTabTapDown(int index, TapDownDetails details) {
    // Immediate visual feedback on tap down
    setState(() {
      _pressedTabs[index] = true;
    });
    _glowControllers[index]!.forward();
  }

  void _onTabTapCancel(int index) {
    setState(() {
      _pressedTabs[index] = false;
    });
    _glowControllers[index]!.reverse();
  }

  Widget _buildGlowingIcon({
    required IconData icon,
    required bool isSelected,
    required int index,
  }) {
    return GestureDetector(
      onTap: () => _onTabTap(index),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.20), // Only faint glow
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 0.5),
                  ),
                ]
              : [],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isSelected)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
              ),
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
              size: 24,
            ),
            // REMOVED INDICATOR DOT
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xFF282C34),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -5),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: widget.currentIndex,
          onTap: (i) {
            // Handled by gesture detectors in _buildGlowingIcon
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.transparent,
          unselectedItemColor: Colors.transparent,
          selectedLabelStyle: const TextStyle(fontSize: 0),
          unselectedLabelStyle: const TextStyle(fontSize: 0),
          items: [
            BottomNavigationBarItem(
              icon: _buildGlowingIcon(
                icon: Icons.home_outlined,
                isSelected: widget.currentIndex == 0,
                index: 0,
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: _buildGlowingIcon(
                icon: Icons.emoji_events_outlined,
                isSelected: widget.currentIndex == 1,
                index: 1,
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: _buildGlowingIcon(
                icon: Icons.shopping_cart_outlined,
                isSelected: widget.currentIndex == 2,
                index: 2,
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: _buildGlowingIcon(
                icon: Icons.dashboard_outlined,
                isSelected: widget.currentIndex == 3,
                index: 3,
              ),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}
