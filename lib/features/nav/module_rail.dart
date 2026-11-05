import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/vision/vision_kit.dart';
import 'side_nav_rail.dart' show SideRailEntry;

/// The module side nav: one real-pixel glass rail per browsing surface.
///
/// Layout contract (v8.5, map W6):
///   [ search actuator ]   ← top, always first where a search exists
///   [ module entries   ]  ← every necessary control/navigation for the module
///   [ settings         ]  ← bottom, where the module has settings
///
/// Every hit target is 44 px with a 20 px glyph — the same sizing the home
/// dock uses (they are the same UI element, different instance). Search opens
/// an inline field in the rail; submitting reports [onSearch].
class ModuleRail extends StatefulWidget {
  final List<SideRailEntry> entries;
  final String? activeKey;
  final ValueChanged<String> onSelect;

  /// Non-null enables the search actuator at the top of the rail.
  final ValueChanged<String>? onSearch;

  /// Non-null adds the settings entry at the bottom of the rail.
  final VoidCallback? onSettings;

  const ModuleRail({
    super.key,
    required this.entries,
    required this.activeKey,
    required this.onSelect,
    this.onSearch,
    this.onSettings,
  });

  @override
  State<ModuleRail> createState() => _ModuleRailState();
}

class _ModuleRailState extends State<ModuleRail> {
  bool _searchOpen = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  static const _target = 44.0; // minimum hit target (dock parity)
  static const _gap = 10.0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (_searchOpen) {
        _searchCtrl.clear();
      } else {
        _searchCtrl.clear();
      }
    });
    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocus.requestFocus();
      });
    }
  }

  void _submit() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    widget.onSearch?.call(q);
  }

  @override
  Widget build(BuildContext context) {
    final search = widget.onSearch != null;
    return VOrnament(
      axis: Axis.vertical,
      padding: const EdgeInsets.all(8),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (search) ...[
              _searchOpen
                  ? SizedBox(
                      width: 208,
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search',
                          hintStyle: const TextStyle(
                              fontSize: 13, color: Colors.white38),
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 18, color: Colors.white60),
                          suffixIcon: GestureDetector(
                            onTap: _toggleSearch,
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: Colors.white54),
                          ),
                          suffixIconConstraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          filled: true,
                          fillColor: const Color(0x1EFFFFFF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    )
                  : VCircleButton(
                      icon: Icons.search_rounded,
                      tooltip: 'Search',
                      size: _target,
                      onTap: _toggleSearch,
                    ),
              const SizedBox(height: _gap),
            ],
            for (final e in widget.entries) ...[
              VCircleButton(
                icon: e.icon,
                tooltip: e.label,
                size: _target,
                selected: widget.activeKey == e.key,
                onTap: () => widget.onSelect(e.key),
              ),
              const SizedBox(height: _gap),
            ],
            if (widget.onSettings != null)
              VCircleButton(
                icon: Icons.tune_rounded,
                tooltip: 'Settings',
                size: _target,
                onTap: widget.onSettings,
              ),
          ],
        ),
      ),
    );
  }
}

/// Keyboard escape hatch for the expanded rail search (Escape collapses it).
class ModuleRailEscape extends StatelessWidget {
  final Widget child;
  final VoidCallback onEscape;
  const ModuleRailEscape(
      {super.key, required this.child, required this.onEscape});

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onEscape,
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
