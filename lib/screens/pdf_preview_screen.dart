import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String fileName;
  final String title;

  const PdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.fileName,
    this.title = 'Preview PDF',
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool saving = false;

  Future<void> _save() async {
    if (saving) return;
    setState(() => saving = true);

    try {
      final result = await FilePicker.saveFile(
        dialogTitle: 'Simpan laporan PDF',
        fileName: widget.fileName,
        bytes: widget.pdfBytes,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );

      if (!mounted) return;
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF berhasil disimpan.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: saving ? null : _save,
            tooltip: 'Simpan PDF',
            icon: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => widget.pdfBytes,
        pdfFileName: widget.fileName,
        initialPageFormat: PdfPageFormat.a4.landscape,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        maxPageWidth: 900,
        padding: const EdgeInsets.all(12),
        shareActionExtraSubject: widget.title,
        shareActionExtraBody: widget.title,
      ),
    );
  }
}
