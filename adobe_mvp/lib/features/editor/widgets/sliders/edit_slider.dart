// features/editor/widgets/sliders/edit_slider.dart
import 'package:adobe_mvp/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// EditSlider: replicates the provided Figma UI as a bottom sheet slider panel.
///
/// Usage:
///   EditSlider(sx: sx, sy: sy, enabled: true, onSelect: (label) { ... });
class EditSlider extends StatefulWidget {
  final double sx;
  final double sy;
  final bool enabled;
    final VoidCallback? onClose;

  final ValueChanged<String>? onSelect;

  const EditSlider({
    Key? key,
    this.sx = 1.0,
    this.sy = 1.0,
    this.enabled = true,
    this.onSelect,
    this.onClose
  }) : super(key: key);

  @override
  State<EditSlider> createState() => _EditSliderState();
}

class _EditSliderState extends State<EditSlider> {
  // list mirrors Figma labels — using custom PNG icons where available, Material icons otherwise.
  final List<_ToolItem> _tools = const [
    _ToolItem(label: 'Crop', iconAsset: 'assets/icons/Crop.png'),
    _ToolItem(label: 'Hue', iconData: Icons.palette),
    _ToolItem(label: 'Saturation', iconData: Icons.opacity),
    _ToolItem(label: 'Temperature', iconData: Icons.thermostat),
    _ToolItem(label: 'Exposure', iconData: Icons.wb_sunny),
    _ToolItem(label: 'Contrast', iconData: Icons.tonality),
    _ToolItem(label: 'Vibrance', iconData: Icons.auto_fix_high),
    _ToolItem(label: 'Clarity', iconData: Icons.filter_hdr),
    _ToolItem(label: 'Sharpen', iconData: Icons.shutter_speed),
  ];

  int? _selectedIndex;

  void _selectIndex(int i) {
    if (!widget.enabled) return;
    setState(() => _selectedIndex = i);
    widget.onSelect?.call(_tools[i].label);
  }

  @override
  Widget build(BuildContext context) {
    // Panel colors & typography match your Figma snippet.
    final panelColor = AppTheme.darkTheme.cardColor;
    final chipBg = AppTheme.darkTheme.cardColor;
    final labelStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontFamily: 'Adobe Clean',
      fontWeight: FontWeight.w500,
      height: 1.83,
    );

    final controlLabelStyle = TextStyle(
      color: AppTheme.darkTheme.colorScheme.onSecondary,
      fontSize: 14,
      fontFamily: 'Adobe Clean',
      fontWeight: FontWeight.w600,
      height: 1.71,
    );

    final panel = Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 32),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: panelColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // handle / spacer
                    GestureDetector(
            onTap: widget.onClose,
            onVerticalDragEnd: (details) {
              // Swipe down to close
              if (details.primaryVelocity != null && details.primaryVelocity! > 100) {
                widget.onClose?.call();
              }
            },
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: 30,
              child: Center(
                child:Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppTheme.darkTheme.colorScheme.primary, borderRadius: BorderRadius.circular(4)),
            // child: Icon(Icons.remove, size: , color: AppTheme.darkTheme.colorScheme.onPrimary),
          )))),
          SizedBox(height: 12 * widget.sy),

          // Tools row container (mirrors the Figma 393 width row)
          SizedBox(
            height: 84 * widget.sy, // gives room for icon + label (approx from figma)
            child: SingleChildScrollView(
              padding: EdgeInsets.only(left: 0),
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(_tools.length, (i) {
                  final tool = _tools[i];
                  final selected = _selectedIndex == i;

                  // Each tool is a ConstrainedBox to match minWidth behaviour in figma
                  return GestureDetector(
                    onTap: () => _selectIndex(i),
                    child: Padding(
                      padding: EdgeInsets.only(right: 16 * widget.sx),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // circular icon / placeholder
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: selected ? 40 : 36,
                              height: selected ? 40 : 36,
                              decoration: BoxDecoration(
                                // color: selected ? const Color(0xFF3B62FB) : Colors.white12,
                                shape: BoxShape.circle,
                                boxShadow: selected ? [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))] : null,
                              ),
                              child: tool.iconAsset != null
                                  ? Image.asset(
                                      tool.iconAsset!,
                                      width: selected ? 24 : 20,
                                      height: selected ? 24 : 20,
                                      color: selected ? AppTheme.darkTheme.colorScheme.onSecondary : Colors.white70,
                                    )
                                  : Icon(tool.iconData, size: selected ? 24 : 20, color: selected ? AppTheme.darkTheme.colorScheme.onSecondary : Colors.white70),
                            ),
                            SizedBox(height: 8),
                            // label
                            SizedBox(
                              width: 86 * widget.sx, // keep labels tidy and wrapped if needed
                              child: Text(
                                tool.label,
                                textAlign: TextAlign.center,
                                style: (selected) ? controlLabelStyle : labelStyle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // SizedBox(height: 20),

          // Below the tools you might show an active control slider for the selected tool.
          // For now, show a subtle placeholder that you can replace with actual control widgets.
          // if (_selectedIndex != null)
          //   Column(
          //     mainAxisSize: MainAxisSize.min,
          //     children: [
          //       // control label
          //       Text(
          //         _tools[_selectedIndex!].label,
          //         style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          //       ),
          //       SizedBox(height: 8 * widget.sy),
          //       // example slider control
          //       SizedBox(
          //         width: MediaQuery.of(context).size.width * 0.86,
          //         child: SliderTheme(
          //           data: SliderAppTheme.darkTheme.copyWith(
          //             trackHeight: 4,
          //             thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          //             overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          //           ),
          //           child: Slider(
          //             value: 0.5,
          //             onChanged: widget.enabled ? (v) {} : null,
          //             activeColor: const Color(0xFF3B62FB),
          //             inactiveColor: Colors.white10,
          //           ),
          //         ),
          //       ),
          //     ],
          //   ),

          // small spacer to respect bottom padding
        ],
      ),
    );

    // Disabled visual + pointer capture handled by AbsorbPointer + AnimatedOpacity
    return AbsorbPointer(
      absorbing: !widget.enabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: widget.enabled ? 1.0 : 0.55,
        child: panel,
      ),
    );
  }
}

/// simple internal structure for each tool item
class _ToolItem {
  final String label;
  final IconData? iconData;
  final String? iconAsset;
  const _ToolItem({required this.label, this.iconData, this.iconAsset})
      : assert(iconData != null || iconAsset != null, 'Either iconData or iconAsset must be provided');
}
