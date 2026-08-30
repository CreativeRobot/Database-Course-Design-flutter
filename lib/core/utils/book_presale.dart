bool isActivePreSale(bool preSale, DateTime? releaseTime, {DateTime? now}) {
  if (!preSale || releaseTime == null) return false;
  return releaseTime.isAfter(now ?? DateTime.now());
}

String formatPreSaleReleaseTime(DateTime releaseTime) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${releaseTime.year}-${two(releaseTime.month)}-${two(releaseTime.day)} '
      '${two(releaseTime.hour)}:${two(releaseTime.minute)}';
}

String preSaleNotice(DateTime releaseTime) =>
    '预售 · 预计 ${formatPreSaleReleaseTime(releaseTime)} 发售';
