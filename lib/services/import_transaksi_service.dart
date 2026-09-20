import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../models/import_transaksi_row.dart';
import 'db_helper.dart';

class ImportPreview {
  final List<ImportTransaksiRow> rows;
  final List<String> errors;
  final String fileName;
  const ImportPreview({required this.rows, required this.errors, required this.fileName});
  bool get canImport => rows.isNotEmpty && errors.isEmpty;
}

class ImportResult {
  final int imported;
  const ImportResult(this.imported);
}

class ImportTransaksiService {
  static const headers = <String>[
    'nama_pelanggan','no_hp','alamat','tanggal','nomor_resi',
    'nama_penerima','kota_tujuan','quantity','berat','jumlah','catatan',
  ];

  static Future<ImportPreview?> pickAndPreview() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['xlsx', 'csv'], withData: true,
    );
    if (result == null || result.files.single.bytes == null) return null;
    final file = result.files.single;
    try {
      final ext = (file.extension ?? '').toLowerCase();
      final rows = ext == 'csv' ? _parseCsv(file.bytes!) : _parseXlsx(file.bytes!);
      return ImportPreview(rows: rows, errors: const [], fileName: file.name);
    } catch (e) {
      return ImportPreview(rows: const [], errors: [e.toString().replaceFirst('Exception: ', '')], fileName: file.name);
    }
  }

  static Future<ImportResult> importRows(List<ImportTransaksiRow> rows) async =>
      ImportResult(await DbHelper.instance.importTransaksiBatch(rows));

  static Future<void> saveTemplate() async {
    final excel = Excel.createExcel();
    final sheet = excel['Template'];
    excel.delete('Sheet1');
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    sheet.appendRow([
      TextCellValue('PT Contoh Jaya'), TextCellValue('08123456789'),
      TextCellValue('Alamat pelanggan'), TextCellValue('20/09/2026'),
      TextCellValue('RESI-001'), TextCellValue('Nama Penerima'),
      TextCellValue('Malang'), const IntCellValue(1), const DoubleCellValue(1.5),
      const IntCellValue(25000), TextCellValue('Contoh'),
    ]);
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Gagal membuat template Excel.');
    await FilePicker.platform.saveFile(
      fileName: 'template_import_transaksi.xlsx',
      bytes: Uint8List.fromList(bytes),
    );
  }

  static List<ImportTransaksiRow> _parseXlsx(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      throw const FormatException('File Excel tidak memiliki sheet.');
    }
    final sheet = workbook.tables.values.first;
    if (sheet.rows.isEmpty) {
      throw const FormatException('File kosong.');
    }
    final indexes = _headerIndexes(_normalizeHeaders(sheet.rows.first.map(_cellText).toList()));
    _validateHeaders(indexes);
    final result = <ImportTransaksiRow>[];
    final errors = <String>[];
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.every((cell) => _cellText(cell).trim().isEmpty)) continue;
      try {
        result.add(_parseRow((key) => indexes[key] == null || indexes[key]! >= row.length ? '' : _cellText(row[indexes[key]!]), i + 1));
      } catch (e) {
        errors.add(e.toString().replaceFirst('Exception: ', ''));
      }
    }
    if (errors.isNotEmpty) throw FormatException(errors.take(10).join('\n'));
    if (result.isEmpty) throw const FormatException('Tidak ada transaksi yang dapat diimport.');
    return result;
  }

  static List<ImportTransaksiRow> _parseCsv(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('\uFEFF', '');
    final delimiter = _detectCsvDelimiter(text);
    final lines = _csvRecords(text, delimiter);
    if (lines.isEmpty) throw const FormatException('File CSV kosong.');
    final indexes = _headerIndexes(_normalizeHeaders(lines.first));
    _validateHeaders(indexes);
    final result = <ImportTransaksiRow>[];
    final errors = <String>[];
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].every((v) => v.trim().isEmpty)) continue;
      try {
        final values = lines[i];
        result.add(_parseRow((key) => indexes[key] == null || indexes[key]! >= values.length ? '' : values[indexes[key]!], i + 1));
      } catch (e) {
        errors.add(e.toString().replaceFirst('Exception: ', ''));
      }
    }
    if (errors.isNotEmpty) throw FormatException(errors.take(10).join('\n'));
    if (result.isEmpty) throw const FormatException('Tidak ada transaksi yang dapat diimport.');
    return result;
  }

  static ImportTransaksiRow _parseRow(String Function(String) get, int line) {
    final nama = get('nama_pelanggan').trim();
    final resi = get('nomor_resi').trim();
    final penerima = get('nama_penerima').trim();
    final kota = get('kota_tujuan').trim();
    if (nama.isEmpty || resi.isEmpty || penerima.isEmpty || kota.isEmpty) {
      throw FormatException('Baris $line: nama pelanggan, nomor resi, penerima, dan kota tujuan wajib diisi.');
    }
    final tanggal = _parseDate(get('tanggal'), line);
    final quantity = _parseInt(get('quantity'), line, 'quantity');
    final berat = _parseDouble(get('berat'), line, 'berat');
    final jumlah = _parseInt(get('jumlah'), line, 'jumlah');
    if (quantity <= 0 || berat < 0 || jumlah <= 0) throw FormatException('Baris $line: quantity/berat/jumlah tidak valid.');
    return ImportTransaksiRow(
      namaPelanggan: nama, noHp: _nullable(get('no_hp')), alamat: _nullable(get('alamat')),
      tanggal: tanggal, nomorResi: resi, namaPenerima: penerima, kotaTujuan: kota,
      quantity: quantity, berat: berat, jumlah: jumlah, catatan: _nullable(get('catatan')),
    );
  }

  static DateTime _parseDate(String raw, int line) {
    final value = raw.trim();
    if (value.isEmpty) throw FormatException('Baris $line: tanggal wajib diisi.');
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    final parts = value.split(RegExp(r'[./-]')).map((e) => int.tryParse(e.trim())).toList();
    if (parts.length == 3 && parts.every((e) => e != null)) {
      final a = parts[0]!, b = parts[1]!, c = parts[2]!;
      if (a > 1900) return DateTime(a, b, c);
      if (c > 1900) return DateTime(c, b, a);
    }
    final serial = double.tryParse(value);
    if (serial != null && serial > 1 && serial < 100000) return DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
    throw FormatException('Baris $line: format tanggal "$value" tidak valid.');
  }

  static int _parseInt(String raw, int line, String field) {
    var value = raw.trim().replaceAll(RegExp(r'(?i)rp'), '').replaceAll(' ', '');
    if (value.isEmpty) {
      throw FormatException('Baris $line: $field tidak valid.');
    }
    final negative = value.startsWith('-');
    value = value.replaceAll('-', '');
    if (value.contains(',') && value.contains('.')) {
      final lastComma = value.lastIndexOf(',');
      final lastDot = value.lastIndexOf('.');
      final decimalIndex = lastComma > lastDot ? lastComma : lastDot;
      final decimals = value.substring(decimalIndex + 1);
      if (decimals.isNotEmpty && int.tryParse(decimals) != 0) {
        throw FormatException('Baris $line: $field harus berupa bilangan bulat.');
      }
      value = value.substring(0, decimalIndex).replaceAll('.', '').replaceAll(',', '');
    } else if (value.contains('.') || value.contains(',')) {
      final separator = value.contains('.') ? '.' : ',';
      final parts = value.split(separator);
      if (parts.length != 2 || parts[1].length != 3) {
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed == null || parsed % 1 != 0) {
          throw FormatException('Baris $line: $field harus berupa bilangan bulat.');
        }
        return negative ? -parsed.toInt() : parsed.toInt();
      }
      value = parts.join();
    }
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw FormatException('Baris $line: $field tidak valid.');
    }
    return negative ? -parsed : parsed;
  }

  static double _parseDouble(String raw, int line, String field) {
    var value = raw.trim().replaceAll(RegExp(r'(?i)rp'), '').replaceAll(' ', '');
    if (value.isEmpty) {
      throw FormatException('Baris $line: $field tidak valid.');
    }
    if (value.contains(',') && value.contains('.')) {
      final lastComma = value.lastIndexOf(',');
      final lastDot = value.lastIndexOf('.');
      final decimalSeparator = lastComma > lastDot ? ',' : '.';
      final thousandsSeparator = decimalSeparator == ',' ? '.' : ',';
      value = value.replaceAll(thousandsSeparator, '').replaceAll(decimalSeparator, '.');
    } else if (value.contains(',')) {
      value = value.replaceAll(',', '.');
    }
    final parsed = double.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), ''));
    if (parsed == null || !parsed.isFinite) {
      throw FormatException('Baris $line: $field tidak valid.');
    }
    return parsed;
  }

  static String _cellText(dynamic cell) {
    if (cell == null) return '';
    final value = cell.value;
    if (value is DateTime) return value.toIso8601String();
    return value?.toString() ?? '';
  }

  static String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
  static List<String> _normalizeHeaders(List<String> values) => values.map((v) => v.trim().toLowerCase().replaceAll(' ', '_')).toList();

  static Map<String, int> _headerIndexes(List<String> headers) {
    final map = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      map[headers[i]] = i;
    }
    return map;
  }

  static void _validateHeaders(Map<String, int> indexes) {
    const required = ['nama_pelanggan','tanggal','nomor_resi','nama_penerima','kota_tujuan','quantity','berat','jumlah'];
    final missing = required.where((h) => !indexes.containsKey(h)).toList();
    if (missing.isNotEmpty) {
      throw FormatException('Kolom wajib tidak ditemukan: ${missing.join(', ')}');
    }
  }

  static String _detectCsvDelimiter(String text) {
    final firstLine = text.split(RegExp(r'[\r\n]')).first;
    final commaCount = firstLine.split(',').length - 1;
    final semicolonCount = firstLine.split(';').length - 1;
    return semicolonCount > commaCount ? ';' : ',';
  }

  static List<List<String>> _csvRecords(String text, String delimiter) {
    final records = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '"') {
        if (quoted && i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (ch == delimiter && !quoted) {
        row.add(field.toString());
        field = StringBuffer();
      } else if ((ch == '\n' || ch == '\r') && !quoted) {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
          i++;
        }
        row.add(field.toString());
        field = StringBuffer();
        if (row.any((v) => v.trim().isNotEmpty)) records.add(row);
        row = <String>[];
      } else {
        field.write(ch);
      }
    }
    row.add(field.toString());
    if (row.any((v) => v.trim().isNotEmpty)) records.add(row);
    return records;
  }
}
