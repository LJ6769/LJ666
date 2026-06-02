/// 礼物商城发送成功后的回传数据。
class LiveGiftSendResult {
  const LiveGiftSendResult({
    required this.giftId,
    required this.giftIconAsset,
    required this.price,
  });

  final String giftId;
  final String giftIconAsset;
  final int price;
}
