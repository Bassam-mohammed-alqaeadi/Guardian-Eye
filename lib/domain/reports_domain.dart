import 'package:meta/meta.dart';

/// FS-009 — Reports & Export. Report period windows read by the aggregation
/// layer. Honest values only: the report never pretends a period contains
/// data that was not captured.
enum ReportPeriod {
  /// The last 7 days (today not yet finished at any time of day).
  week,

  /// The current calendar month from the first day until now.
  month,

  /// An explicit custom range [start, end].
  custom,
}

/// Export artefact formats supported by [ReportExportService].
enum ReportFormat {
  /// Paginated A4 PDF written with the `pdf` package (RTL Arabic-aware).
  pdf,

  /// Plain CSV (UTF-8 with BOM) written with the `csv` package.
  csv,
}

/// A single metric value recorded inside a report section.
@immutable
class ReportMetric {
  const ReportMetric({
    required this.labelKey,
    required this.value,
    this.numericValue,
    this.tone = ReportTone.neutral,
  });

  final String labelKey;
  final String value;
  final int? numericValue;
  final ReportTone tone;
}

/// Tone applied to a metric card so the report never hides a bad signal.
enum ReportTone { neutral, good, warning, critical }

/// Aggregated snapshot for one subsystem section of the report.
@immutable
class ReportSection {
  const ReportSection({
    required this.kind,
    required this.titleKey,
    required this.dataStart,
    required this.dataEnd,
    required this.metrics,
    this.rows = const [],
    this.isEmpty = false,
  });

  final String kind;
  final String titleKey;
  final DateTime dataStart;
  final DateTime dataEnd;
  final List<ReportMetric> metrics;
  final List<List<String>> rows;
  final bool isEmpty;

  ReportSection copyWith({List<ReportMetric>? metrics}) => ReportSection(
        kind: kind,
        titleKey: titleKey,
        dataStart: dataStart,
        dataEnd: dataEnd,
        metrics: metrics ?? this.metrics,
        rows: rows,
        isEmpty: isEmpty,
      );
}

/// Section kinds produced by the aggregation layer.
extension ReportSectionKind on ReportSection {
  static const String web = 'web';
  static const String usage = 'usage';
  static const String location = 'location';
  static const String safety = 'safety';
  static const String modes = 'modes';
  static const String sos = 'sos';
}

/// Full report snapshot for one family over one period.
@immutable
class FamilyReportSnapshot {
  const FamilyReportSnapshot({
    required this.familyId,
    required this.familyName,
    required this.period,
    required this.start,
    required this.end,
    required this.sections,
    required this.capturedAt,
  });

  final String familyId;
  final String familyName;
  final ReportPeriod period;
  final DateTime start;
  final DateTime end;
  final List<ReportSection> sections;
  final DateTime capturedAt;

  bool get isEmpty => sections.isEmpty || sections.every((s) => s.isEmpty);
}
