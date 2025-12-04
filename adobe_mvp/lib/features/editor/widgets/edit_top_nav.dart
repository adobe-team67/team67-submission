// features/editor/widgets/top_nav.dart
import 'package:adobe_mvp/core/global.dart';
import 'package:flutter/material.dart';
import 'package:adobe_mvp/ui/theme/app_theme.dart';
import 'model_selection_popup.dart';

class TopNav extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onShare;

  const TopNav({
    super.key,
    required this.onBack,
    required this.onUndo,
    required this.onRedo,
    required this.onShare,
  });

  @override
  State<TopNav> createState() => _TopNavState();
}

class _TopNavState extends State<TopNav> {
  Future<void> _openModelPopup() async {
    final result = await showModelSelectionPopup(context);
    if (result == true && mounted) {
      setState(() {}); // refresh to show newly selected model
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = AppTheme.darkTheme.iconTheme.color ?? Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back
          Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 36, height: 36),
                  icon: Image.asset('assets/icons/Chevron left.png', width: 18, height: 18, color: iconColor),
                  onPressed: widget.onBack,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openModelPopup,
                child: Row(
                  spacing: 10,
                  children: [
                    Text(GlobalConfig.selectedModelName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontFamily: 'Adobe Clean',
                          fontWeight: FontWeight.w500,
                          height: 1.57,
                        )),
                    // const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: ShapeDecoration(
                        color: (GlobalConfig.selectedModelType == 'PRO') ? const Color(0xFF937204) : const Color(0xFF3B62FB),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      child: Text(
                        GlobalConfig.selectedModelType,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontFamily: 'Adobe Clean',
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(),
                      child: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),

          // // Center placeholder (title / steps if needed)
          // Expanded(
          //   child: Center(
          //     child: Text(
          //       'Editor',
          //       style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(color: Colors.black87),
          //     ),
          //   ),
          // ),

          // Right actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                  icon: Image.asset('assets/icons/undo.png', width: 20, height: 20, color: iconColor),
                  onPressed: widget.onUndo,
                ),
              ),
              // const SizedBox(width: 8),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                  icon: Image.asset('assets/icons/redo.png', width: 20, height: 20, color: iconColor),
                  onPressed: widget.onRedo,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                  icon: Image.asset('assets/icons/Share.png', width: 20, height: 20, color: iconColor),
                  onPressed: widget.onShare,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
