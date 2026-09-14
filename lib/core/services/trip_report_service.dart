import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_report_model.dart';

class TripReportService {
  TripReportService._();
  static final TripReportService instance = TripReportService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<bool> submitReport(TripReportModel report) async {
    try {
      String? pName = report.passengerName;
      String? pPhone = report.passengerPhone;
      String? dName = report.driverName;
      String? dPhone = report.driverPhone;

      // Enrich passenger details if missing
      if ((pName == null || pName.isEmpty || pPhone == null || pPhone.isEmpty) &&
          report.passengerId != null &&
          report.passengerId!.isNotEmpty) {
        try {
          final uRes = await _client
              .from('users')
              .select('name, phone_number, phone')
              .eq('id', report.passengerId!)
              .maybeSingle();
          if (uRes != null) {
            pName ??= uRes['name']?.toString();
            pPhone ??= (uRes['phone_number'] ?? uRes['phone'])?.toString();
          }
        } catch (_) {}
      }

      // Enrich driver details if missing
      if ((dName == null || dName.isEmpty || dPhone == null || dPhone.isEmpty) &&
          report.driverId != null &&
          report.driverId!.isNotEmpty) {
        try {
          final dRes = await _client
              .from('users')
              .select('name, phone_number, phone')
              .eq('id', report.driverId!)
              .maybeSingle();
          if (dRes != null) {
            dName ??= dRes['name']?.toString();
            dPhone ??= (dRes['phone_number'] ?? dRes['phone'])?.toString();
          }
        } catch (_) {}
      }

      final enrichedReport = TripReportModel(
        id: report.id,
        tripId: report.tripId,
        reporterId: report.reporterId,
        reporterRole: report.reporterRole,
        reportedId: report.reportedId,
        reportedRole: report.reportedRole,
        passengerId: report.passengerId,
        passengerName: pName,
        passengerPhone: pPhone,
        driverId: report.driverId,
        driverName: dName,
        driverPhone: dPhone,
        tripStatus: report.tripStatus,
        pickupAddress: report.pickupAddress,
        destinationAddress: report.destinationAddress,
        fare: report.fare,
        reason: report.reason,
        description: report.description,
        status: report.status,
      );

      final insertData = enrichedReport.toJson();
      await _client.from('trip_reports').insert(insertData);
      debugPrint('[TripReportService] Report submitted successfully for trip: ${report.tripId}');
      return true;
    } catch (e, stack) {
      debugPrint('[TripReportService] Error submitting report: $e\n$stack');
      return false;
    }
  }

  Future<List<TripReportModel>> getReportsForTrip(String tripId) async {
    try {
      final res = await _client
          .from('trip_reports')
          .select()
          .eq('trip_id', tripId)
          .order('created_at', ascending: false);
      final list = (res as List).cast<Map<String, dynamic>>();
      return list.map((e) => TripReportModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[TripReportService] Error fetching trip reports: $e');
      return [];
    }
  }
}
