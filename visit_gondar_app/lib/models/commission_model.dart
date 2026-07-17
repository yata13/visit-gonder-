// Tracks platform commission on every booking

class CommissionModel {
  final String id;
  final String bookingId;
  final String referenceId;
  final String referenceType;   // 'hotel' | 'guide'
  final double totalAmount;     // full booking price
  final double commissionRate;  // e.g. 0.10 = 10%
  final double commissionAmount;// totalAmount * commissionRate
  final double ownerAmount;     // totalAmount - commissionAmount
  final String status;          // 'pending' | 'paid' | 'refunded'
  final DateTime createdAt;

  const CommissionModel({
    required this.id,
    required this.bookingId,
    required this.referenceId,
    required this.referenceType,
    required this.totalAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.ownerAmount,
    required this.status,
    required this.createdAt,
  });

  factory CommissionModel.fromJson(Map<String, dynamic> json) => CommissionModel(
    id:               json['id'] as String,
    bookingId:        json['booking_id'] as String,
    referenceId:      json['reference_id'] as String,
    referenceType:    json['reference_type'] as String,
    totalAmount:      (json['total_amount'] as num).toDouble(),
    commissionRate:   (json['commission_rate'] as num).toDouble(),
    commissionAmount: (json['commission_amount'] as num).toDouble(),
    ownerAmount:      (json['owner_amount'] as num).toDouble(),
    status:           json['status'] as String,
    createdAt:        DateTime.parse(json['created_at'] as String),
  );

  // Calculate commission breakdown
  static Map<String, double> calculate({
    required double totalAmount,
    required double commissionRate,
  }) {
    final commission = totalAmount * commissionRate;
    return {
      'commission': commission,
      'owner':      totalAmount - commission,
      'total':      totalAmount,
    };
  }
}
