import '../../core/localization/app_localizations.dart';

/// FS-002 — Web Filtering. The canonical category taxonomy the platform
/// filters on. Each category pairs its storage key with the icon and
/// localization keys a screen renders. The child experience, the AI event
/// layer (`WEB_BLOCK_HIT` / `WEB_POLICY_UPDATED`), and the parent UI all
/// consume this single source — categories are never hard-coded per
/// screen.
///
/// Grouping follows the master spec (WF-002): *sensitive* content that is
/// blocked by default, *age* categories that fit older ages, and *social*
/// categories whose per-child granularity carries the real parenting
/// decision.
class WebFilterCategory {
  const WebFilterCategory({
    required this.key,
    required this.l10nKey,
    required this.descriptionKey,
    required this.group,
    required this.blockedByDefault,
    required this.icon,
  });

  final String key;
  final String l10nKey;
  final String descriptionKey;
  final WebCategoryGroup group;
  final bool blockedByDefault;
  final String icon;

  String label(AppLocalizations l10n) => l10n.t(l10nKey);
  String description(AppLocalizations l10n) => l10n.t(descriptionKey);
}

enum WebCategoryGroup { sensitive, age, social }

class WebFilterCategories {
  static const List<WebFilterCategory> all = [
    WebFilterCategory(
        key: 'adultContent',
        l10nKey: 'categoryAdultContent',
        descriptionKey: 'categoryAdultContentDesc',
        group: WebCategoryGroup.sensitive,
        blockedByDefault: true,
        icon: '18_plus'),
    WebFilterCategory(
        key: 'gambling',
        l10nKey: 'categoryGambling',
        descriptionKey: 'categoryGamblingDesc',
        group: WebCategoryGroup.sensitive,
        blockedByDefault: true,
        icon: 'casino_outlined'),
    WebFilterCategory(
        key: 'violence',
        l10nKey: 'categoryViolence',
        descriptionKey: 'categoryViolenceDesc',
        group: WebCategoryGroup.sensitive,
        blockedByDefault: true,
        icon: 'gpp_bad_outlined'),
    WebFilterCategory(
        key: 'drugs',
        l10nKey: 'categoryDrugs',
        descriptionKey: 'categoryDrugsDesc',
        group: WebCategoryGroup.sensitive,
        blockedByDefault: true,
        icon: 'vaccines_outlined'),
    WebFilterCategory(
        key: 'dangerousContent',
        l10nKey: 'categoryDangerousContent',
        descriptionKey: 'categoryDangerousContentDesc',
        group: WebCategoryGroup.sensitive,
        blockedByDefault: true,
        icon: 'warning_amber_outlined'),
    WebFilterCategory(
        key: 'bullying',
        l10nKey: 'categoryBullying',
        descriptionKey: 'categoryBullyingDesc',
        group: WebCategoryGroup.sensitive,
        blockedByDefault: true,
        icon: 'record_voice_over_outlined'),
    WebFilterCategory(
        key: 'teenContent',
        l10nKey: 'categoryTeenContent',
        descriptionKey: 'categoryTeenContentDesc',
        group: WebCategoryGroup.age,
        blockedByDefault: false,
        icon: 'psychology_outlined'),
    WebFilterCategory(
        key: 'dating',
        l10nKey: 'categoryDating',
        descriptionKey: 'categoryDatingDesc',
        group: WebCategoryGroup.age,
        blockedByDefault: false,
        icon: 'favorite_border'),
    WebFilterCategory(
        key: 'gaming',
        l10nKey: 'categoryGaming',
        descriptionKey: 'categoryGamingDesc',
        group: WebCategoryGroup.age,
        blockedByDefault: false,
        icon: 'sports_esports_outlined'),
    WebFilterCategory(
        key: 'streaming',
        l10nKey: 'categoryStreaming',
        descriptionKey: 'categoryStreamingDesc',
        group: WebCategoryGroup.age,
        blockedByDefault: false,
        icon: 'movie_outlined'),
    WebFilterCategory(
        key: 'social',
        l10nKey: 'categorySocial',
        descriptionKey: 'categorySocialDesc',
        group: WebCategoryGroup.social,
        blockedByDefault: false,
        icon: 'forum_outlined'),
    WebFilterCategory(
        key: 'suspiciousLanguage',
        l10nKey: 'categorySuspiciousLanguage',
        descriptionKey: 'categorySuspiciousLanguageDesc',
        group: WebCategoryGroup.sensitive,
        blockedByDefault: true,
        icon: 'chat_bubble_outline'),
  ];

  static const List<WebCategoryGroup> groups = [
    WebCategoryGroup.sensitive,
    WebCategoryGroup.age,
    WebCategoryGroup.social,
  ];

  static String groupLabel(AppLocalizations l10n, WebCategoryGroup group) =>
      switch (group) {
        WebCategoryGroup.sensitive => l10n.t('sensitiveCategory'),
        WebCategoryGroup.age => l10n.t('ageCategory'),
        WebCategoryGroup.social => l10n.t('socialCategory'),
      };

  static List<WebFilterCategory> ofGroup(WebCategoryGroup group) =>
      all.where((category) => category.group == group).toList();
}
