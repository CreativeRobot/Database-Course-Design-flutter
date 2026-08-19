String? resolveMediaUrl(String baseUrl, String? path) {
  if (path == null || path.trim().isEmpty) return null;
  if (Uri.tryParse(path)?.hasScheme ?? false) return path;
  return '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/${path.replaceFirst(RegExp(r'^/'), '')}';
}
