class TripReportModel {
  final String? id;
  final String? tripId;
  final String reporterId;
  final String reporterRole; // 'passenger' | 'driver'
  final String? reportedId;
  final String reportedRole; // 'passenger' | 'driver'
  final String? passengerId;
  final String? passengerName;
  final String? passengerPhone;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String tripStatus; // 'in_progress' | 'completed' | 'cancelled'
  final String? pickupAddress;
  final String? destinationAddress;
  final double? fare;
  final String reason;
  final String description;
  final String status; // 'pending' | 'investigating' | 'resolved' | 'dismissed'
  final String? adminNotes;
  final DateTime? resolvedAt;
  final DateTime? createdAt;

  const TripReportModel({
    this.id,
    this.tripId,
    required this.reporterId,
    required this.reporterRole,
    this.reportedId,
    required this.reportedRole,
    this.passengerId,
    this.passengerName,
    this.passengerPhone,
    this.driverId,
    this.driverName,
    this.driverPhone,
    required this.tripStatus,
    this.pickupAddress,
    this.destinationAddress,
    this.fare,
    required this.reason,
    required this.description,
    this.status = 'pending',
    this.adminNotes,
    this.resolvedAt,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      'reporter_id': reporterId,
      'reporter_role': reporterRole,
      if (reportedId != null) 'reported_id': reportedId,
      'reported_role': reportedRole,
      if (passengerId != null) 'passenger_id': passengerId,
      if (passengerName != null) 'passenger_name': passengerName,
      if (passengerPhone != null) 'passenger_phone': passengerPhone,
      if (driverId != null) 'driver_id': driverId,
      if (driverName != null) 'driver_name': driverName,
      if (driverPhone != null) 'driver_phone': driverPhone,
      'trip_status': tripStatus,
      if (pickupAddress != null) 'pickup_address': pickupAddress,
      if (destinationAddress != null) 'destination_address': destinationAddress,
      if (fare != null) 'fare': fare,
      'reason': reason,
      'description': description,
      'status': status,
      if (adminNotes != null) 'admin_notes': adminNotes,
      if (resolvedAt != null) 'resolved_at': resolvedAt!.toIso8601String(),
    };
  }

  factory TripReportModel.fromJson(Map<String, dynamic> json) {
    return TripReportModel(
      id: json['id']?.toString(),
      tripId: json['trip_id']?.toString(),
      reporterId: json['reporter_id']?.toString() ?? '',
      reporterRole: json['reporter_role']?.toString() ?? 'passenger',
      reportedId: json['reported_id']?.toString(),
      reportedRole: json['reported_role']?.toString() ?? 'driver',
      passengerId: json['passenger_id']?.toString(),
      passengerName: json['passenger_name']?.toString(),
      passengerPhone: json['passenger_phone']?.toString(),
      driverId: json['driver_id']?.toString(),
      driverName: json['driver_name']?.toString(),
      driverPhone: json['driver_phone']?.toString(),
      tripStatus: json['trip_status']?.toString() ?? 'in_progress',
      pickupAddress: json['pickup_address']?.toString(),
      destinationAddress: json['destination_address']?.toString(),
      fare: (json['fare'] as num?)?.toDouble(),
      reason: json['reason']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      adminNotes: json['admin_notes']?.toString(),
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}
