enum InquiryStatus {
  newInquiry('new'),
  read('read'),
  closed('closed');

  const InquiryStatus(this.value);
  final String value;

  static InquiryStatus parse(Object? v) =>
      InquiryStatus.values.firstWhere((s) => s.value == v, orElse: () => InquiryStatus.newInquiry);
}

/// inquiries/{id}: one message from a buyer about a listing (no chat thread).
class Inquiry {
  const Inquiry({
    required this.id,
    required this.listingId,
    required this.farmerId,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhone,
    required this.commodityId,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String listingId;
  final String farmerId;
  final String buyerId;
  final String buyerName;
  final String buyerPhone;
  final String commodityId;
  final String message;
  final InquiryStatus status;
  final DateTime createdAt;
}
