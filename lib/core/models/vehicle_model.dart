class VehicleModel {
  final String id;
  final String driverId;
  final String model;
  final String numberPlate;
  final String color;
  final String type; // 'car' | 'scooter' | 'motorcycle'

  VehicleModel({
    required this.id,
    required this.driverId,
    required this.model,
    required this.numberPlate,
    required this.color,
    required this.type,
  });

  factory VehicleModel.fromMap(Map<String, dynamic> data, String id) {
    return VehicleModel(
      id: id,
      driverId: data['driver_id'] ?? data['driverId'] ?? '',
      model: data['model'] ?? '',
      numberPlate: data['number_plate'] ?? data['numberPlate'] ?? '',
      color: data['color'] ?? '',
      type: data['vehicle_category'] ?? data['type'] ?? data['vehicleType'] ?? 'car',
    );
  }

  Map<String, dynamic> toMap() {
    return toDatabaseMap();
  }

  /// Returns ONLY valid PostgreSQL column names for Supabase `vehicles` table
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'driver_id': driverId,
      'model': model,
      'number_plate': numberPlate,
      'color': color,
      'type': type,
    };
  }
}
