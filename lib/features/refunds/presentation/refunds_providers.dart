import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/models/common/page_response.dart';
import '../data/refund_models.dart';
import '../data/refund_repository.dart';

final refundRepositoryProvider = Provider<RefundRepository>((ref) {
  return RefundRepository(ref.watch(apiClientProvider));
});

final customerRefundsProvider =
    FutureProvider.autoDispose<PageResponse<CustomerRefundRequest>>((ref) {
      return ref.watch(refundRepositoryProvider).listRefunds();
    });

final customerRefundDetailProvider = FutureProvider.autoDispose
    .family<CustomerRefundRequest, int>((ref, id) {
      return ref.watch(refundRepositoryProvider).getRefund(id);
    });
