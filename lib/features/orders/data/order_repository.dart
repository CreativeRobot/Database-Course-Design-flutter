import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/common/page_response.dart';
import 'order_models.dart';

class OrderRepository {
  const OrderRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PageResponse<BookOrder>> listOrders({
    String? status,
    int page = 1,
    int size = 10,
  }) async {
    final response = await _apiClient.get<PageResponse<BookOrder>>(
      ApiPaths.orders,
      queryParameters: {
        if (status != null) 'status': status,
        'page': page,
        'size': size,
      },
      parser: (value) =>
          PageResponse.fromJson(value, itemParser: BookOrder.fromJson),
    );
    return response.data;
  }

  Future<BookOrder> createOrder({
    required int addressId,
    String? remark,
  }) async {
    final response = await _apiClient.post<BookOrder>(
      ApiPaths.orders,
      data: {
        'addressId': addressId,
        if (remark != null && remark.trim().isNotEmpty) 'remark': remark.trim(),
      },
      parser: BookOrder.fromJson,
    );
    return response.data;
  }

  Future<BookOrder> getOrder(int orderId) async {
    final response = await _apiClient.get<BookOrder>(
      ApiPaths.order(orderId),
      parser: BookOrder.fromJson,
    );
    return response.data;
  }

  Future<BookOrder> cancelOrder(int orderId) async {
    final response = await _apiClient.put<BookOrder>(
      ApiPaths.cancelOrder(orderId),
      parser: BookOrder.fromJson,
    );
    return response.data;
  }

  Future<PaymentResult> payOrder(int orderId) async {
    final response = await _apiClient.post<PaymentResult>(
      ApiPaths.orderPayment(orderId),
      data: const {'paymentMethod': 'MOCK'},
      parser: PaymentResult.fromJson,
    );
    return response.data;
  }

  Future<BookOrder> confirmReceipt(int orderId) async {
    final response = await _apiClient.put<BookOrder>(
      ApiPaths.confirmOrderReceipt(orderId),
      parser: BookOrder.fromJson,
    );
    return response.data;
  }
}
