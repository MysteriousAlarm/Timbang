import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/generated/app_localizations.dart';

class MunicipalityField extends StatelessWidget {
  const MunicipalityField({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      key: const Key('municipalityField'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.municipalityLabel,
        prefixIcon: const Icon(Icons.location_on_outlined),
      ),
      items: [
        for (final m in AppConfig.municipalities)
          DropdownMenuItem(
            value: m,
            child: Text(m, style: const TextStyle(fontSize: 18)),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
