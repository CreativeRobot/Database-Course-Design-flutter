import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/book/book.dart';
import '../../../data/models/book/book_detail.dart';
import '../../../data/models/common/page_response.dart';
import '../../orders/data/order_models.dart';
import '../../reviews/data/review_models.dart';
import 'admin_models.dart';

class AdminRepository {
  const AdminRepository(this._api);
  final ApiClient _api;

  Future<AdminStatistics> statistics() async => (await _api.get(
    ApiPaths.adminStatistics,
    parser: AdminStatistics.fromJson,
  )).data;

  Future<PageResponse<Book>> books({
    String? status,
    int? authorId,
    int? publisherId,
    int? categoryId,
    int page = 1,
    int size = 20,
  }) async => (await _api.get(
    ApiPaths.adminBooks,
    queryParameters: {
      if (status != null) 'status': status,
      if (authorId != null) 'authorId': authorId,
      if (publisherId != null) 'publisherId': publisherId,
      if (categoryId != null) 'categoryId': categoryId,
      'page': page,
      'size': size,
    },
    parser: (v) => PageResponse.fromJson(v, itemParser: Book.fromJson),
  )).data;

  Future<BookDetail> book(int id) async => (await _api.get(
    ApiPaths.adminBook(id),
    parser: BookDetail.fromJson,
  )).data;

  Future<BookDetail> saveBook(Map<String, dynamic> data, {int? id}) async =>
      id == null
      ? (await _api.post(
          ApiPaths.adminBooks,
          data: data,
          parser: BookDetail.fromJson,
        )).data
      : (await _api.put(
          ApiPaths.adminBook(id),
          data: data,
          parser: BookDetail.fromJson,
        )).data;

  Future<void> setBookStatus(int id, String status) async {
    await _api.put(ApiPaths.adminBookStatus(id), data: {'status': status});
  }

  Future<void> adjustStock(int id, int amount, String remark) async {
    await _api.put(
      ApiPaths.adminBookStock(id),
      data: {'changeQuantity': amount, 'remark': remark.trim()},
    );
  }

  Future<UploadResult> upload(List<int> bytes, String filename) async =>
      (await _api.postMultipart(
        ApiPaths.adminImageUpload,
        bytes: bytes,
        filename: filename,
        parser: UploadResult.fromJson,
      )).data;

  Future<PageResponse<AdminAuthor>> authors({
    String? keyword,
    int page = 1,
    int size = 20,
  }) async => (await _api.get(
    ApiPaths.adminAuthors,
    queryParameters: {
      if (keyword != null && keyword.trim().isNotEmpty)
        'keyword': keyword.trim(),
      'page': page,
      'size': size,
    },
    parser: (v) => PageResponse.fromJson(v, itemParser: AdminAuthor.fromJson),
  )).data;

  Future<void> saveAuthor(Map<String, dynamic> data, {int? id}) async {
    if (id == null) {
      await _api.post(ApiPaths.adminAuthors, data: data);
    } else {
      await _api.put(ApiPaths.adminAuthor(id), data: data);
    }
  }

  Future<void> deleteAuthor(int id) => _delete(ApiPaths.adminAuthor(id));

  Future<PageResponse<AdminPublisher>> publishers({
    String? keyword,
    int page = 1,
    int size = 20,
  }) async => (await _api.get(
    ApiPaths.adminPublishers,
    queryParameters: {
      if (keyword != null && keyword.trim().isNotEmpty)
        'keyword': keyword.trim(),
      'page': page,
      'size': size,
    },
    parser: (v) =>
        PageResponse.fromJson(v, itemParser: AdminPublisher.fromJson),
  )).data;

  Future<void> savePublisher(Map<String, dynamic> data, {int? id}) async {
    if (id == null) {
      await _api.post(ApiPaths.adminPublishers, data: data);
    } else {
      await _api.put(ApiPaths.adminPublisher(id), data: data);
    }
  }

  Future<void> deletePublisher(int id) => _delete(ApiPaths.adminPublisher(id));

  Future<List<AdminCategory>> categories({int? status}) async =>
      (await _api.get(
        ApiPaths.adminCategories,
        queryParameters: {if (status != null) 'status': status},
        parser: (v) {
          if (v is! List) throw const FormatException('分类响应必须是数组');
          return v.map(AdminCategory.fromJson).toList(growable: false);
        },
      )).data;

  Future<List<AdminCategory>> categoryTree({int? status}) async =>
      (await _api.get(
        ApiPaths.adminCategoriesTree,
        queryParameters: {if (status != null) 'status': status},
        parser: (v) {
          if (v is! List) throw const FormatException('分类树响应必须是数组');
          return v.map(AdminCategory.fromJson).toList(growable: false);
        },
      )).data;

  Future<void> saveCategory(Map<String, dynamic> data, {int? id}) async {
    if (id == null) {
      await _api.post(ApiPaths.adminCategories, data: data);
    } else {
      await _api.put(ApiPaths.adminCategory(id), data: data);
    }
  }

  Future<void> setCategoryStatus(int id, int status) async {
    await _api.put(ApiPaths.adminCategoryStatus(id), data: {'status': status});
  }

  Future<void> deleteCategory(int id) => _delete(ApiPaths.adminCategory(id));

  Future<PageResponse<BookOrder>> orders({
    String? orderNo,
    int? userId,
    String? status,
    int page = 1,
    int size = 20,
  }) async => (await _api.get(
    ApiPaths.adminOrders,
    queryParameters: {
      if (orderNo != null && orderNo.trim().isNotEmpty)
        'orderNo': orderNo.trim(),
      if (userId != null) 'userId': userId,
      if (status != null) 'status': status,
      'page': page,
      'size': size,
    },
    parser: (v) => PageResponse.fromJson(v, itemParser: BookOrder.fromJson),
  )).data;

  Future<BookOrder> order(int id) async => (await _api.get(
    ApiPaths.adminOrder(id),
    parser: BookOrder.fromJson,
  )).data;

  Future<void> shipOrder(int id) async {
    await _api.put(ApiPaths.adminShipOrder(id));
  }

  Future<PageResponse<UserReview>> reviews({
    int? bookId,
    int? userId,
    int? status,
    int page = 1,
    int size = 20,
  }) async => (await _api.get(
    ApiPaths.adminReviews,
    queryParameters: {
      if (bookId != null) 'bookId': bookId,
      if (userId != null) 'userId': userId,
      if (status != null) 'status': status,
      'page': page,
      'size': size,
    },
    parser: (v) => PageResponse.fromJson(v, itemParser: UserReview.fromJson),
  )).data;

  Future<void> setReviewStatus(int id, int status) async {
    await _api.put(ApiPaths.adminReviewStatus(id), data: {'status': status});
  }

  Future<PageResponse<InventoryLog>> inventoryLogs({
    int? bookId,
    int? orderId,
    String? type,
    String? startTime,
    String? endTime,
    int page = 1,
    int size = 20,
  }) async => (await _api.get(
    ApiPaths.adminInventoryLogs,
    queryParameters: {
      if (bookId != null) 'bookId': bookId,
      if (orderId != null) 'orderId': orderId,
      if (type != null) 'changeType': type,
      if (startTime != null && startTime.isNotEmpty) 'startTime': startTime,
      if (endTime != null && endTime.isNotEmpty) 'endTime': endTime,
      'page': page,
      'size': size,
    },
    parser: (v) => PageResponse.fromJson(v, itemParser: InventoryLog.fromJson),
  )).data;

  Future<void> _delete(String path) async {
    await _api.delete<dynamic>(path);
  }
}
