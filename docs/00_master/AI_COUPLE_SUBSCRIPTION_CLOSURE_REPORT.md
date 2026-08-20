# تقرير إغلاق الدفعة: نظام Guardian AI (الطبقات التسع) + وحدة تناغم الزوجين (FS-013) + نظام الاشتراكات والدفع

**الفرع:** `feature/design-system-integration` — **حالة العمل:** مكتوب ومُتحقَّق منه، بانتظار أمر الحفظ في Git من المالك
**التاريخ:** 21 أغسطس 2026 — **الحالة:** اكتمال الدفعة + تحقق كامل

---

## 1. ملخص تنفيذي

أنجزت هذه الدفعة ثلاثة أنظمة كبرى دفعةً واحدة كما طُلب: **نظام Guardian AI ذي الطبقات التسع** (من تسجيل الأحداث إلى الشفافية)، و**وحدة تناغم الزوجين FS-013** (سبعة شاشات)، و**نظام الاشتراكات والصلاحيات Paywall** (أربع شاشات)، بالإضافة إلى إكمال **M9 — تتبع الموقع في الخلفية** الذي كان متبقياً من الدفعة السابقة. كل ما كُتب مكوَّد بالكامل (Domain + Data + Application + Presentation + Tests + Localization + Routing)، مربوط بقاعدة بيانات SQLite المحلية الإصدار 28، ومُحقَّق عبر تحليل ساكن نظيف (**0 أخطاء**) واختبارات انحدار كاملة (**432/432 خضراء**، منها 30 اختباراً جديداً كُتبت لهذه الدفعة).

> **إعلان الصدق (Honesty Banner):** نظام Guardian AI هو نظام **حتمي مبني على القواعد (Deterministic Rule-Based)** يعمل محلياً بالكامل — ليس ذكاءً اصطناعياً سحابياً ولا نموذج LLM. ونظام الاشتراكات هو **إدارة صلاحيات محلية فقط** — لا يوجد أي معالج دفع حقيقي مدمج في هذه المرحلة.

---

## 2. نظام Guardian AI — الطبقات التسع

### 2.1 البنية

بُني النظام كطبقات مترابطة من L1 إلى L9، تعمل بالكامل داخل الجهاز دون اتصال بالسحابة، وكلها موثقة في شاشات العرض بأنها قواعد حتمية شفافة:

| الطبقة | الاسم | الملف المنفذ | الوظيفة |
|---|---|---|---|
| L1 | Event Normalizer | `lib/domain/family_events.dart` | تحويل أحداث التطبيق إلى إشارات موحدة `NormalizedSignal` بأوزان ثابتة، مع رفض أي نوع حدث غير معروف إلى "unmapped" (لا يلفّق إشارات أبداً) |
| L2 | Risk Scoring | `lib/application/guardian_ai_engine.dart` | تقييم مخاطر كل طفل إلى أحد المستويات: `safe / watch / alert` بناءً على أوزان الإشارات |
| L3 | Behavior Profiling | engine | أنماط استخدام يومية لكل طفل (weekday × hour) مع نسبة انحراف عن خط الأساس |
| L4 | Health Scorecard | engine | بطاقة صحة العائلة من 0 إلى 100 عبر أبعاد متعددة (قواعد نشطة، توازن رقابي، تفاعل المكافآت…) |
| L5 | Weekly Insights | engine | خلاصة أسبوعية بأدلة ملموسة (Evidence) وتصنيف لمدى كفاية البيانات |
| L6 | Copilot Suggestions | engine | اقتراحات رقابية قابلة للتنفيذ بفترة سريان وأثر محسوب |
| L7 | Policy Proposals | engine | اقتراحات قواعد عائلية مع تبرير وتصويت عائلي |
| L8 | Transparency Report | engine + `ai_repository.dart` | تقرير شفاف بكل ما حُسب وكيف حُسب |
| L9 | Detections Console | engine + repo | سجل الكشوف المراجعة بموافقة الوالدين قبل أي إظهار |

### 2.2 سجل الأحداث وموافقة الخصوصية (L0)

أُسس **سجل أحداث العائلة** (`family_event_registry_repository.dart`) الذي يخزن `GuardianFeatureEvent` و`NormalizedSignal` و`AiConsentScope`. مبدأ التشغيل هنا "فشل مغلق" (Fail-Closed): **الفئات الحساسة (سلوكية / موقعية) مرفوضة افتراضياً** ولا تُفعَّل إلا بموافقة صريحة من الوالد المالك لكل فئة على حدة، وكل فئة تُكشف بشكل مستقل.

### 2.3 الشاشات (A-001 … A-007 — 7 شاشات)

| الشاشة | المسار |
|---|---|
| A-001 محور الرؤى Insights Hub | `/insights/:familyId` |
| A-002 تقييم مخاطر الطفل | `/insights/:familyId/risk` |
| A-006 اقتراحات المساعد (Copilot) | `/insights/:familyId/copilot` |
| A-007 ذكاء القواعد (Policy Intelligence) | `/insights/:familyId/policy` |
| A-010 وحدة الكشوف (Detections Console) | `/insights/:familyId/detections` |
| A-011 مركز الشفافية | `/insights/:familyId/transparency` |
| A-013 مركز خصوصية الذكاء الاصطناعي | `/insights/:familyId/privacy` |

كل شاشة تتحقق من الصلاحية عبر `FamilyRuntimeContext.can()` ولا تعيد تطبيق الأدوار محلياً، وتعرض الحالات الصادقة (تحميل / فارغ / خطأ / عدم اتصال) دون نجاح مزيف.

---

## 3. وحدة تناغم الزوجين (FS-013) — 7 شاشات

| الشاشة | المسار | الوظيفة |
|---|---|---|
| C-001 Hub الزوجين | `/couple/:familyId` | لوحة المشترك بين الزوجين |
| C-002 ربط الزوج/الزوجة | `/couple/:familyId/linking` | طلبات الربط المعلقة مع حالاتها |
| C-003 الاقتراحات المشتركة | `/couple/:familyId/proposals` | اقتراحات بتدفق حياة كامل (معلَّق ← مقبول/مرفوض/منتهي) |
| C-004 اقتراح جديد | `/couple/:familyId/proposals/new` | نموذج إنشاء اقتراح |
| C-005 الروتينات المشتركة | `/couple/:familyId/routines` | CRUD كامل للروتينات |
| C-006 المسؤوليات | `/couple/:familyId/responsibilities` | تفويض المسؤوليات لأحد الزوجين |
| C-007 التسليمات (Handovers) | `/couple/:familyId/handovers` | طلبات تسليم وختم زمني عند الإكمال |

النماذج في `lib/domain/couple_harmony.dart` والمستودع في `lib/data/couple_repository.dart` كلها مدعومة بجداول SQLite خاصة (`couple_linking`, `couple_proposals`, `couple_routines`, `couple_responsibilities`, `couple_handovers`) مع عزل كامل بين العائلات.

---

## 4. نظام الاشتراكات والدفع (Paywall) — 4 شاشات

| الشاشة | المسار | الوظيفة |
|---|---|---|
| ST-001 الرئيسية | `/subscription/:familyId` | حالة الاشتراك ومخطط الخطة (Tier) مع Banner الصدق |
| ST-002 الترقية | `/subscription/:familyId/upgrade` | اختيار الخطة |
| ST-003 الصلاحيات | `/subscription/:familyId/entitlements` | الجدول الكامل للصلاحيات (Entitlement) |
| ST-004 العدادات | `/subscription/:familyId/meters` | عدادات الاستخدام مقابل الحد (`limit_`) |

النظام يُدار محلياً بالكامل: `Entitlement` (بدون حقل id — المفتاح مركب من family + feature)، `UsageMeter` يخزن الحد في عمود `limit_` الآمن نحو كلمات SQL المحجوزة، و`BillingRecord` كمسار تدقيق **إضافة فقط (Append-only)** مرتب زمنياً تنازلياً. لا يوجد معالج دفع حقيقي، والتعريفات (`SubscriptionPlanCaps`) تحدد السقف (مثل عدد الأطفال) والقدرات (AI / Couple / تصدير PDF / تتبع الخلفية) لكل Tier.

---

## 5. قاعدة البيانات — الترحيلات v25 → v28

رفعت النسخة من 27 إلى **28** مع أربع ترحيلات جديدة مُطبقة في **كلا** مساري إنشاء قاعدة جديدة (`_createSchema`) والترحيل التدريجي (`_upgradeSchema`):

| الترحيل | الجداول |
|---|---|
| v25 — سجل الأحداث | `family_events`, `normalized_signals`, `ai_consent_scopes`, `source_event_tracking` |
| v26 — مخرجات AI | `ai_risk_states`, `ai_behavior_profiles`, `ai_insights`, `ai_detections`, `ai_copilot_suggestions`, `ai_policy_proposals` |
| v27 — تناغم الزوجين | `couple_linking`, `couple_proposals`, `couple_routines`, `couple_responsibilities`, `couple_handovers` |
| v28 — الاشتراكات | `subscription_entitlements`, `subscription_usage_limits`, `billing_records` |

كل ترحيل **idempotent** (إنشاء الجداول بـ `IF NOT EXISTS`)، وجميع الجداول تتضمن `created_at` ومفاتيح أجنبية نحو `families(id)` مع عزل بيانات بين العائلات مُتحقَّق منه بالاختبارات. **تنبيه أمانة:** تم خلال هذه الدفعة إعادة بناء كتل v25–v28 في مسار `_createSchema` بعد اكتشاف أن الجداول الحديثة كانت موجودة في مسار الترحيل التدريجي فقط دون مسار الإنشاء الجديد — وهي فجوة كانت ستسقط إنشاء قاعدة جديدة على أجهزة لم يسبقها عمل سابق.

---

## 6. الصلاحيات الجديدة

أُضيفت 5 قيم جديدة إلى `FamilyPermission` مع منحها للأدوار في `family_authorization.dart`:

| الصلاحية | الوصف |
|---|---|
| `viewAiInsights` | الاطلاع على رؤى Guardian AI |
| `manageAiConsent` | إدارة موافقات فئات البيانات للذكاء الاصطناعي |
| `manageCoupleDecisions` | اتخاذ قرارات الاقتراحات المشتركة |
| `viewCoupleInsights` | الاطلاع على لوحات تناغم الزوجين |
| `manageSubscription` | إدارة الاشتراك والصلاحيات |

---

## 7. التوطين (l10n)

أُضيفت **مفاتيح عربية وإنجليزية** لمجموعات: `aiInsights/aiRisk/aiBehavior/aiHealth/aiWeekly/aiCopilot/aiPolicy/aiTransparency/aiPrivacy/aiDetection/aiExplanation/aiConsent`، و`coupleHub/coupleProposal/coupleRoutine/coupleHandover/coupleLinking/coupleResponsibility/coupleDone/couplePending`، و`subscriptionStatus/subscriptionTier/subscriptionMeters/subscriptionBilling…` بما يشمل `yes/no`. التحقق الآلي أكد أن **كل المفاتيح الـ 212 المستخدمة** في الشاشات الجديدة موجودة في الخريطة العربية والإنجليزية معاً، مع إعادة تنفيذ `fix_l10n_lines.py` بعد الإدراج.

---

## 8. الاختبارات

كُتبت ثلاث سويتات جديدة مبنية على نمط `openTestDatabase()` الحقيقي ضد مخطط SQLite الفعلي (نفس نمط `fs011_family_rules_test.dart`):

| الملف | الاختبارات | التغطية |
|---|---|---|
| `test/ai_guardian_test.dart` | 14 | EventNormalizer (شامل ومرفوض)، AiConsentScope (فشل مغلق + copyWith)، محرك حتمي فارغ = `safe`، Scorecard فارغ = خط أساس، تصعيد SOS حتمي، round-trip JSON لنماذج L2/L6، جولات DB للـ repository (أحداث + إشارات + كشوف + مراجعة + مسح عائلي كامل) |
| `test/fs013_couple_harmony_test.dart` | 8 | نماذج الزوجين، دورة حياة الاقتراح (معلَّق ← مقبول)، CRUD الروتينات، تفويض المسؤوليات، ختم التسليمات، الاقتراحات المنتهية تُحل بصدق، وعزل العائلات |
| `test/st_subscription_test.dart` | 8 | Entitlement بلا id، عمود `limit_` الآمن وتفضيله على `limit` القديم، بوابات الميزات (ممنوح/غير ممنوح)، العدادات، التدقيق الملحق-فقط، وعزل العائلات |

**النتيجة النهائية:**

| الفحص | النتيجة |
|---|---|
| `flutter analyze lib/` | **0 أخطاء** |
| اختبارات الانحدار الكاملة (56 ملفاً) | **432/432 خضراء** (+30 اختباراً جديداً) |
| استثناء مُتعارف عليه | `headless_validation_test.dart` يعلق مسبقاً ويستبعد من التشغيل (موثق سابقاً — لا يعادل اختبار جهاز حقيقي) |

---

## 9. M9 — تتبع الموقع في الخلفية (إكمال من دفعة سابقة)

أُنجز أيضاً في هذه الدفعة: `LocationTrackingService.kt` + `BootReceiver.kt` + `MainActivity.kt` على أندرويد، و`background_location_service.dart` + `location_repository.dart` (تقييم التقاطعات) + `android_location_tracking_adapter.dart` على Dart، مع بطاقة التتبع في شاشات الموقع و22 اختباراً جديداً (`test/fs_background_location_test.dart`) وتقرير الإغلاق السابق `BACKGROUND_LOCATION_CLOSURE_REPORT.md`.

---

## 10. الترابط المعماري

كل الأنظمة الثلاثة موصولة بمزودات Riverpod في `lib/application/guardian_providers.dart` (مزودات AI والزوجين والاشتراكات وM9)، ومسارات GoRouter في `lib/presentation/router/app_router.dart`، ومفاتيح l10n موحدة، ونفس نظام التصميم (GuardianTokens navy/teal، بطاقات Material 3 بزوايا 16، خط Cairo، دعم RTL كامل)، وكل الحالات الصادقة (تحميل/فارغ/خطأ/عدم اتصال) مُطبقة دون نجاح مزيف.

---

## 11. ما تبقى بعد هذه الدفعة

| النظام الفرعي | الشاشات التقريبية |
|---|---|
| FS-010 الدردشة العائلية المؤقتة (Ephemeral Family Chat) | 4 (CH-001…CH-004) — بانتظار بوابة المرحلة M5 membership |
| FS-012 وضع الطفل وجهاز الطفل | ~5 |
| FS-014 تقويم العائلة | ~5 |
| FS-016 الإعدادات والأمان | ~8 |

**لم يُنفَّذ أي Commit في هذه الدفعة** — جميع الملفات معدلة/جديدة في شجرة العمل بانتظار تأكيد الحفظ بعبارة "احفظ في القت" كما نص عقد التشغيل.

---

*أُعد بواسطة Manus AI — Guardian Eye Pro*
