import 'package:material_ui/material_ui.dart';
import '../../../core/vision/vision_kit.dart';

/// Agent Capabilities & Skills — grouped toggle rows in an account-sized window.
class SkillsScreen extends StatefulWidget {
  final VoidCallback onClose;

  const SkillsScreen({super.key, required this.onClose});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  final Map<String, bool> _skills = {
    'Real-Time Web Search & Unbiased Fact Verification': true,
    'Personal Finance, Mortgage & Insurance Calculators': true,
    'Contract & Legal Document Plain-Language Summaries': true,
    'Home Improvement, Energy & Cost Efficiency Modeling': true,
    'High-Fidelity Photo & Visual Understanding': true,
    'Multi-Language Translation & Travel Planning': false,
  };

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        VScrim(onTap: widget.onClose),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.md, VSpace.md, 76),
              child: VWindow(
                title: 'Agent Capabilities & Skills',
                centerTitle: true,
                maxWidth: VOverlay.menuWidth(context) + 36,
                leading: VCircleButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: widget.onClose),
                child: VListGroup(children: [
                  for (final k in _skills.keys)
                    VListRow(
                      title: k,
                      titleLines: 2,
                      trailing: VToggle(value: _skills[k]!, onChanged: (v) => setState(() => _skills[k] = v)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
