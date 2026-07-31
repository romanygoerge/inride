import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class VehicleCategoryOption {
  final String id;
  final String title;
  final String iconPath;
  final double defaultPrice;

  const VehicleCategoryOption({
    required this.id,
    required this.title,
    required this.iconPath,
    required this.defaultPrice,
  });
}

class VehicleCategorySelector extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const VehicleCategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  static const List<VehicleCategoryOption> categories = [
    VehicleCategoryOption(
      id: 'motorcycle',
      title: 'موتوسيكل',
      iconPath: 'assets/icons/motorcycle.png',
      defaultPrice: 15.0,
    ),
    VehicleCategoryOption(
      id: 'car',
      title: 'سيارة ملاكي',
      iconPath: 'assets/icons/car.png',
      defaultPrice: 45.0,
    ),
    VehicleCategoryOption(
      id: 'scooter',
      title: 'اسكوتر (قريباً)',
      iconPath: 'assets/icons/scooter.png',
      defaultPrice: 20.0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: categories.map((cat) {
        final isSelected = selectedCategory == cat.id;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(cat.id),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withAlpha(30)
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat.id == 'motorcycle'
                        ? Icons.two_wheeler
                        : cat.id == 'car'
                            ? Icons.directions_car
                            : Icons.electric_scooter,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    size: 26,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
