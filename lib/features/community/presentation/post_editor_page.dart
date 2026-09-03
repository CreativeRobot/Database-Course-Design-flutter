import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_exception.dart';
import '../data/community_models.dart';
import 'community_controller.dart';
import 'community_view_helpers.dart';
import 'community_widgets.dart';

class PostEditorPage extends ConsumerStatefulWidget {
  const PostEditorPage({super.key});

  static const maxImages = 9;

  @override
  ConsumerState<PostEditorPage> createState() => _PostEditorPageState();
}

class _PostEditorPageState extends ConsumerState<PostEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _bookSearchController = TextEditingController();
  final List<PlatformFile> _images = [];
  final Set<int> _selectedBookIds = {};
  String _bookSearchKeyword = '';
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _bookSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = PostEditorPage.maxImages - _images.length;
    if (remaining <= 0) {
      _showMessage('每篇帖子最多添加${PostEditorPage.maxImages}张图片');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );
    if (result == null) return;
    final readable = result.files.where((file) => file.bytes != null).toList();
    final skipped = result.files.length - readable.length;
    setState(() => _images.addAll(readable.take(remaining)));
    if (result.files.length > remaining) {
      _showMessage('只保留前$remaining张图片，最多可添加${PostEditorPage.maxImages}张');
    } else if (skipped > 0) {
      _showMessage('有$skipped张图片无法读取，已跳过');
    }
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final urls = <String>[];
      for (final image in _images) {
        final bytes = image.bytes;
        if (bytes == null) continue;
        final uploaded = await ref
            .read(communityRepositoryProvider)
            .uploadImage(bytes: bytes, filename: image.name);
        urls.add(uploaded.url);
      }
      final created = await ref
          .read(communityRepositoryProvider)
          .createPost(
            CommunityPostDraft(
              title: _titleController.text,
              content: _contentController.text,
              imageUrls: urls,
              bookIds: _selectedBookIds.toList(growable: false),
            ),
          );
      ref.invalidate(communityFeedProvider);
      if (mounted) context.go(AppRoutePaths.communityPost(created.id));
    } on ApiException catch (error) {
      _showMessage(error.message);
    } on ArgumentError catch (error) {
      _showMessage(error.message?.toString() ?? '帖子内容不符合要求');
    } catch (_) {
      _showMessage('帖子发布失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(communityBookOptionsProvider);
    final bookOptions = books.asData?.value ?? const [];
    final visibleBookOptions = filterCommunityBookOptions(
      bookOptions,
      _selectedBookIds,
      _bookSearchKeyword,
    );
    return Scaffold(
      backgroundColor: CommunityColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('发布帖子'),
        leading: IconButton(
          onPressed: () => context.go(AppRoutePaths.community),
          icon: const Icon(Icons.close_rounded),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_rounded),
              label: Text(_submitting ? '发布中' : '发布'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 60),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Form(
              key: _formKey,
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: CommunityColors.line),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '分享你的阅读发现',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '可以添加图片并关联相关图书，让其他读者更容易找到这篇帖子。',
                        style: TextStyle(color: CommunityColors.muted),
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: _titleController,
                        maxLength: 120,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '帖子标题',
                          hintText: '用一句话概括你想分享的内容',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return '请输入帖子标题';
                          if (text.length > 120) return '标题不能超过120个字符';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _contentController,
                        minLines: 8,
                        maxLines: 16,
                        maxLength: 5000,
                        decoration: const InputDecoration(
                          labelText: '正文',
                          alignLabelWithHint: true,
                          hintText: '写下你的书评、问题或阅读感受…',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return '请输入帖子正文';
                          if (text.length > 5000) return '正文不能超过5000个字符';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '帖子图片',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text('${_images.length}/${PostEditorPage.maxImages}'),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _submitting ? null : _pickImages,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: const Text('选择图片'),
                          ),
                        ],
                      ),
                      if (_images.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 190,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.2,
                              ),
                          itemCount: _images.length,
                          itemBuilder: (context, index) {
                            final image = _images[index];
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    image.bytes!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 5,
                                  top: 5,
                                  child: IconButton.filled(
                                    tooltip: '移除图片',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _submitting
                                        ? null
                                        : () => setState(
                                            () => _images.removeAt(index),
                                          ),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        '关联图书（可选）',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '可选择多本相关图书',
                        style: TextStyle(color: CommunityColors.muted),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bookSearchController,
                        enabled: !_submitting,
                        decoration: InputDecoration(
                          hintText: '搜索要关联的图书',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _bookSearchKeyword.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '清除图书搜索',
                                  onPressed: () {
                                    _bookSearchController.clear();
                                    setState(() => _bookSearchKeyword = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() => _bookSearchKeyword = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (books.isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (books.hasError)
                        const Text('图书选项加载失败，请稍后重试')
                      else if (bookOptions.isEmpty)
                        const Text('暂时没有可关联的图书')
                      else if (visibleBookOptions.isEmpty)
                        const Text('没有找到相关图书')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final book in visibleBookOptions)
                              FilterChip(
                                selected: _selectedBookIds.contains(book.id),
                                avatar: const Icon(
                                  Icons.menu_book_outlined,
                                  size: 17,
                                ),
                                label: Text(book.title),
                                onSelected: _submitting
                                    ? null
                                    : (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedBookIds.add(book.id);
                                          } else {
                                            _selectedBookIds.remove(book.id);
                                          }
                                        });
                                      },
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
