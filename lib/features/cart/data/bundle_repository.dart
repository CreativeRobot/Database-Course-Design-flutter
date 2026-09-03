import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import 'bundle_models.dart';

class BundleRepository {
  const BundleRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<List<BookBundle>> forBook(int bookId) async {
    final response = await _apiClient.get<List<BookBundle>>(ApiPaths.bookBundles(bookId), parser: (value) => (value as List).map(BookBundle.fromJson).toList(growable: false));
    return response.data;
  }

  Future<List<BookBundle>> adminList() async {
    final response = await _apiClient.get<List<BookBundle>>(ApiPaths.adminBookBundles, parser: (value) => (value as List).map(BookBundle.fromJson).toList(growable: false));
    return response.data;
  }

  Future<BookBundle> create({required String name, String? description, required double bundlePrice, required List<int> bookIds}) async {
    final response = await _apiClient.post<BookBundle>(ApiPaths.adminBookBundles, data: {'name': name, if (description != null) 'description': description, 'bundlePrice': bundlePrice, 'bookIds': bookIds}, parser: BookBundle.fromJson);
    return response.data;
  }

  Future<BookBundle> update(int id, {required String name, String? description, required double bundlePrice, required List<int> bookIds, required int version}) async {
    final response = await _apiClient.put<BookBundle>(ApiPaths.adminBookBundle(id), data: {'name': name, if (description != null) 'description': description, 'bundlePrice': bundlePrice, 'bookIds': bookIds, 'version': version}, parser: BookBundle.fromJson);
    return response.data;
  }

  Future<BookBundle> changeStatus(int id, String status) async {
    final response = await _apiClient.put<BookBundle>(ApiPaths.adminBookBundleStatus(id), data: {'status': status}, parser: BookBundle.fromJson);
    return response.data;
  }
}
