import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/offer.dart';
import '../../core/repositories/ride_repository.dart';
import '../../generated/app_localizations.dart';

class OfferDialog extends StatelessWidget {
  final RideOffer offer;
  final VoidCallback onClose;

  const OfferDialog({required this.offer, required this.onClose, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController counterController = TextEditingController();
    return AlertDialog(
      title: Text(l10n.offerDetails, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${l10n.offeredFare}: ${offer.price.round()} ${l10n.egp}', style: GoogleFonts.cairo()),
          const SizedBox(height: 8),
          Text('${l10n.estimatedTime}: ${l10n.durationMinutes(offer.eta.inMinutes)}', style: GoogleFonts.cairo()),
          const SizedBox(height: 12),
          TextField(
            controller: counterController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.enterCounterOffer,
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
          child: Text(l10n.declineOffer),
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
          child: Text(l10n.counterOffer),
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
          child: Text(l10n.acceptOffer),
        ),
      ],
    );
  }
}

