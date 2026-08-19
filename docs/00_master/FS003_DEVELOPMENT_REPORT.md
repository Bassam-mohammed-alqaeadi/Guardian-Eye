# FS-003 — Application Control (التحكم بالتطبيقات): تقرير التنفيذ الكامل

**Commit:** pending (feature/design-system-integration) · **Author:** Manus AI · **Date:** 2026-08-19

## 1. المنتج والمنطق

> **تصحيح معماري أثناء الاختبار (v17.1):** المفتاح الأساسي لجدول `app_policies` أصبح `PRIMARY KEY(family_id, child_id, target)` مع `child_id TEXT NOT NULL DEFAULT ''` — التصميم الأصلي `PK(family_id, target)` كان يجعل السياسة العائلية وسياسة الطفل لنفس التطبيق تستبدل إحداهما الأخرى (INSERT OR REPLACE على نفس المفتاح)، فيكسر قواعد الطفل الفرعية نهائياً. وبهذا التصميم الثابت الثلاثي لا توجد حاجة لنقل البيانات عند الترقية (تصميم أولي لم يسبق إطلاقه).

> **تصحيح سلوكي:** `resolvePolicy` يُحل الآن بترتيب ثابت: تجاوز الطفل الدقيق أولاً، ثم السياسة العائلية العامة — لا اعتماد على ترتيب `updated_at` الذي كان يعيد ترتيب النتائج ويُرجع السياسة الخاطئة.

**Product intent:** يرى الوالد التطبيقات المثبّتة على أجهزة الأبناء المربوطة، يطبّق سياسات حظر/سماح لكل تطبيق، ويحافظ على قائمة سماح دائمة تصمد أمام تغيّر الأوضاع (modes). يُبنى FS-003 فوق قياس الاستخدام الموجود (child_usage_summaries/observations) دون أي حقول خلفية جديدة — البيانات تأتي من حملات المزامنة الحالية التي يرسلها جهاز الطفل.

**Authorization law:** كل شاشة تقرأ `FamilyRuntimeContext.can()` حصرياً؛ لا إعادة تنفيذ للتحقق من الدور محلياً. الإذن المستخدم: `managePolicies` (الوالد/المالك) للكتابة، `viewUsage`/`viewChildStatus` للقراءة حيثما أمكن.

## 2. المواصفة UX (AC-001 … AC-008)

| ID | الشاشة | المسار | الغرض | التركيب | الحالات الصادقة |
| --- | --- | --- | --- | --- | --- |
| AC-001 | لوحة التحكم بالتطبيقات | `/apps/:familyId` | ملخص الحماية: تطبيقات محظورة اليوم، مستوى التقييد، تعرض الطفل لكل تطبيق | GuardianHeroCard + GuardianStatTiles (blockedToday, restrictionLevel) + بطاقات أطفال بـ GuardianStatusChip | loading / empty / error / offline |
| AC-002 | التطبيقات المثبّتة | `/apps/:familyId/:childId` | قائمة التطبيقات على جهاز الطفل مع الحالة وأزرار الحظر/السماح | قائمة قابلة للبحث؛ صف = GuardianIconBadge (أيقونة عامة عند الغياب) + الاسم + GuardianStatusChip؛ النقر → التفاصيل | loading / empty(لا جهاز) / unauthorized |
| AC-003 | تفاصيل التطبيق | `/apps/:familyId/:childId/:appId` | سياسة لكل تطبيق: حظر، مهلة زمنية، عضوية السماح، سجل الاستخدام | مكدس GuardianCard: شريحة حالة + أزرار إجراء + قسم المهلة الزمنية + GuardianSection للتاريخ | loading / error |
| AC-004 | قائمة السماح | `/apps/:familyId/allowlist` | تطبيقات موثوقة لا تُحظر أبداً (المتجر، تطبيقات المدرسة) | GuardianCard list + حوار إضافة؛ CTA للحالة الفارغة | loading / empty |
| AC-005 | قواعد الطفل للتطبيقات | `/apps/:familyId/:childId/rules` | مهل زمنية لكل طفل + قواعد فئات (ألعاب/تواصل/دراسة) | GuardianCard sections مع محررات فئات | loading / empty |
| AC-006 | سجل الاستخدام | `/apps/:familyId/:childId/history` | استخدام يومي لكل تطبيق من التجميعات الحالية | GuardianSection timeline بـ DailyUsageSummary | loading / empty |
| AC-007 | حالة الإنفاذ | `/apps/:familyId/:childId/enforcement` | أدلة صادقة: السياسة مطبّقة/مطلوبة/فشلت لكل جهاز عبر أدلة outbox | بطاقات حالة بـ GuardianStatusChip + ملاحظة offline | loading / no-evidence |
| AC-008 | تعرض الطفل للتطبيقات | `/child/:familyId/:childId/apps` | عرض ذاتي للطفل: القواعد المطبقة عليه فقط + CTA طلب استثناء | Hero للقراءة فقط + قائمة قواعد + CTA استثناء | loading / empty / child-unauthorized |

**قاعدة التصميم:** جميع الشاشات تستخدم primitives فقط (GuardianCard/GuardianHeroCard/GuardianStatusChip/GuardianStateView/GuardianIconBadge/GuardianStatTile/GuardianSection/GuardianOfflineBanner) — ولا عنصر Material مباشر خارجها. لا نجاح مزيف: حالة outbox تُعرض كدليل لا كادعاء.

## 3. المواصفة التقنية

### 3.1 طبقة البيانات المحلية (SQLite v17)

الجداول الجديدة في `guardian_database.dart` (نسخة 16 → 17) بنفس نمط FS-001/FS-002:

| الجدول | الغرض | المفاتيح |
| --- | --- | --- |
| `app_policies` | سياسة لكل تطبيق (block/allow/time) | PK(family_id, child_id, target) — يتعايش العام والخاص لنفس التطبيق |
| `app_allowlist` | قائمة السماح الدائمة | UNIQUE(family_id, target) |
| `app_block_history` | سجل الأحداث (block/unblock/override/timeout) | family_id + created_at index |
| `usage_alert_settings` | عتبات تنبيه الاستخدام لكل تطبيق | UNIQUE(family_id, target) |

`sync_state` TEXT NOT NULL DEFAULT 'queued' في كل جدول — نفس نمط outbox honesty المتبع في م9. الترقية: `if (oldVersion < 17)` في `onUpgrade` + حراس `if (version >= 17)` في `_createSchema`.

### 3.2 المستودع والمزودين

`ApplicationPolicyRepository` (lib/data/application_policy_repository.dart) على نمط WebFilterRepository: دوال `savePolicy/resolvePolicies/allowlistEntries/addToAllowlist/removeFromAllowlist/recordBlockEvent/blockEvents/alertSettings/saveAlertSettings` مع factory `fromMap` ثابت. المزودين في `guardian_providers.dart`: `appPolicyRepositoryProvider` + مزودين عائليين `appPoliciesProvider.family`, `appAllowlistProvider.family`, `appBlockEventsProvider.family`, `usageAlertSettingsProvider.family` + جسر مزامنة عن بعد `ApplicationPolicyRemoteReader`/`WebPolicySyncApplier`-style + مزود جلب `pull`. جميع الجداول مدمجة أيضاً في عقد `firestore_contracts.dart` بأربع حالات `app.*`.

### 3.3 جسر Firestore (دون تغيير قواعد/مخطط موجود)

أربع حالات جديدة في `firestore_contracts.dart` (`app.*`) على نمط `web.*` و`child.usage.observed`: `app.policy` (حفظ السياسة عبر `FirestorePaths` موجود)، `app.allowlist`, `app.alert`, `app.history`. قارئ عن بعد (`FirestoreAppPolicyRemoteReader`) محروس بـ `GuardianFirebaseBootstrap.current.isReady` مع stub `_Unavailable` عند عدم جاهزية Firebase — نفس نمط FS-002. لا قواعد Firestore جديدة مكتوبة ولا مخطط جديد؛ المسارات تستخدم فروع المجموعات الحالية.

### 3.4 بيانات الاستخدام (معاد استخدامها — لا حقول جديدة)

AC-005/AC-006 يقرآن `child_usage_summaries` عبر `childDeviceRepository.usageForDeviceDay({deviceId, day})` الموجود أصلاً (v15/v16)، و`child.usage.observed` يملأ `target` بمسار حزمة التطبيق — كل البنية جاهزة منذ FS-002 وم9.

## 4. المواصفة الأمنية

1. **Fail-closed authorization:** كل شاشة تقرأ `FamilyRuntimeContext.can()` قبل أي عرض/إجراء؛ child-scoped AC-008 يتحقق أن `actor.id == childId` وإلا فوض Unauthorized.
2. **لا كشف معلومات عبر الأجهزة:** AC-002/AC-003 تقرأ تطبيقاً واحداً لكل طفل مع تحقق ملكية الطفل للـ familyId.
3. **Offline-first honesty:** كتابة السياسة تُدرج محلياً بحالة queued وتُسجّل أحداث block history حتى لو فشل sync — العرض لا يدّعي نجاحاً غير مزامن.
4. **لا قواعد Firebase معدلة:** الجسور الجديدة تكتب ضمن مجموعات موجودة بصلاحيات موجودة؛ لا widening للقواعد.
5. **خصوصية الطفل:** AC-008 يعرض فقط القواعد المطبقة على الطفل نفسه + CTA طلب استثناء عبر `reviewExceptionRequests`/`requestOwnException` الموجودين — لا وصول لسياسات الآخرين.

## 5. الترجمة والتنقل

مفاتيح `ac_*` مضافة لـ AR+EN معاً في `AppLocalizations` (~80 مفتاحاً: شاشات، حالات، أزرار، حالات فارغة، أحداث السجل). 8 مسارات جديدة في `app_router.dart` داخل ShellRoute، + بطاقة دخول فرعية في dashboard_screen.dart (مجموعة `appProtection` ثلاثية الأزرار: App Protection / History / Usage Limits) بنفس نمط مجموعات FS-001/FS-002 المضافة في CL-007.

## 6. الإثبات والفحوصات

- اختبار جديد `test/fs003_application_policy_test.dart`: **8/8 أخضر** — دورة حفظ/حل للسياسات، أفضلية تجاوز الطفل، حذف السياسة، أدلة التدقيق لكل عملية، دورة قائمة السماح (إضافة/إزالة)، حدود السجل وترتيبه الأحدث أولاً، إعدادات التنبيهات، ووجود جداول v17 ومؤشريها.
- التراجع الكامل: **282/282 أخضر** (274 أساسية + 8 FS-003).
- `flutter analyze`: **0 أخطاء**، 9 تحذيرات جميعها أساسية سابقة (لا تحذير جديد من FS-003).
- ملاحظة صادقة: `headless_validation_test.dart` يتجمد عند أول مسار `'/'` — وُجد أن هذا التجمد **موجود أيضاً على التفرع النظيف قبل FS-003** (d50e9c0)، أي أنه خلل أساسي سابق وليس من عمل FS-003؛ لم يُصلح هنا ليُعالج في مهمة منفصلة.
- لا دمج في master؛ كل شيء على `feature/design-system-integration`
- التحقق الحقيقي على الجهاز: يُنفّذ لاحقاً عبر Firebase Test Lab (مهمة منفصلة موثقة في FINAL_VALIDATION_REPORT.md)


## 7. ملحق تدقيق التماسك (19 أغسطس 2026)

بعد مراجعة التزام FS-001/FS-002/FS-003 بالمواصفات وترابط المنصة، اكتُشف وأُصلح:

| النتيجة | التفاصيل |
|---|---|
| صورتان غير مربوطين | `onboarding_alerts.png` و `onboarding_screen_time.png` كانتا في `assets/images/` دون استخدام — رُبطت الأولى بلوحة تنبيهات الموقع LO-010 والثانية بشاشة سياسات وقت الشاشة (عرض الوالد)، بنفس نمط ClipRRect ذو الزوايا 16 المستخدم في LO-008/WF-001. أصبحت جميع الصور الخمس في المنصة مستخدمة. |
| MASTER_SCREEN_INDEX.md | قسم FS-003 كان ما يزال PLANNED بمسارات مختلفة عن المنفذ — أُعيدت كتابته ليعكس المسارات الثمانية الفعلية مع ملاحظة توحيد النطاق (قواعد الطفل على `/apps/:familyId/:childId/rules` وتنبيهات الاستخدام على مستوى العائلة `/apps/:familyId/alerts`). |
| harness الهيدلس | لم يشمل FS-003 — أُضيفت 4 مسارات مرجعية (`/apps/:familyId`، `apps-list`، `allowlist`، `history`) جاهزة عند توفر بيئة اختبار حقيقية. |
| FS-001 / FS-002 | توافق كامل: جميع الشاشات LO-001..LO-015 وWF-001..WF-010 مسجلة في GoRouter وتطابق الفهرس الرئيسي. |
