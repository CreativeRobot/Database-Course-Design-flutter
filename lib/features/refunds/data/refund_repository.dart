import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/common/page_response.dart';
import 'refund_models.dart';

class RefundRepository {
  const RefundRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CustomerRefundRequest> createRefund(
    int orderId,
    RefundApplication application,
  ) async {
    final response = await _apiClient.post<CustomerRefundRequest>(
      ApiPaths.orderRefunds(orderId),
      data: application.toJson(),
      parser: CustomerRefundRequest.fromJson,
    );
    return response.data;
  }

  Future<PageResponse<CustomerRefundRequest>> listRefunds({
    int page = 1,
    int size = 100,
  }) async {
    final response = await _apiClient.get<PageResponse<CustomerRefundRequest>>(
      ApiPaths.refunds,
      queryParameters: {'page': page, 'size': size},
      parser: (value) => PageResponse.fromJson(
        value,
        itemParser: CustomerRefundRequest.fromJson,
      ),
    );
    return response.data;
  }

  Future<CustomerRefundRequest> getRefund(int refundId) async {
    final response = await _apiClient.get<CustomerRefundRequest>(
      ApiPaths.refund(refundId),
      parser: CustomerRefundRequest.fromJson,
    );
    return response.data;
  }
}
