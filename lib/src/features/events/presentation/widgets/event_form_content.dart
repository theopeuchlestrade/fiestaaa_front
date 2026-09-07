import 'package:flutter/material.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';

String? requiredEventText(String? value, S l) =>
    value == null || value.trim().isEmpty ? l.fieldRequired : null;

Future<bool> confirmLeaveEventForm(BuildContext context) async {
  final l = S.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.formLeaveTitle),
          content: Text(l.formLeaveBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.formStay),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.formLeave),
            ),
          ],
        ),
      ) ??
      false;
}

/// Same fields, section order and action placement in creation and editing.
class EventFormContent extends StatelessWidget {
  const EventFormContent({
    super.key,
    required this.formKey,
    required this.title,
    required this.name,
    required this.description,
    required this.address,
    required this.schedule,
    required this.advanced,
    required this.modules,
    required this.advancedController,
    required this.modulesController,
    required this.advancedSummary,
    required this.modulesSummary,
    required this.onSubmit,
    required this.submitting,
    required this.submitLabel,
    this.back = false,
    this.onBack,
    this.footer,
    this.notice,
    this.advancedOpen = false,
    this.modulesOpen = false,
  });
  final GlobalKey<FormState> formKey;
  final String title, submitLabel, advancedSummary, modulesSummary;
  final TextEditingController name, description;
  final Widget address, schedule, advanced, modules;
  final ExpansibleController advancedController, modulesController;
  final VoidCallback onSubmit;
  final VoidCallback? onBack;
  final bool submitting, back, advancedOpen, modulesOpen;
  final Widget? footer, notice;
  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    return FiestaaaPageLayout(
      maxWidth: 760,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (back) BackButton(onPressed: onBack),
                    FiestaaaPageHeader(title: title),
                    ?notice,
                    TextFormField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: l.fiestaaaName,
                        prefixIcon: const Icon(Icons.celebration),
                      ),
                      validator: (value) => requiredEventText(value, l),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: description,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: l.description,
                        alignLabelWithHint: true,
                      ),
                      validator: (value) => requiredEventText(value, l),
                    ),
                    const SizedBox(height: 16),
                    address,
                    const SizedBox(height: 16),
                    schedule,
                    const SizedBox(height: 16),
                    ExpansionTile(
                      controller: advancedController,
                      initiallyExpanded: advancedOpen,
                      maintainState: true,
                      title: Text(l.formAdvanced),
                      subtitle: Text(advancedSummary),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: advanced,
                        ),
                      ],
                    ),
                    ExpansionTile(
                      controller: modulesController,
                      initiallyExpanded: modulesOpen,
                      maintainState: true,
                      title: Text(l.formModules),
                      subtitle: Text(modulesSummary),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: modules,
                        ),
                      ],
                    ),
                    ?footer,
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: submitting ? null : onSubmit,
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(submitLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> validateExpandedEventForm(
  GlobalKey<FormState> key,
  ExpansibleController advanced,
  ExpansibleController modules,
) async {
  advanced.expand();
  modules.expand();
  await WidgetsBinding.instance.endOfFrame;
  final invalid = key.currentState?.validateGranularly() ?? {};
  if (invalid.isEmpty) return true;
  final field = invalid.first;
  if (!field.mounted) return false;
  await Scrollable.ensureVisible(
    field.context,
    duration: const Duration(milliseconds: 200),
    alignment: .2,
  );
  if (!field.mounted) return false;
  void focusEditable(Element element) {
    if (element.widget is EditableText) {
      (element.widget as EditableText).focusNode.requestFocus();
      return;
    }
    element.visitChildren(focusEditable);
  }

  (field.context as Element).visitChildren(focusEditable);
  return false;
}
