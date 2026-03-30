import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

void showLanguagePickerSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              S.tr('language'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 16),
            ...S.supportedLocales.map((loc) {
              final code = loc.languageCode;
              final selected = S.locale.value.languageCode == code;
              return ListTile(
                leading: Text(
                  S.localeFlags[code] ?? '',
                  style: const TextStyle(fontSize: 28),
                ),
                title: Text(
                  S.localeLabels[code] ?? code,
                  style: TextStyle(
                    color: selected ? AppColors.red : AppColors.white,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: AppColors.red)
                    : null,
                onTap: () {
                  S.locale.value = loc;
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    ),
  );
}
