import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import 'cart_models.dart';

class CartRepository {
  const CartRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ShoppingCart> getCart() async {
    final response = await _apiClient.get<ShoppingCart>(
      ApiPaths.cart,
      parser: ShoppingCart.fromJson,
    );
    return response.data;
  }

  Future<CartItem> addItem({required int bookId, int quantity = 1}) async {
    final response = await _apiClient.post<CartItem>(
      ApiPaths.cartItems,
      data: {'bookId': bookId, 'quantity': quantity},
      parser: CartItem.fromJson,
    );
    return response.data;
  }

  Future<CartItem> updateItem(
    int bookId, {
    int? quantity,
    bool? selected,
  }) async {
    final response = await _apiClient.put<CartItem>(
      ApiPaths.cartItem(bookId),
      data: {
        if (quantity != null) 'quantity': quantity,
        if (selected != null) 'selected': selected,
      },
      parser: CartItem.fromJson,
    );
    return response.data;
  }

  Future<ShoppingCart> updateSelection(bool selected) async {
    final response = await _apiClient.put<ShoppingCart>(
      ApiPaths.cartSelection,
      data: {'selected': selected},
      parser: ShoppingCart.fromJson,
    );
    return response.data;
  }

  Future<void> removeItem(int bookId) async {
    await _apiClient.delete<Object?>(ApiPaths.cartItem(bookId));
  }

  Future<int> removeSelected() async {
    final response = await _apiClient.delete<int>(
      ApiPaths.cartSelected,
      parser: (value) => (value as num?)?.toInt() ?? 0,
    );
    return response.data;
  }
}
