import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'login_screen.dart' show AppColors;
import '../services/api_service.dart';

class AdminDocumentsScreen extends StatefulWidget {
  const AdminDocumentsScreen({super.key});

  @override
  State<AdminDocumentsScreen> createState() => _AdminDocumentsScreenState();
}

class _AdminDocumentsScreenState extends State<AdminDocumentsScreen> {
  List<AdminDocument> _documents = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final docs = await ApiService.listDocuments();
      if (!mounted) return;
      setState(() => _documents = docs);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('listDocuments error: $e');
      if (mounted) setState(() => _error = "Couldn't load documents.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickAndUpload() async {
    if (_isUploading) return;

    // Bytes, not paths: Chrome has no file path to give us.
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['txt', 'pdf'],
    );
    if (file == null) return; // user cancelled

    setState(() => _isUploading = true);
    try {
      final bytes = await file.readAsBytes();
      await ApiService.uploadDocument(filename: file.name, bytes: bytes);
      if (!mounted) return;
      _snack('Uploaded ${file.name}');
      await _loadDocuments();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      debugPrint('upload error: $e');
      if (mounted) _snack('Upload failed. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _confirmDelete(AdminDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
          '"${doc.filename}" will be removed and UniAssist will no longer '
          'use it to answer questions. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.deleteDocument(doc.id);
      if (!mounted) return;
      _snack('Deleted ${doc.filename}');
      await _loadDocuments();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      debugPrint('delete error: $e');
      if (mounted) _snack("Couldn't delete the document. Try again.");
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Unknown date';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              } else {
                navigator.pushNamedAndRemoveUntil(
                  '/home',
                  (route) => false,
                );
              }
            },
          ),
          title: const Text('Manage documents'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickAndUpload,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: _isUploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onPrimary,
                ),
              )
            : const Icon(Icons.upload_file),
        label: Text(_isUploading ? 'Uploading...' : 'Upload'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700)),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: _loadDocuments, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_documents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No documents yet. Tap Upload to add a .txt or .pdf file.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.onSurfaceVariant),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: _documents.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final doc = _documents[index];
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.outlineVariant.withOpacity(0.4)),
            ),
            child: ListTile(
              leading: Icon(
                doc.filename.toLowerCase().endsWith('.pdf')
                    ? Icons.picture_as_pdf_outlined
                    : Icons.description_outlined,
                color: AppColors.primary,
              ),
              title: Text(doc.filename,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${_formatDate(doc.uploadDate)} • ${doc.chunkCount} chunks'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(doc),
              ),
            ),
          );
        },
      ),
    );
  }
}