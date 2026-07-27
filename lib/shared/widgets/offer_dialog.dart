import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/offer.dart';
import '../../core/repositories/ride_repository.dart';

class OfferDialog extends StatelessWidget {
  final RideOffer offer;
  final VoidCallback onClose;

  const OfferDialog({required this.offer, required this.onClose, super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController counterController = TextEditingController();
    return AlertDialog(
      title: Text('عرض رحلة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('السعر: ${offer.price.round()} ج.م', style: GoogleFonts.cairo()),
          const SizedBox(height: 8),
          Text('المقدر للوصول: ${offer.eta.inMinutes} دقيقة', style: GoogleFonts.cairo()),
          const SizedBox(height: 12),
          TextField(
            controller: counterController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'سعر مقترح (اختياري)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await RideRepository.instance.respondToOffer(
              offerId: offer.id,
              response: 'rejected',
            );
            onClose();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('رفض'),
        ),
        TextButton(
          onPressed: () async {
            final counter = double.tryParse(counterController.text);
            if (counter != null) {
              await RideRepository.instance.respondToOffer(
                offerId: offer.id,
                response: 'countered',
                counterPrice: counter,
              );
            }
            onClose();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('مقابل'),
        ),
        ElevatedButton(
          onPressed: () async {
            await RideRepository.instance.respondToOffer(
              offerId: offer.id,
              response: 'accepted',
            );
            onClose();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('قبول'),
        ),
      ],
    );
  }
}
