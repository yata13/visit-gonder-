class BookingModel {
  final String id;
  final String userId;
  final String type;           // 'hotel' | 'guide'
  final String referenceId;    // hotel id or guide id
  final String referenceName;  // hotel name or guide name
  final String referenceImage;
  final DateTime checkIn;
  final DateTime checkOut;
  final double totalPrice;
  final String status;         // 'upcoming' | 'completed' | 'cancelled'
  final String? notes;
  final DateTime createdAt;

  const BookingModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.referenceId,
    required this.referenceName,
    required this.referenceImage,
    required this.checkIn,
    required this.checkOut,
    required this.totalPrice,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
    id:             json['id'] as String,
    userId:         json['user_id'] as String,
    type:           json['type'] as String,
    referenceId:    json['reference_id'] as String,
    referenceName:  json['reference_name'] as String,
    referenceImage: json['reference_image'] as String,
    checkIn:        DateTime.parse(json['check_in'] as String),
    checkOut:       DateTime.parse(json['check_out'] as String),
    totalPrice:     (json['total_price'] as num).toDouble(),
    status:         json['status'] as String,
    notes:          json['notes'] as String?,
    createdAt:      DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'user_id':         userId,
    'type':            type,
    'reference_id':    referenceId,
    'reference_name':  referenceName,
    'reference_image': referenceImage,
    'check_in':        checkIn.toIso8601String(),
    'check_out':       checkOut.toIso8601String(),
    'total_price':     totalPrice,
    'status':          status,
    'notes':           notes,
  };
}
