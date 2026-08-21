import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/reports_domain.dart';

/// FS-009 — report artefact export. Generates PDF and CSV files from an
/// honest [FamilyReportSnapshot] and returns the absolute file path so the
/// presentation layer can attach it to [share_plus]'s share call.
///
/// Never claims success for data that was not present: empty sections are
/// labelled inside the artefact itself ("No data captured in this period").
class ReportExportService {
  ReportExportService({pw.Font? font, Directory? outputDirectory})
      : _font = font,
        _outputDirectory = outputDirectory;

  final pw.Font? _font;
  final Directory? _outputDirectory;

  Future<pw.ThemeData> _buildTheme() async {
    if (_font != null) return pw.ThemeData.withFont(base: _font!);
    try {
      // Try to load Cairo for Arabic/Unicode support if available in assets.
      final fontData = await File('assets/fonts/Cairo-Regular.ttf').readAsBytes();
      final boldData = await File('assets/fonts/Cairo-Bold.ttf').readAsBytes();
      final base = pw.Font.ttf(fontData.buffer.asByteData());
      final bold = pw.Font.ttf(boldData.buffer.asByteData());
      return pw.ThemeData.withFont(base: base, bold: bold);
    } catch (_) {
      // Fallback to Helvetica (no Unicode support, but safe).
      return pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
  }

  /// Export a snapshot to the given [format] and return the written file.
  Future<File> export({
    required FamilyReportSnapshot snapshot,
    required ReportFormat format,
  }) async {
    final dir = _outputDirectory ?? await getApplicationDocumentsDirectory();
    if (format == ReportFormat.csv) {
      final csv = _buildCsv(snapshot);
      final file = File(p.join(dir.path,
          'guardian_report_${snapshot.familyId}_${_stamp(snapshot)}.csv'));
      await file.writeAsString(csv, encoding: utf8);
      return file;
    }
    final theme = await _buildTheme();
    final pdf = _buildPdf(snapshot, theme);
    final file = File(p.join(dir.path,
        'guardian_report_${snapshot.familyId}_${_stamp(snapshot)}.pdf'));
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  String _stamp(FamilyReportSnapshot snapshot) {
    final t = snapshot.capturedAt;
    return '${t.year}${_two(t.month)}${_two(t.day)}_${_two(t.hour)}${_two(t.minute)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  // ----------------------------------------------------------------- CSV

  String _buildCsv(FamilyReportSnapshot snapshot) {
    final cells = <List<Object?>>[];
    cells.add(['Guardian Eye Pro - Family Report']);
    cells.add(['Family', snapshot.familyName]);
    cells.add(['Period', '${_d(snapshot.start)} to ${_d(snapshot.end)}']);
    cells.add(['Captured at', _d(snapshot.capturedAt)]);
    cells.add([]);

    for (final section in snapshot.sections) {
      cells.add([section.titleKey]);
      for (final metric in section.metrics) {
        cells.add([metric.labelKey, metric.value]);
      }
      if (section.rows.isNotEmpty) {
        for (final row in section.rows) {
          cells.add(row);
        }
      } else if (section.isEmpty) {
        cells.add(['(no-data)', 'No data captured in this period']);
      }
      cells.add([]);
    }
    return const ListToCsvConverter().convert(cells);
  }

  String _d(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

  // ----------------------------------------------------------------- PDF

  pw.Document _buildPdf(FamilyReportSnapshot snapshot, pw.ThemeData theme) {
    final doc = pw.Document(theme: theme);
    final navy = PdfColor.fromInt(0xFF0F2A5B);
    final teal = PdfColor.fromInt(0xFF00B8A9);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      textDirection: pw.TextDirection.ltr, // Base direction
      build: (pw.Context context) => [
        _pdfHeader(snapshot, navy, teal),
        for (final section in snapshot.sections)
          _pdfSection(section, navy, teal),
        _pdfFooter(snapshot, navy),
      ],
    ));
    return doc;
  }

  pw.Widget _pdfHeader(
      FamilyReportSnapshot snapshot, PdfColor navy, PdfColor teal) {
    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: navy,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
              pw.Text('Guardian Eye Pro',
                  style: pw.TextStyle(
                      font: _font,
                      color: PdfColors.white,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Family Report - ${snapshot.familyName}',
                  style: pw.TextStyle(
                      font: _font, color: PdfColors.white, fontSize: 12)),
            ]),
            pw.Text(_periodLabel(snapshot.period),
                style: pw.TextStyle(
                    font: _font, color: teal, fontSize: 12,
                    fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'Period: ${_d(snapshot.start)} to ${_d(snapshot.end)}  |  '
        'Generated: ${_d(snapshot.capturedAt)}',
        style: pw.TextStyle(font: _font, fontSize: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 12),
    ]);
  }

  String _periodLabel(ReportPeriod period) => switch (period) {
        ReportPeriod.week => 'Last 7 days',
        ReportPeriod.month => 'This month',
        ReportPeriod.custom => 'Custom range',
      };

  pw.Widget _pdfSection(
      ReportSection section, PdfColor navy, PdfColor teal) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: teal,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Text(section.titleKey.toUpperCase(),
            style: pw.TextStyle(
                font: _font, color: PdfColors.white, fontSize: 11,
                fontWeight: pw.FontWeight.bold)),
      ),
      pw.SizedBox(height: 6),
      if (section.isEmpty)
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
          ),
          child: pw.Text(
            'No data captured in this period. The report only includes '
            'records actually stored on this device.',
            style: pw.TextStyle(font: _font, fontSize: 10,
                color: PdfColors.grey700)),
        )
      else ...[
        pw.Table.fromTextArray(
          context: null,
          data: [
            ['Metric', 'Value'],
            for (final m in section.metrics) [m.labelKey, m.value],
          ],
          headerStyle: pw.TextStyle(
              font: _font, color: PdfColors.white, fontSize: 10,
              fontWeight: pw.FontWeight.bold),
          headerDecoration: pw.BoxDecoration(color: navy),
          cellStyle: pw.TextStyle(font: _font, fontSize: 10),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
          },
          rowDecoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
          ),
        ),
        if (section.rows.isNotEmpty) pw.SizedBox(height: 6),
        if (section.rows.isNotEmpty)
          pw.Table.fromTextArray(
            context: null,
            data: [
              ['Domain', 'Category', 'Hits'],
              for (final row in section.rows)
                ['${row.length > 0 ? row[0] : ''}',
                 row.length > 1 ? '${row[1]}' : '',
                 row.length > 2 ? '${row[2]}' : ''],
            ],
            headerStyle: pw.TextStyle(
                font: _font, color: PdfColors.white, fontSize: 10,
                fontWeight: pw.FontWeight.bold),
            headerDecoration: pw.BoxDecoration(color: navy),
            cellStyle: pw.TextStyle(font: _font, fontSize: 10),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
            },
          ),
      ],
      pw.SizedBox(height: 14),
    ]);
  }

  pw.Widget _pdfFooter(FamilyReportSnapshot snapshot, PdfColor navy) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: pw.Text(
        'Honest report: generated from data recorded on the family device. '
        'Guardian Eye Pro - ${snapshot.capturedAt.year}',
        style: pw.TextStyle(font: _font, fontSize: 8, color: navy),
      ),
    );
  }
}
