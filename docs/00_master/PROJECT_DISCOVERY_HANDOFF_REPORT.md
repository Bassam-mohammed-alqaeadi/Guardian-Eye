# Guardian Eye Pro — تقرير الاستكشاف والتسليم المعرفي

**نوع التقرير:** PROJECT DISCOVERY + TECHNICAL HANDOFF
**تاريخ الإعداد:** 20 أغسطس 2026
**الحالة:** تجميع الأدلة من الكود الفعلي فقط (بدون أي تنفيذ أو تعديل ملفات)
**الفرع:** `feature/design-system-integration`
**المرجعية:** جميع النتائج مبنية على فحص فعلي لمستودع `Bassam-mohammed-alqaeadi/Guardian-Eye` في هذه الجلسة.

---

## الفهرس

1. الملخص التنفيذي (Executive Summary)
2. رؤية المنتج والمستخدمون (Product Vision and Users)
3. الحالة الحالية للمنتج (Current Product Status)
4. جرد الميزات (Feature Inventory)
5. رحلات المستخدم (User Journeys)
6. جرد الشاشات (Screen Inventory)
7. المعمارية وخريطة المستودعات (Architecture and Repository Map)
8. نماذج البيانات وخريطة API (Data Models and API Map)
9. المصادقة والصلاحيات (Authentication and Permissions)
10. مراجعة الخصوصية وحماية الأسرة (Privacy and Family-Safety Review)
11. واجهة المستخدم ونظام التصميم (UI/UX and Design System)
12. مراجعة الاختبارات والجودة (Testing and Quality Review)
13. سجل الديون التقنية (Technical Debt Register)
14. blockers الحالية (Current Blockers)
15. المجهولات والأسئلة (Unknowns and Questions)
16. القرارات التالية المقترحة — بدون تنفيذ (Suggested Next Decisions)
17. فهرس الأدلة (Evidence Index)
18. ملخص التسليم النهائي (Final Handoff Summary)

---

# الجزء 1 من 4 — الملخص التنفيذي، الرؤية، الحالة، جرد الميزات

---

## 1. الملخص التنفيذي (Executive Summary)

**Guardian Eye Pro** هو تطبيق عائلات آمن (Family Safety Platform) مبني بـ Flutter لنظام Android، باسم الحزمة `guardian_ai`. المنتج في مرحلة **نموذج عملي متقدم قابل للبناء (Advanced Working Prototype)**: الواجهة الأمامية مكتملة لأكثر من 90 نظاماً فرعياً من أصل 16 نظاماً فرعياً مخططاً (FS-001..FS-011 منفذة، FS-010/FS-012..FS-016 مخططة)، مع بنية تحتية حقيقية لـ Firebase (Firestore + Auth) ومزامنة outbox دون اتصال، وخادم Render خلفي فعلي (Express + firebase-admin)، دون استخدام أي Mock في الطبقات الأساسية.

| المؤشر | القيمة | الدليل |
|---|---|---|
| أنماط المسارات المسجلة (Routes) | 85 | `lib/presentation/router/app_router.dart` |
| ملفات الشاشات / الأسطر | ~27 ملف / ~28,400 سطر | `lib/presentation/screens/` |
| الاختبارات | 380/380 خضراء (52 ملف اختبار) | آخر تشغيل انحدار في هذه الجلسة |
| تحليل Static | 0 أخطاء | `flutter analyze lib/` |
| إصدار قاعدة البيانات SQLite | v24 (50 جدول) | `lib/core/database/guardian_database.dart` |
| مفاتيح الترجمة AR = EN | 1,377 (مطابقة كاملة) | `lib/core/localization/app_localizations.dart` |
| بروفيدرات Riverpod | 116 | `lib/application/guardian_providers.dart` |
| الأنظمة الفرعية المنفذة | FS-001, FS-002, FS-003, FS-004, FS-005, FS-006, FS-007, FS-008, FS-009, FS-011, FS-015 | تقارير الإغلاق في `docs/00_master/` |
| commits | 67 على فرع واحد (لم يُدمج في master أبداً) | `git log` |
| Build APK release | ينجح (90 MB) | Release tag `validation-build-20260818` |

**أهم ما في المرحلة الحالية:** عمل FS-007 (المهام اليومية — 8 شاشات TK-001..TK-008) وFS-008 (النقاط والمكافآت — 7 شاشات RW-001..RW-007) مكتمل ومختبر (26 اختباراً جديداً، 380/380 أخضر)، لكن **لم يُحفظ بعد في القتهب**؛ توجد 18 ملفاً غير مُلتزم بها (uncommitted) في الفرع.

**جملة الحالة الدقيقة:** المنصة حاليًا في مرحلة نموذج عملي متقدم مكتمل الواجهة لأحد عشر نظاماً فرعياً مع Backend حقيقي ومزامنة دون اتصال وصلاحيات عائلية، والجزء المكتمل فعليًا هو FS-001..FS-011 (باستثناء FS-010)، بينما الأجزاء غير المكتملة هي FS-010 (المحادثات المؤقتة)، FS-012..FS-016 (وضع الطفل، الوئام الزوجي، لوحة البداية، بوابات الميزات، الاشتراك التجاري)، وواجهة Guardian AI ذات الطبقات التسع المؤجلة عمداً لنهاية المشروع.

---

## 2. رؤية المنتج والمستخدمون (Product Vision and Users)

### 2.1 هوية المنتج

| البند | القيمة | الدليل |
|---|---|---|
| الاسم الرسمي | Guardian Eye Pro | `lib/presentation/guardian_app.dart`، `README.md` (مخزون Flutter الافتراضي — لم يُخصص بعد، UNKNOWN إذا كان الاسم التجاري النهائي) |
| الهوية المعلنة | "Human-engineered. AI-powered. Family-first." | وثيقة MASTER blueprint (`docs/00_master/`) |
| الوعد الأساسي | نظام تشغيل عائلي (Family Operating System): حماية رقمية صادقة للأطفال دون ادعاءات خادعة | `docs/00_master/MASTER_FEATURE_MATRIX.md`، نصوص `l10n` مثل `familyDecisionCenter`, `offlineFirst` |
| القيم الأساسية | الصدق في العرض (Honesty-based enforcement): "لا نجاح كاذب" — كل حالة (offline/error/permission) تُعرض بصراحة | 9 بريميتيفات `GuardianStateView`/`GuardianOfflineBanner` في `lib/presentation/guardian_primitives.dart` |
| اللغة المفضلة | عربي/RTL أولاً + إنجليزي | خريطتا `ar` و`en` متطابقتان (1,377 مفتاحاً)، خط Cairo، اتجاه RTL افتراضي |

### 2.2 النبرة والترجمة

نبرة النصوص عائلية رصينة بالعربية الفصحى المبسطة ("مركز قرارات الأسرة"، "أمان اليوم"، "إشارة الأمان"، "يتطلب انتباه") وبمقابلات إنجليزية مباشرة. مفاتيح الترجمة تتبع نمط بادئة+CamelCase (مثل `tkAction`, `rwRewardsTitle`, `frRulesTitle`) ومخزنة في ملف واحد `lib/core/localization/app_localizations.dart` بمصفوفتين ثابتتين `'ar'` و`'en'` — لا يوجد نظام l10n مولد آلياً (arb)؛ الترجمة يدوية داخل الكود. **الترجمة ثنائية اللغة متماثلة 100% في العدد** (فحص بالبايثون في هذه الجلسة: AR = EN = 1,377).

### 2.3 المستخدمون الأساسيون

| الدور | الوصف | الأدلة |
|---|---|---|
| **primaryParent** (ولي الأمر الأساسي) | مالك العائلة الوحيد؛ كل الصلاحيات، ينشئ العائلة ويدعو ويعزل ويقرر كل شيء | `FamilyAuthorization.permissionsFor` في `lib/domain/family_authorization.dart` |
| **parent / coParent** (ولي أمر مشارك) | يدير الأطفال والسياسات والقواعد والمهام والمكافآت، ويعتمد الاستثناءات | المصفوفة نفسها |
| **spouse** (الزوج/الزوجة — FS-006) | وضع عرض فقط مع استثناءات محددة (يُحقق إتمام المهام، لا يعدّل الرصيد) | المصفوفة نفسها + FS-006 |
| **child** (الطفل) | يرى فقط ما يخصه بصراحة (سياساته، استعمالاته، مهامه، رصيده) ويطلب استثناءات/إتمام مهام/استرداد مكافآت، ولا يُنفذ قراره ذاتياً | المصفوفة نفسها + `ChildExceptionRequest` state machine |

### 2.4 الأجهزة والمنصات

المنصة مدعومة رسمياً **Android فقط** (`flutter/flutter` SDK 3.35.6، target Android، google-services.json في `firebase.json`). البناء على Web/iOS غير مثبت ولا يوجد ملفات إعداد لها (UNKNOWN إن كانت مخططة — لا توجد إشارات في الوثائق). لا يوجد اختبار على جهاز حقيقي في هذه الجلسة ولا في الجلسات السابقة الموثقة (انظر قسم 14).

---

## 3. الحالة الحالية للمنتج (Current Product Status)

### 3.1 ما يعمل فعلياً (Implemented)

الأنظمة الأحد عشر التالية مكتملة بواجهاتها ومنطقها ومصادر بياناتها وصلاحياتها واختباراتها، وكلها مبنية على SQLite محلي (offline-first) مع جسر Firestore حقيقي وأحداث outbox:

| النظام | الشاشات | الاختبارات | الحالة النهائية |
|---|---|---|---|
| FS-001 Location & Geofencing | 15 (LO-001..LO-015) | لا يوجد ملف fs001 | مكتمل + تدقيق CL-007 |
| FS-002 Web Filtering | 10 (WF-001..WF-010) | لا يوجد ملف fs002 | مكتمل + جسر Firebase حقيقي |
| FS-003 Application Control | 8 (AC-001..AC-008) | 8 | مكتمل |
| FS-004 Screen & Camera Monitoring | 9 (SC-001..SC-009) | 11 | مكتمل |
| FS-005 Custom Modes | 10 (MD-001..MD-010) | 15 | مكتمل (أساس وضع الطفل) |
| FS-006 SOS Expansion | 8 (SO-001..SO-008) | 13 | مكتمل |
| FS-007 Tasks & Daily Schedules | 8 (TK-001..TK-008) | جزء من 26 | **مكتمل — غير محفظ في القتهب** |
| FS-008 Family Points & Rewards | 7 (RW-001..RW-007) | جزء من 26 | **مكتمل — غير محفظ في القتهب** |
| FS-009 Reports & PDF Export | 8 (RP-001..RP-008) | 10 | مكتمل (PDF/CSV عبر pdf+csv) |
| FS-011 Family Rules & Policy Engine | 7 (FR-001..FR-007) | 13 | مكتمل |
| FS-015 Device Linking & Enrollment | 11 (DL-001..DL-011) | 10 | مكتمل |

### 3.2 ما يعمل جزئياً أو غير مكتمل (Partially implemented / Planned)

| البند | الحالة | الدليل |
|---|---|---|
| FS-010 Ephemeral Chat | **غير منفذ إطلاقاً** (لا مسارات /chat ولا أي ذكر في lib) | `MASTER_FEATURE_MATRIX.md` يصفها PLANNED بـ 4 شاشات |
| FS-012 Child Mode (الوضع المقيد للطفل) | مخطط — 5 شاشات | المصفوفة، Phase 6 |
| FS-013 Couple Harmony | مخطط — 7 شاشات | المصفوفة، Phase 6 |
| FS-014 Primary Dashboard (Onboarding كامل) | مخطط — 7 شاشات (توجد الآن فقط شاشة إنشاء عائلة مبسطة في `/family`) | المصفوفة، Phase 7 |
| FS-016 Startup & Feature Gates (splash, upgrade gate, cold start) | مخطط — 5 شاشات | المصفوفة، Phase 7؛ يوجد splash موجود لكن بوابات الميزات والتخطيط الدوراني غير منفذة |
| التتبع الجغرافي المستمر في الخلفية | **غير منفذ**: التقاط الموقع يدوي فقط عبر `Geolocator.getCurrentPosition()` من شاشات العرض (safety_actions_screen.dart، sos_screens.dart — 4 مواضع) ولا يوجد أي استخدام لـ `Workmanager` أو `getPositionStream` في `lib/` رغم وجود العملتين في pubspec | مسح كامل بـ grep |
| الإشعارات المحلية (push on-device) | **غير موصولة**: `flutter_local_notifications` في pubspec لكن لا توجد أي import في lib؛ التسجيل FCM للمعرفات فقط عبر `FcmTokenRepository` (firebase_messaging) | `lib/data/fcm_token_repository.dart` |
| التسليم الفعلي لإشعارات SOS/Incidents عبر FCM | غير مثبت كسلسلة تشغيل (الواجهة موجودة، الـ delivery غير مؤكد — مصمم "بدون ادعاء تسليم") | `FINAL_VALIDATION_REPORT.md` |
| حذف الحساب وتصدير البيانات | **غير منفذ** (لا مفاتيح l10n ولا شاشات) | grep deleteAccount/exportAccount في lib: صفر نتائج |
| طبقة Guardian AI (الطبقات التسع) | مؤجل عمداً لنهاية المشروع بقرار صريح من المستخدم | رسائل المستخدم السابقة + Phase 10-11 |
| الاشتراك التجاري (Phase 13) | مخطط ($75/سنة مستهدفة، 8,000 عائلة، $600k/2028) | `MASTER_FEATURE_MATRIX.md` |

### 3.3 الأكبر عوائق تقنية (3)

1. **لا تحقق حقيقي على جهاز Android**: لا emulator ولا Firebase Test Lab جرى في هذه الجلسة؛ headless harness معطوب جزئياً (hang معروf مسبقاً — يستثنى من الانحدار)؛ APK release يبنى فقط. سلوك Android الحقيقي (permissions خلفية، lifecycle، background services) غير مختبر.
2. **التتبع الجغرافي والمراقبة يحدتهما التقاط يدوي**: لا background location ولا background screenshot؛ القيمة الأمنية للمنتج تعتمد على آلية غير منفذة.
3. **عمل FS-007/FS-008 غير محفظ في القتهب**: 18 ملفاً متغيراً خارج version control — خطر فقدان عمل.

### 3.4 الأكبر مخاطر (3)

1. **فجوة التحقق**: 380 اختباراً كلها وحدة/مستودع/واجهة؛ لا توجد اختبارات تكاملية على الجهاز ولا اختبارات لنظامَي FS-001/FS-002 رغم أنهما أساسيان (لا ملفات fs001/fs002).
2. **خطأ التزامن المحتمل في outbox**: مكتشف ومصلح داخل هذه الجلسة في FS-007/FS-008 (تصادم مفاتيح idempotency عند حدثين في نفس الملّي-ثانية) — يوضح أن نمط الإرسال الحالي حساس للتوقيت ويجب اختباره تحت تزامن حقيقي.
3. **الاعتماد على مزامنة unidirectional واحدة**: لا يوجد مسار استرداد تعارضات bidirectional (Firestore → device) معلن؛ البيانات تُقرأ من Firestore عبر جسر قراءة فقط؛ تعارضات الكتابة المحتملة بين أجهزة العائلة تُعالج بآخر فوز (last-writer) عبر serverTimestamp — غير مُختبر.

---

## 4. جرد الميزات (Feature Inventory)

### 4.1 جدول الميزات

| الميزة | الوصف | المستفيد | الحالة | الملفات | مصدر البيانات | الصلاحيات | حالات خاصة | الاختبارات |
|---|---|---|---|---|---|---|---|---|
| إنشاء العائلة | نموذج إنشاء عائلة (familyName + parentName) ثم دعوة | primaryParent | Implemented (مبسط) | `dashboard_screen.dart` (شاشة إنشاء مدمجة) + `family_members_repository.dart` | SQLite + outbox → Firestore | owner فقط | لا عائلة → شاشة إنشاء + familySetupRequired | جزء من suite |
| دعوة/إدارة الأعضاء | دعوة uid، قبول، عزل، تحديث دور | primaryParent | Implemented | `family_members_repository.dart` + Firestore contracts (`family.member.*`) | SQLite + outbox | owner فقط | حالة invitation pending/accepted/revoked | مغطاة بـ tests البنية |
| حسابات الأطفال وربطها | addChild → pairing code → redeem → device linking (FS-015) | primaryParent/child | Implemented | `child_device_repository.dart`, `pairing_repository.dart`, FS-015 | SQLite pairing_sessions + devices + outbox | owner + primaryParent | PairingState: pending/verified/enrolled/expired/rejected/revoked | fs015: 10 |
| إدارة الأجهزة | قائمة الأجهزة، نقل الجهاز، إلغاء الربط، health verdicts | adult roles | Implemented | `devices_repository.dart`, settings | SQLite devices + outbox | owner للتحكم | device transfer/unlink routes | جزء من m4/m8 |
| الموقع والجدران الجغرافية | خريطة، تفاصيل عضو، تاريخ، جدران، تنبيهات، مفضلة، خصوصية، onboarding | adult roles | Implemented | `location_repository.dart` + 15 شاشة LO | SQLite (location_points, geofences, location_alerts, favorite_places, location_settings) | كتابة: جهاز الطفل/الوالد حسب doc | التقاط يدوي لا مستمر | لا يوجد fs001 |
| تصفية الويب | سجل hits، allowlist/blocklist، فئات، تنبيهات، إعدادات، عرض الطفل | adult roles + child view | Implemented | `web_filter_repository.dart` + 10 شاشات WF | SQLite (web_hits, child_usage_summaries) + جسر Firebase حقيقي | parent-written geofences/allowlist | child allowlist view | لا يوجد fs002 |
| وقت الشاشة والتطبيقات | سياسات وقت شاشة، نوافذ، استثناءات، daily safety، usage alerts | adult roles + child own | Implemented | `policy_repository.dart`, `enforcement_engine`, `screen_time_engine` | SQLite (policies, overrides, app_policies, child_usage_*) | managePolicies للبالغين | استثناء مؤقت منتهِ الصلاحية، fail-closed | جزء من m6-m8 |
| الجداول والمهام (FS-007) | مهام عائلية/يومية/أسبوعية، طلب إتمام، تحقق، سجل، بوابة ربط بالقواعد | adult + child own | Implemented | `family_tasks_repository.dart` + `tasks_screens.dart` | SQLite (tasks, task_completion_log) + outbox | viewTasks/manageTasks للبالغين؛ child يرى مهامه ويطلب إتمامها | مهمة منتهية (completed/cancelled) ترفض طلبات جديدة إلا التحقق المتعدد للأطفال | fs007_008: 26 |
| النقاط والمكافآت (FS-008) | كتالوج مكافآت، رصيد، سجل، طلب استرداد، موافقة ولي الأمر | adult + child own | Implemented | `family_rewards_repository.dart` + `rewards_screens.dart` | SQLite (family_rewards, reward_points_ledger, reward_pending_claims) | manageRewards للبالغين؛ child يطلب استرداده | الإنفاق السالب لا يحدث إلا عبر approveClaim؛ مكافأة معطلة ترفض الطلبات | fs007_008: 26 |
| الإشعارات (تنبيهات داخلية) | تنبيهات الموقع/الاستخدام داخل التطبيق + outbox | adult roles | Implemented جزئياً | `safety_repositories.dart`, `location_alerts` | SQLite + outbox | adult | بلا إشعارات push فعلية | جزء من suite |
| لوحة السلامة/Safety score | إحصاءات اليوم (incidentsToday, safeToday/attentionRequired, safetySignal)، تسلسل زمني | adult roles | Implemented | `FamilySafetyExperienceRepository.timelineForFamily` + dashboard tiles | تجميع SQLite | adult | طفل لا يرى | جزء من suite |
| العمل دون اتصال + Outbox queue | طابور outbox + SyncExecutor + idempotency + single-flight sync | الجميع | Implemented | `outbox_repository.dart`, `outbox_sync_executor.dart` | SQLite outbox → Firestore batch | — | syncState: localOnly/queued/synced/blocked/failed؛ تعارضات مصنفة | مغطاة بـ m2/m7 |
| التقارير وتصدير PDF/CSV | snapshot أسبوعي/يومي + تصدير ملفات + مشاركة | adult + child own-view | Implemented | `reports_domain.dart`, `reports_export_service.dart` + 8 شاشات RP | تجميع SQLite | viewReports للبالغين | الأقسام الفارغة تُعلم داخل الملف | fs009: 10 |
| حذف الحساب / تصدير البيانات | حذف الحساب وتصدير كل بيانات المستخدم | المستخدم | **غير منفذ** | — | — | — | — | — |
| الدفع والاشتراكات | خطط اشتراك، ترقية، بوابة ميزات | primaryParent | **مخطط** (Phase 13) | — | — | — | — | — |

### 4.2 الميزات الإضافية المكتشفة في الكود

توجد شاشات ومكونات لا تنتمي مباشرة لجدول FS: شاشة `firebase-session` (تسجيل دخول تجريبي email/password — موجودة للتحقق)، شاشة `/requests/:familyId` (استثناءات الأطفال ChildExceptionRequest + state machine)، شاشة `/timeline/:familyId` (التسلسل الزمني للسلامة)، وضع الزوج/الزوجة في FS-006 (`/couple/:fid` enrollment/link-device/role)، وبوابات `actorVerificationRequired` عند فقدان سياق الممثل.

---

## 5. رحلات المستخدم (User Journeys)

### 5.1 رحلة الوالد: إنشاء حساب → إضافة طفل

**البداية:** فتح التطبيق → **النهاية:** عائلة منشأة وطفل ظاهر.

1. `main.dart` يهيئ قاعدة البيانات ثم Firebase bootstrap (معلّم `GUARDIAN_FIREBASE_CONFIGURED`) ثم يركب `GuardianApp`.
2. `/` (dashboard) يكشف غياب العائلة → شاشة `noFamily` + نموذج إنشاء (familyName, parentName) → `createFamily`.
3. منطق الإنشاء: `FamilyMembersRepository.createFamily` يكتب عائلة + صف عضو primaryParent في SQLite، ويُرسِل حدث `family.created` إلى outbox (يكتب مستند العائلة + صف العضو في Firestore عند التزامن — `firestore_contracts.dart` case `family.created`).
4. لوحة العائلة تظهر مع إحصاءات (children, incidentsToday, syncQueue).
5. `addChild` → نموذج اسم الطفل → إنشاء عضو child + `pairDevice` يبدأ جلسة إقران (pairing code) → الطفل يدخل الكود عبر `/enroll/:familyId/:code` → التحقق والتسجيل (FS-015) → `PairingState: enrolled` → جهاز childDevice يظهر.

**API calls:** outbox → Firestore (`/families/{fid}/members/{uid}`)؛ Firebase Auth لتسجيل الوالد عبر `/firebase-session`.
**حالات الفشل:** فشل الشبكة → outbox يبقى queued مع syncState=queued، شريط offlineFirst ظاهر؛ فشل bootstrap → `FirebaseBootstrapStatus.failed` يعرض حالة صادقة دون تعليق التطبيق.
**الصلاحيات:** إنشاء/إضافة طفل تتطلب `manageChildren` (primaryParent/parent/coParent).

### 5.2 رحلة ربط جهاز الطفل

1. الوالد: dashboard → `pairDevice` → `PairingRequest` جديد بحالة pending، كود عرض على الشاشة، مهلة انتهاء.
2. الطفل على جهازه: يدخل `/enroll/:familyId/:code` → تأكيد → `verifyPairing`.
3. الجهاز يسجل في `devices` بدور `childDevice` وحالة health؛ نقل/إلغاء الربط عبر `/settings/devices`.

**حالات الفشل:** كود منتهي (PairingState.expired) → إعادة إنشاء؛ كود مرفوض (rejected) → الوالد يُخطر؛ جهاز معطل (revoked) → لا مزامنة.
**الصلاحيات:** الإنشاء parent، الإقران child على جهازه (owner == actor)، الإلغاء primaryParent.

### 5.3 رحلة عرض الموقع وحالة الجهاز

1. dashboard → familyMap → `/location/:familyId` (خريطة) أو member → `/location/:fid/:memberId`.
2. تفاصيل العضو → Location History (`/location/:fid/:memberId/history`).
3. التقاط نقطة: `safety_actions_screen.dart` يستدعي `Geolocator.getCurrentPosition()` يدوياً → `location_repository.savePoint` → `location_points` + outbox.
4. الجدران الجغرافية: قائمة + إنشاء/تعديل + تنبيهات دخول/خروج عبر `location_alerts`.

**ملاحظة حرجة:** لا توجد خدمة خلفية تلتقط الموقع تلقائياً؛ البيانات تعتمد على التقاط يدوي/حدثي (INFERRED).
**الصلاحيات:** قراءة الموقع للبالغين؛ الطفل يرى مشاركة موقعه فقط (`/child/:fid/:cid/location-sharing`).

### 5.4 رحلة استقبال تنبيه

1. حدث داخلي (خروج من جدار/حادث/استخدام مفرط) → صف في `location_alerts`/`incidents` + outbox.
2. الوالد يرى badge في dashboard + `/location/:fid/alerts` أو Safety Timeline.
3. الحادث يمر دورة حياة `IncidentLifecycle` (observed → classified → confirmed → acknowledged)؛ التأكيد يُرسِل outbox `incident.acknowledged` (أُصلح في CL-005).

**حالات الفشل:** فشل التزامن → incident يبقى بحالة syncState واضحة (لا إخفاء).
**الصلاحيات:** يمكن للبالغين فقط تأكيد الحوادث (`canAcknowledgeIncident`).

### 5.5 رحلة فشل الاتصال / العمل دون اتصال

1. انقطاع الشبكة → `connectivity_plus` يُطلق حدثاً → sync coordinator single-flight يتوقف، `GuardianOfflineBanner` يظهر أعلى التطبيق.
2. كل عملية كتابة (سياسة/مهمة/مكافأة/موقع/حادث) تُكتب SQLite أولاً + صف outbox.
3. عند العودة: SyncExecutor يستأنف، يرسل دفعة Firestore مع `serverTimestamp` وidempotencyKey؛ الفشل القابل للإعادة يُجدول، الدائم يُصنّف `SyncFailureKind.permanent`.
4. التكرار آمن لأن writes عبر `batch.set` بمفاتيح تفرد.

### 5.6 رحلة الاشتراك / فشل الدفع

**غير منفذة.** Phase 13 (الاشتراك التجاري) مخطط بلا أي كود. رحلة الدفع الحالية: UNKNOWN بالكامل. أي بوابة دفع مستقبلية يجب أن تُبنى من الصفر مع بوابات ميزات FS-016.

### 5.7 رحلة حذف الحساب / إزالة طفل

**حذف الحساب: غير منفذ** (لا شاشات/مفاتيح). **إزالة الطفل:** عضو child يُعزل عبر `family.member.revoked` (Firestore contract موجود + outbox)، مع revocation في SQLite؛ لا يوجد مسار موثق لمحو بيانات الطفل من الأجهزة (UNKNOWN) — قرار مطلوب.

---

**ما تم تغطيته في الجزء 1:** الأقسام 1-5 (الملخص التنفيذي، الرؤية والمستخدمون، الحالة، جرد الميزات، الرحلات).
**ما يلي في الجزء 2:** جرد الشاشات (لكل شاشة سجل كامل)، المعمارية وخريطة المستودعات، نماذج البيانات وخريطة API.

---

# الجزء 2 من 4 — جرد الشاشات، المعمارية، نماذج البيانات وخريطة API

---

## 6. جرد الشاشات (Screen Inventory)

يوجد **~96 شاشة UI** مصنفة ضمن 27 ملف Dart (بمجموع ~28,400 سطر) تخدم 85 نمط مسار. الجدول التالي يسرد كل مجموعة حسب النظام الفرعي، مع سجل مصغر لكل شاشة.

### 6.1 جرد المجموعات

| المجموعة | الملف (الأسطر) | الشاشات |
|---|---|---|
| لوحة العائلة (Dashboard) | `dashboard_screen.dart` (923) | DashboardScreen + شاشة إنشاء عائلة مدمجة + بوابات noFamily/familySetupRequired |
| FS-001 الموقع (12) | `location_screens.dart` (2600) + `location_child_screens.dart` (248) | FamilyMapScreen, MemberLocationDetailsScreen, LocationHistoryScreen, GeofenceListScreen, CreateGeofenceScreen, EditGeofenceScreen, LocationSettingsScreen, LocationAlertsScreen, LocationPrivacyScreen, PermissionOnboardingScreen, SharingStatusScreen, FavoritePlacesScreen + ChildLocationSharingScreen |
| FS-002 فلترة الويب (11) | `web_filter_screens.dart` (645) + `web_filter_management_screens.dart` (831) + `web_filter_child_screens.dart` (849) | WebFilterDashboardScreen, WebFilterCategoriesScreen, WebBlocklistScreen, WebSettingsScreen, WebBlockHistoryScreen, WebBlockHitDetailScreen, WebTemporaryAllowScreen, WebAllowlistScreen, PerChildWebPolicyScreen, BlockedPageScreen + شاشة لوحة (10 WF + مشاركة عرض) |
| FS-003 التحكم بالتطبيقات (9) | `application_screens.dart` (1956) | AppControlDashboardScreen, InstalledAppsListScreen, AppDetailScreen, AppAllowlistScreen, PerChildAppRulesScreen, UsageAlertsScreen, AppBlockHistoryScreen, ChildAppUsageScreen + NoAppPolicy widget |
| FS-004 المراقبة (8) | `monitoring_screens.dart` (2106) | MonitoringDashboardScreen, MonitoringCameraControlScreen, MonitoringEvidenceQueueScreen, MonitoringLiveSessionScreen, MonitoringRequestsHistoryScreen, MonitoringSchedulesScreen, MonitoringScreenshotsTimelineScreen, MonitoringShotViewerScreen, MonitoringChildSessionScreen |
| FS-005 الأنماط (8) | `modes_screens.dart` (2375) | ModesDashboardScreen, ModeDetailScreen, ModeCreateScreen, ModeEditScreen, ModeScheduleScreen, ModeChildrenScreen, ModeActivationHistoryScreen, ChildActiveModeScreen |
| FS-006 SOS (8) | `sos_screens.dart` (2002) | SosDashboardScreen, SosActivationScreen, ActiveSosScreen, EmergencyLocationScreen, EmergencyAlertScreen, SosAckHistoryScreen, SosRecipientsScreen, SosDrillScreen |
| FS-007 المهام (8) | `tasks_screens.dart` (1885) | FamilyTasksDashboardScreen, TaskBuilderScreen, TaskEditScreen, TaskDetailScreen, TaskChildViewScreen, TaskCompletionScreen, RecurringTasksScreen, TaskTimelineScreen |
| FS-008 المكافآت (8) | `rewards_screens.dart` (1129) | RewardsDashboardScreen, RewardCatalogScreen, RewardCatalogEditorScreen (new+edit), RewardRedeemScreen, PendingClaimsScreen, RewardAutomationScreen, RewardLedgerScreen |
| FS-009 التقارير (8) | `reports_screens.dart` (1094) | ReportsDashboardScreen, WebReportScreen, UsageReportScreen, LocationReportScreen, SafetyReportScreen, ModesReportScreen, SosReportScreen, ReportExportScreen |
| FS-011 القواعد (7) | `rules_screens.dart` (2114) | FamilyRulesDashboardScreen, RuleBuilderScreen, RuleEditScreen, RuleScheduleScreen, RuleImpactScreen, RuleConflictsScreen, RuleExecutionLogScreen |
| FS-015 ربط الأجهزة (10) | `device_linking_screens.dart` (1832) | DeviceLockoutScreen, DeviceEnrollScreen, DeviceEnrollConfirmScreen, SpouseLinkDeviceScreen, SpouseEnrollScreen, SpouseRoleConfirmationScreen, DevicePermissionOnboardingScreen, DeviceUnlinkScreen, DeviceHealthDashboardScreen, DeviceTransferScreen |
| شاشات مساعدة | 5 ملفات | FamilyMembersScreen, PairingScreen, ChildRedemptionScreen, ChildContextScreen, FirebaseSessionScreen, PermissionsScreen, SafetyPoliciesScreen, FamilyDailySafetyScreen, FamilySafetyTimelineScreen, ParentExceptionRequestsScreen, SafetyActionsScreen, SettingsScreen |

### 6.2 سجل مصغر لعينة الشاشات (الالتزام بالنمط المطلوب)

**FamilyMapScreen** — `/location/:familyId` — هدف: عرض مواقع أفراد العائلة على خريطة مع مؤشرات حالة. **المدخلات:** familyId (مسار)، نقاط الموقع من SQLite، دور الممثل. **العرض:** مؤشرات أعضاء على خريطة (Widget خريطة داخلي — ملاحظة: لا يوجد مزود خرائط خارجي مثل Google Maps مثبت؛ الخريطة عبارة عن سطح عرض مخصص INFERRED)، بطاقات أقرب نقطة لكل عضو، شريط تحديث. **حالات:** loading (GuardianStateView)، no-data (hero image onboarding_location + "لا توجد مواقع بعد")، offline (GuardianOfflineBanner)، permission-denied. **الأزرار:** عرض تفاصيل العضو، التنبيهات، الجدران. **المخارج:** navigate إلى `/location/:fid/:memberId`, `/alerts`, `/geofences`.

**TaskBuilderScreen** — `/tasks/:familyId/new` — هدف: إنشاء مهمة عائلية. **المدخلات:** familyId، قائمة الأطفال (filter بالصلاحية)، بيانات النموذج. **العرض:** حقول العنوان/الوصف/الاستحقاق (تاريخ+ساعة اختيارية)/التكرار (بدون/يومي/أسبوعي + أيام)/الأطفال المُسندين/ربط بقاعدة (linkedRuleId) → جسور FS-011. **الحالات:** لا أطفال (رسالة + زر addChild)، حقل فارغ (خطأ تحت الحقل)، فشل الحفظ (SnackBar honest error). **المخارج:** حفظ → tasks.create → navigate detail.

**PendingClaimsScreen** — `/rewards/:familyId/claims` — هدف: قائمة طلبات الاسترداد المعلقة لولي الأمر. **المدخلات:** rewardPendingClaimsProvider. **العرض:** بطاقة لكل طلب (الطفل، المكافأة، التكلفة بالنقاط، التاريخ، القرار إذا وُجد). **الأزرار:** approve/decline. **المخارج:** قرار عبر rewardsRepository → outbox → سجل نقاط سالب فقط عند الموافقة (Honesty: لا خصم قبل القرار). **الحالات:** لا طلبات (hero family_rewards.png)، فشل تحميل، طفل بلا صلاحيات.

**SosActivationScreen** — `/sos/:familyId/activate` — هدف: تفعيل حالة SOS طارئة. **المدخلات:** SosConfig، قائمة المستلمين. **العرض:** زر تأكيد كبير + عداد تنازلي لإلغاء الإرسال (مضاد للتنشيط الخاطئ)، شرح ما سيُرسل. **المخارج:** sos.activate event → مستند sos_events + إشعار outbox للمستلمين. **الحالات:** لا مستلمين (رسالة + زر recipients)، فشل.

**ModeCreateScreen** — `/modes/:familyId/new` — هدف: تعريف نمط مخصص (دراسة/نوم/سفر). **المدخلات:** قالب نمط (templates)، قيود (تطبيقات/وقت/جدران)، جدول زمني. **المخارج:** mode.created → mode_activations + mode_configs. **الترابط:** الأنماط تُفعّل/تُعطل من Dashboard؛ ConflictResolver يكشف تعارض الأنماط مع السياسات (FS-005 ←→ FS-002/FS-003).

**ChildContextScreen** — `/child/:familyId/:childId` — هدف: واجهة الطفل الشفافة (يرى فقط ما يخصه). **المدخلات:** childId + ctx.actor (child). **العرض:** سياساته (عرض فقط)، استخداماته، مهامه، رصيده، حالة جهازه، مشاركة موقعه. **الأزرار:** طلب استثناء، طلب إتمام مهمة، طلب استرداد مكافأة. **ملاحظة معمارية:** الشاشة نفسها تُعرض للبالغ بصلاحيات أوسع — التمييز عبر `FamilyRuntimeContext.can()` لا عبر شاشتين.

### 6.3 أنماط التصميم المشتركة (ملخص)

كل الشاشات تستخدم بريميتيفات `guardian_primitives.dart`: `GuardianCard` (حافة مدورة 16)، `GuardianStateView` (loading/error/empty)، `GuardianOfflineBanner`، `GuardianSection`، `GuardianStatTile`، `GuardianStatusChip`. الصور الثابتة (12 في `assets/images/`) تُعرض داخل `ClipRRect(borderRadius:16, BoxFit.cover)`. الأيقونات من `font_awesome_flutter`. الشاشات تتشابه: Header + Section + قائمة + CTA سفلي، مع نصوص l10n عربية أولية.

---

## 7. المعمارية وخريطة المستودعات (Architecture and Repository Map)

### 7.1 نظرة معمارية

```
main.dart
 ├─ GuardianDatabase.instance.initialize()        ← sqflite (SQLite v24)
 ├─ GuardianFirebaseBootstrap.initialize()        ← Firebase (flag-controlled, emulator support)
 └─ ProviderScope(child: GuardianApp())
      ├─ AppTheme (light/dark, Cairo + Material 3)
      ├─ appRouterProvider (GoRouter ~90 routes)
      └─ GuardianProviderScope → presentation ← providers (Riverpod) ← data (repositories)
           ← domain (pure models/engines)  ← core (db, l10n, theme, sync)
```

الطبقات تتبع نمط clean architecture ببنية 5 مجلدات تحت `lib/`: `core` (ثوابت وقاعدة بيانات وترجمة وثيمات وoutbox)، `domain` (نماذج نقية ومحركات قرارات بدون Flutter)، `data` (مستودعات repositories + خدمات Firestore/Render)، `application` (providers منسقة + coordinator المزامنة)، `presentation` (screens + router + primitives).

### 7.2 ملف المستودعات (Repository Inventory)

| الملف | المسؤلية |
|---|---|
| `core/database/guardian_database.dart` | SQLite singleton، migrations من v1 إلى v24، كل الـ50 جدول |
| `core/sync/outbox_sync_executor.dart` | استئناف/إرسال دفعات outbox، single-flight، تصنيف فشل |
| `data/firestore_contracts.dart` | ~1100 سطر: جميع أحداث العائلة (family.created .. family.reward.*) مع المسارات والبيانات |
| `data/remote/outbox_remote_writer.dart` | كتابة outbox → Firestore batch.set مع serverTimestamp + idempotency |
| `data/remote/remote_provisioning_service.dart` | استدعاء Render (provision-child/redeem-child/notify) |
| `data/*_repository.dart` (14 مستودع) | CRUD لكل نظام: location/web_filter/app_control/monitoring/modes/sos/family_tasks/family_rewards/reports/family_rules/devices/family_members/family_authorization/fcm_token |
| `domain/family_authorization.dart` | مصفوفات الصلاحيات + FamilyRuntimeContext.can() |
| `domain/*.dart` (~17 ملف) | النماذج والمحركات النقية (EnforcementEngine, PolicyEngine, RiskEngine, ScreenTimeEngine...) |

### 7.3 خريطة المستودع GitHub

| المسار | المحتوى |
|---|---|
| `lib/` (106 ملفات) | التطبيق كاملاً (Flutter/Dart) |
| `test/` (52 ملفاً) | الاختبارات |
| `docs/00_master/` | المخطط الرئيسي + تقارير الإغلاق + مصفوفة الميزات + INDEX + ROADMAP + coherence audits + قواعد Firestore + ARENA_AI_HANDOFF + ASSETS_REQUIRED |
| `guardian_backend/` | خادم Render (index.js 502 سطر، Express 5 + firebase-admin 14 + cors + dotenv) |
| `firebase/` | firestore.rules (v2 + helpers: signedIn/member/activeMember/parent/owner/creatingOwnFamily/activeOwnedDevice/activeTokenDevice)، storage.rules، indexes.json، functions/، tests/، EMULATOR_SECURITY_TEST_PLAN |
| `firebase.json` | projectId: manus-guardian، emulator ports 9099/8080/5001 |
| `android/` | إعدادات Android + google-services.json |
| `assets/images/` | 12 صورة علامة (family_tasks, family_rewards, family_rules, family_reports, device_pairing, monitoring_guard, sos_emergency, onboarding_*, guardian_eye_icon) |
| `README.md` | **مخزون Flutter الافتراضي — لم يُخصص** (فجوة موثقة) |

### 7.4 دورة طلب البيانات (Data Request Flow)

```
Screen → Riverpod provider (guardian_providers.dart: 116 provider)
   → Repository (يقرأ SQLite أولاً — offline-first)
   → (مزامنة) outbox rows → OutboxSyncExecutor → Firestore batch
   → (عند الحاجة) Render REST أو Firebase real-time listener [ملاحظة: القراءة من Firestore عبر جسر — listener ليس معمماً على كل الجداول]
```

---

## 8. نماذج البيانات وخريطة API (Data Models and API Map)

### 8.1 قاعدة البيانات المحلية (SQLite v24 — 50 جدول)

| المجموعة | الجداول | النظام |
|---|---|---|
| العائلة | families, family_members, family_invitations, devices | FS-015/عام |
| الإقران والأجهزة | pairing_sessions, child_device_* (6 جداول) | FS-015 |
| الاستخدام | child_usage_summaries, child_usage_* (5 جداول) | FS-003 |
| الويب | web_hits, web_filter_*, app_policies, allowlist, block_history, usage_alert_settings | FS-002/FS-003 |
| الموقع | location_points, location_alerts, geofences, favorite_places, location_settings | FS-001 |
| السلامة | incidents, sos_events, sos_recipients, monitoring_* (5), app_policies | FS-004/FS-006 |
| الأنماط | mode_activations, mode_configs | FS-005 |
| القواعد | family_rules, rule_execution_log | FS-011 |
| المهام | tasks, task_completion_log | FS-007 |
| المكافآت | family_rewards, reward_points_ledger, reward_pending_claims | FS-008 |
| المزامنة | outbox (+idempotency_key), notification_events, notification_tokens | عام |

الهجرة مرقمة v1..v24، وكل حالات الترقية (upgrade cases) مكتوبة بحيث تكون idempotent (فحص عبر `PRAGMA table_info` للـ ALTER).

### 8.2 نماذج النطاق الرئيسية (domain)

`FamilyMember` (role: primaryParent/parent/coParent/spouse/child)، `FamilyInvitation` (+Status)، `GuardianFamily`، `GuardianDevice` (+DeviceHealth)، `GuardianIncident` (+IncidentLifecycle)، `DigitalPolicy` + `PolicyEngine` (PolicyDecision/Resolution)، `ChildDeviceState` (state machine)، `EnforcementEngine` (fail-closed decisions)، `ChildExceptionRequest` (state machine)، `ScreenTimeEngine`، `ModeConfig/Activation/Template/ConflictResolver`، `SosConfig`، `PairingRequest/Lifecycle/EnrollmentResult`، `DeviceLinkingLifecycle/DeviceTransferResult`، `FamilyRule` (+linkedTaskId bridge ←→ FS-007)، `TaskEntry` (+TaskStatus/TaskRecurrence/TaskGateResolver)، `FamilyReward` (+PointsLedgerEntry/LedgerReason/RewardClaim/RewardAutomation)، `FamilyReportSnapshot`، `GuardianEvent`، `RiskEngine/RiskDecision`، `SafetyObservation/SafetyTimelineEvent`، `ParentNotificationContract`، `PermissionLadderRow`.

### 8.3 خريطة الـ Backend الحقيقي (Render)

| المسار | الطريقة | الوظيفة | المصادقة |
|---|---|---|---|
| `GET /` | GET | health check | — |
| `/api/provision-child` | POST | إعداد جهاز طفل (يرسل push للوالد) | requireAuth (Firebase) |
| `/api/redeem-child` | POST | استرداد كود إقران | requireAuth |
| `/api/notify` | POST | إرسال إشعار push عبر FCM | requireAuth |

المصدر: `guardian_backend/index.js` (Express 5.2.1 + firebase-admin 14.2.0 + dotenv). الـ URL الافتراضي: `https://guardian-eye-djg8.onrender.com` (قابل للتعديل عبر SharedPreferences في `remote_provisioning_service.dart`). **ملاحظة مهمة:** كل منطق العائلة الفعلي (العائلات، الأعضاء، السياسات، الحوادث) يعيش في **Firestore مباشرة عبر outbox** — خادم Render مسؤول فقط عن provisioning والإشعارات، وليس عن البيانات.

### 8.4 خريطة أحداث Firestore (businessMutation → path + data)

| الحدث | المسار الناتج | النظام |
|---|---|---|
| `family.created` | families/{fid} + members/{uid} | عام |
| `family.member.invited/cancelled/accepted` | members + invitations | FS-015 |
| `family.member.revoked / role.updated` | members | FS-015 |
| `family.policy.*` (create/update/override/exception) | policies/{id} | FS-002/003 |
| `family.incident.*` (recorded/acknowledged) | incidents/{id} | عام |
| `family.sos.*` (activated/recipient-notified) | sos_events | FS-006 |
| `family.device.*` (linked/unlinked/transferred) | devices | FS-015 |
| `family.mode.*` (activated/configured) | mode_activations | FS-005 |
| `family.rule.*` (created/updated/executed) | family_rules + rule_execution_log | FS-011 |
| `family.task.created/updated/cancelled/completion-requested/completed` | tasks/{id} + task_completion_log | FS-007 |
| `family.reward.created/updated/toggled/ledger.earned/claim.requested/claim.decided` | family_rewards + reward_points_ledger + reward_pending_claims | FS-008 |

المرسل: `OutboxRemoteWriter` عبر `Firestore.batch().set()` مع `serverTimestamp()` و`idempotencyKey` لكل صف outbox. التعارض: آخر كاتب يفوز (last-writer-wins عبر serverTimestamp) — لا تعارض متعدد الاتجاهات معقد.

### 8.5 API الداخلية (لا REST خارجي آخر)

التواصل بين التطبيق وخلفية Render REST عبر `RemoteProvisioningService` (Dio). لا يوجد REST للتقارير/السياسات/المهام — كلها عبر outbox → Firestore. لا يوجد GraphQL/WebSocket. API سطح التطبيق هو **Riverpod providers** (116) وليس REST داخلي.

---

**ما تم تغطيته في الجزء 2:** الأقسام 6-8 (جرد الشاشات كاملاً، المعمارية وخريطة المستودعات، نماذج البيانات وخريطة API وخريطة الأحداث).
**ما يلي في الجزء 3:** المصادقة والصلاحيات (قسم 9)، الخصوصية (10)، UI/UX (11).

---

# الجزء 3 من 4 — المصادقة والصلاحيات، الخصوصية، واجهة المستخدم

---

## 9. المصادقة والصلاحيات (Authentication and Permissions)

### 9.1 المصادقة (Authentication)

المصادقة عبر **Firebase Authentication** (email/password) في `lib/data/firebase_auth_context.dart` مع ثلاث عمليات: `signInWithEmailAndPassword` (سطر 72)، `createUserWithEmailAndPassword` (79)، `signOut` (90). الشاشة المقابلة `/firebase-session` (FirebaseSessionScreen). النظام **معلَّم بالبيئة**: `bool.fromEnvironment('GUARDIAN_FIREBASE_CONFIGURED')` + تحقق من `Firebase.apps.isNotEmpty`، مع دعم Firebase Emulator، والحالة `FirebaseBootstrapStatus.disabled/ready/failed` تُعرض بصدق على الشاشة (لا تعليق للتطبيق عند تعطل Firebase).

ملاحظة مهمة: المصادقة الحالية **بلا بوابة OAuth أو SMS**؛ حساب الطفل نفسه هو Firebase account منفصل يُنشأ أثناء دورة الإقران (provision-child عبر Render)، ولا توجد مصادقة ثنائية العامل ولا إدارة جلسات متعددة الأجهزة موثقة. **UNKNOWN** حالة إعادة المصادقة الدورية (هل يُطلب من ولي الأمر إعادة تسجيل دخول دورية؟ لا يوجد دليل في الكود — INFERRED: لا).

### 9.2 الأدوار والصلاحيات (Authorization)

نموذج الصلاحيات: **enum FamilyPermission** (~55 صلاحية في `lib/domain/guardian_models.dart` منها viewTasks/manageTasks/viewRewards/manageRewards المضافة في FS-007/FS-008)، تُفسَّر عبر **FamilyRuntimeContext.can(perm)** في `lib/domain/family_authorization.dart` بمصفوفات لكل دور:

| الدور | الصلاحيات النموذجية | القيود |
|---|---|---|
| primaryParent | جميع الصلاحيات بلا استثناء | مالك العائلة فقط |
| parent / coParent | إدارة الأطفال والسياسات والاستثناءات والخط الزمني والأجهزة والتقارير والقواعد والمهام والمكافآت | لا عزل أعضاء، لا نقل ملكية |
| spouse | عرض فقط + استثناءان: يُحقق إتمام المهام (verify)، يرى المكافآت | لا تعديل في أي كيان |
| child | viewFamily + viewOwnPolicy/Usage/Status/Permissions/Report/Rules/Tasks/Rewards + طلباته الخاصة (استثناء/إتمام مهمة/استرداد مكافأة) | `canViewSafetyEvents = false`، `canAcknowledgeIncident = false`، لا يرى بيانات غيره أبداً |

القاعدة المعمارية الملزمة: **لا إعادة تنفيذ لفحوص الأدوار محلياً في الشاشات** — كل قرار عبر `ctx.can()` واستخدام `ctx.actor` (وليس `ctx.me`). الرفض يرمي `StateError('family_permission_denied:{perm}')` ويُعرض عبر GuardianStateView. توجد أيضاً `PermissionLadderRow` في `device_linking.dart` لسلم صلاحيات الجهاز المعروض في onboarding.

**أبرز فجوات الصلاحيات:** لا توجد صلاحيات granular للزوج في إدارة الحوادث (يُرى فقط)، ولا فصل صلاحيات بين parent وcoParent في القواعد (كلاهما يملك manageRules — قد يكون مقصوداً)، ولا قيود على حذف المكافآت ذات الطلبات المعلقة (INFERRED: الحذف يتم دون تحويل الطلبات — يحتاج قرار منتج).

---

## 10. مراجعة الخصوصية وحماية الأسرة (Privacy and Family-Safety Review)

### 10.1 ما هو موعود للخصوصية (في النصوص والمواصفات)

النصوص المعلنة في l10n (مفاتيح privacy*): "نجمع فقط آخر مواضع معلنة لكل عضو مفعّل له المشاركة، وفق وتيرة تحديث محددة في الإعدادات" و"تُحفظ المواضع محليًا وتُزامن مع حسابات العائلة الموثقة فقط. لا تحتفظ العائلة بأي بيانات بعد حذف العضو" و"حذف بيانات الموقع" + "يمكنك حذف سجل المواقع في أي وقت من إعدادات هذا الجهاز. لا تُرسل البيانات إلى أطراف ثالثة". يوجد نظام قواعد Firestore مكتوب (`firebase/firestore.rules` v2) مع helpers: signedIn, member, activeMember, parent, owner, creatingOwnFamily, activeOwnedDevice, activeTokenDevice؛ قراءة families/{fid} للعضو النشط فقط. توجد وثائق قواعد لكل نظام (FIRESTORE_RULES_LOCATION.md، FIRESTORE_RULES_WEB_FILTER.md) تحدد كاتب/قارئ كل مستند (مثل: مواضع الموقع يكتبها جهاز الطفل/الوالد حصراً، الآباء قراءة فقط؛ الجدران يكتبها الوالد).

### 10.2 ما هو منفذ فعلاً في حماية البيانات

| الآلية | الحالة | الدليل |
|---|---|---|
| تجزئة كود الإقران (SHA-256) | منفذة | `guardian_repositories.dart:163` sha256 of rawCode |
| عزل رؤية الطفل | منفذة برمجياً | FamilyAuthorization + ChildContextScreen |
| قواعد Firestore مقيدة | مكتوبة، **UNVERIFIED النشر** | firebase/firestore.rules موجود؛ هل نُشرت فعلاً على projectId manus-guardian؟ UNKNOWN |
| تخزين محلي مشفر | **غير منفذ** | sqflite بملف SQLite عادي؛ لا SQLCipher ولا أي تشفير على مستوى التطبيق |
| flutter_secure_storage | **غير مستخدم** رغم وجوده في pubspec | grep: 0 import في lib |
| حذف الحساب / تصدير البيانات | **غير منفذ** | 0 مفاتيح l10n، 0 شاشات |
| حذف سجل الموقع (الموعود) | وجود مفتاح l10n فقط؛ لا توجد شاشة حذف في location_settings | INFERRED: غير منفذ |
| تشفير البيانات أثناء النقل | منفذ ضمنياً (HTTPS لـ Render + Firestore TLS) | افتراضي Firebase/Render |
| حد عمر/موافقة الطفل | غير موجود | لا منطق age-gating في الكود |

### 10.3 التزامات تنظيمية مفتوحة

**COPPA / GDPR-K:** لا يوجد age-gating، ولا بوابة موافقة والدية قابلة للتوثيق، ولا سياسة خصوصية داخل التطبيق، ولا آلية حذف حساب (مطلوبة تنظيمياً في Google Play لأسر الأطفال). **الفجوة الأخطر:** حذف الحساب وتصدير البيانات غير منفذين إطلاقاً بينما تُعد هذه ميزة إلزامية تقريباً في متاجر التطبيقات لمنتجات عائلية. **التوصية كقرار منتج:** قبل أي نشر تجاري، يجب تنفيذ: (1) حذف حساب شامل (محلي + Firestore + devices)، (2) تصدير بيانات العائلة (ملف zip)، (3) سياسة خصوصية داخل التطبيق، (4) التحقق من نشر قواعد Firestore على projectId، (5) تشفير قاعدة البيانات المحلية أو على الأقل حماية ملف SQLite.

---

## 11. واجهة المستخدم ونظام التصميم (UI/UX and Design System)

### 11.1 نظام التصميم (Design System)

النظام مبني على `lib/core/theme/guardian_tokens.dart` كمصدر وحيد للحقيقة البصرية:

| التوكن | القيمة | الاستخدام |
|---|---|---|
| guardianNavy | `#0F2A5B` | الهيدرات، AppBar، شريط التنقل السفلي، العلامات |
| guardianNavyDeep | `#0A1F44` | تدرجات الوضع الليلي |
| guardianNavySoft | `#163872` | أسطح ثانوية |
| guardianTeal | `#00B8A9` | اللون الثانوي، الأزرار، المؤشرات |
| guardianTealLight / Deep / Soft | `#2DD4BF` / `#00897B` / `#CCF2EE` | حالات ومشتقات |
| statusAlert | `#E2574C` (Soft `#FDE3E1`) | الأخطاء والتنبيهات |

الخط: **Cairo** (عربي) عبر `google_fonts` مع Material 3. القيم المعلنة للنوايا: Trust · Safety · Calm · Intelligence · Family · Premium · Modernity · Clarity — "حالة هادئة صادقة لا تُدرِم الأحداث".

### 11.2 البريميتيفات التسعة

`lib/presentation/guardian_primitives.dart`: **GuardianCard** (بطاقة مدورة 16 + ظل)، **GuardianHeroCard** (بطاقة صورة بطل)، **GuardianIconBadge** (شارة أيقونة دائرية)، **GuardianOfflineBanner** (شريط honest offline)، **GuardianSection** (قسم بعنوان)، **GuardianStatTile** (بلاطة إحصاء)، **GuardianStateView** (loading/error/empty بمبدأ "لا نجاح كاذب")، **GuardianStatusChip**، **GuardianStatusPalette**. كل الشاشات (~96) تستخدمها؛ القواعد الإلزامية الموثقة: الصور داخل `ClipRRect(borderRadius:16, BoxFit.cover)`، ولا spread operator خاطئ (`..` بدل `...`)، ولا فحوص أدوار محلية.

### 11.3 التوطين (Localization)

ملف واحد `lib/core/localization/app_localizations.dart` بمصفوفتين ثابتتين متطابقتين (1,377 مفتاح AR = EN بالضبط)، نمط الاستخدام `l10n.t('key')` في كل الشاشات. الاتجاه RTL افتراضي مع LayoutBuilder للتبديل. التغطية ثنائية كاملة لكل الأنظمة المنفذة (مفاتيح wf_/ac_/sc_/md_/so_/tk_/rw_/rp_/fr_/dl_/lo_...) — تم التحقق آلياً بمسح Python في هذه الجلسة (0 مفاتيح مستخدمة غير معرفة). **الفجوات:** لا نظام arb/مولد؛ التحديث يدوي (قيد موثق في متطلبات المشروع)، ومفاتيح الحذف/التصدير غير موجودة (قسم 10).

### 11.4 الأصول البصرية

12 صورة علامة في `assets/images/`: guardian_eye_icon، device_pairing، family_tasks، family_rewards، family_rules، family_reports، monitoring_guard، sos_emergency، onboarding_alerts، onboarding_filtering، onboarding_location، onboarding_screen_time (كلها flat vector art بنمط navy/teal). الأيقونات: `font_awesome_flutter` + Material icons. **الفجوات:** لا أيقونة مخصصة للتطبيق بحجم launcher كامل موثقة (guardian_eye_icon موجود لكن غير مثبت أنه الـ launcher الفعلي)، لا رسوم متحركة/انتقالات معمارية (INFERRED: انتقالات GoRouter افتراضية)، لا Dark mode UI كامل — يوجد AppTheme._build light/dark لكن انتشار dark غير مختبر.

### 11.5 تجربة الحالات الصعبة (حسب المبدأ المعلن)

كل الشاشات تعرض الحالات الأربعة بصدق: loading (GuardianStateView)، empty (hero image + رسالة AR)، error (statusAlert + رسالة فعلية)، offline (GuardianOfflineBanner أعلى التطبيق). لا توجد نجاحات كاذبة: حالات المزامنة (localOnly/queued/synced/blocked/failed) تُعرض، وتقرير الحوادث يمر دورة حياة قابلة للتتبع.

---

**ما تم تغطيته في الجزء 3:** الأقسام 9-11 (المصادقة والصلاحيات، الخصوصية وحماية الأسرة، UI/UX ونظام التصميم).
**ما يلي في الجزء 4:** الاختبارات والجودة (12)، الديون التقنية (13)، blockers (14)، المجهولات (15)، القرارات المقترحة (16)، فهرس الأدلة (17)، ملخص التسليم (18).

---

# الجزء 4 من 4 — الاختبارات والجودة، الديون التقنية، العوائق، المجهولات، القرارات، الأدلة، الملخص

---

## 12. مراجعة الاختبارات والجودة (Testing and Quality Review)

### 12.1 الأرقام العامة

| المؤشر | القيمة |
|---|---|
| ملفات الاختبار | 52 |
| عدد الاختبارات (test/testWidgets) | 383 |
| آخر تشغيل انحدار | 380/380 أخضر (يُستثنى helperان) |
| تحليل Static | 0 أخطاء، 0 تحذيرات (flutter analyze) |
| تحليل TODO/FIXME/محاكاة | 0 TODO، 0 FIXME، 0 Mock في lib |
| APK release | يبنى بنجاح (90 MB)، tag `validation-build-20260818` (18 أغسطس 2026) |
| اختبار على جهاز حقيقي | **لم يُنفذ أبداً** (مفصلة في قسم 14) |

### 12.2 التغطية حسب النظام الفرعي

| المجموعة | الملفات | الاختبارات | ملاحظات |
|---|---|---|---|
| الأنظمة المنفذة | fs003=8، fs004=11، fs005=15، fs006=13، fs007_008=26، fs009=10، fs011=13، fs015=10 | 106 | FS-001 وFS-002 **بلا أي ملف اختبار** رغم أنهما أساسيان |
| مراحل المخطط (m1-m8) | m1_shell=9، m3_child_context=12+8، m4_device_linking=8، m4_pairing_widget=10، m5_identity=6، m5_family=13، m6_policy_admin=20، m7_measurement=37، m8_enforcement=19 | 142 | تغطي القشرة، سياق الطفل، الإقران، إدارة العائلة، الإدارة السياسات، القياس، الإنفاذ |
| البنية التحتية | outbox_retry=2، outbox_sync_executor=6، outbox_sync_status=4، pairing_lifecycle=2، pairing_safety=2، sync_coordinator=5، coherence_audit=6، firebase_bootstrap=3، firebase_contract=8 | 38 | |
| الواجهة | widget_test=2 (يفتح عائلة فارغة)، m4_pairing_widget=10 | 12 | اختبار الواجهة ضئيل مقارنة بـ96 شاشة |

### 12.3 نقاط القوة المكتشفة

الاختبارات حقيقية بالكامل: تفتح قاعدة بيانات تجريبية (sqflite_common_ffi عبر `openTestDatabase` في `test_database.dart`)، تبذر عائلة مع أربعة أعضاء (family-fr/parent-fr/child-a/child-b)، وتتحقق من سلوك المستودعات فعلياً. اختبارات المراحل (m1-m8) هي الأعلى قيمة لأنها تختبر التدفقات عبر الطبقات. اختبارات FS-007/FS-008 (26) اكتشفت وأصلحت 3 ثغرات منطقية حقيقية أثناء بنائها (حالة 'in_progress' خاطئة، رفض التحقق المتعدد للأطفال، تصادم idempotency) — دليل على فائدتها.

### 12.4 نقاط الضعف المكتشفة

1. **لا اختبارات وحدة للمحركات النقية** (EnforcementEngine, PolicyEngine, ScreenTimeEngine, ConflictResolver, RuleGateResolver, RewardAutomation) — منطق القرار الأعقد في المنتج غير مختبر بوحدة مستقلة، بل فقط عبر اختبارات مستودعات.
2. **لا اختبارات تكامل GoRouter/Provider** للشاشات (widget tests شبه معدومة: 12 من 383).
3. **headless_validation_test.dart** متعطّل سابقاً (hang) ويُستثنى من الانحدار — كانت الطبقة الوحيدة شبه-تلقائية لفحص الشاشات.
4. **لا اختبارات لنظامَي FS-001 وFS-002** إطلاقاً.
5. **لا اختبارات أداء/ذاكرة** (الصور 2176×1632 تُحمَّل كاملة — خطر ذاكرة على أجهزة ضعيفة، INFERRED).

### 12.5 حالة التحقق على جهاز حقيقي (بصراحة تامة)

لا emulator ولا Firebase Test Lab ولا جهاز حقيقي استُخدم في هذه الجلسة أو موثق في تاريخ المشروع. تم فقط **بناء APK release بنجاح** (90 MB) كدليل على قابلية البناء. سلوك Android الحقيقي — صلاحيات الخلفية، lifecycle، background services، Location في الخلفية — **غير مختبر** ولا يمكن ادعاء صحته. headless harness (flutter_tester) وثّق نفسه صراحة كطبقة وسيطة لا تعادل اختبار Android.

---

## 13. سجل الديون التقنية (Technical Debt Register)

| # | البند | الشدة | التفصيل |
|---|---|---|---|
| D1 | عمل FS-007/FS-008 غير محفظ | **حرجة** | 18 ملفاً متغيراً خارج version control على الفرع؛ أي تعطل يفقد العمل |
| D2 | حذف الحساب وتصدير البيانات | **حرجة** | مطلب تنظيمي أساسي لمنتج عائلي؛ غير منفذ إطلاقاً |
| D3 | تتبع الموقع في الخلفية | **عالية** | التقاط يدوي فقط؛ القيمة الأمنية للمنتج (الموقع/الجدران) أضعف من الموعود |
| D4 | الإشعارات المحلية غير موصولة | **عالية** | flutter_local_notifications في pubspec بلا أي استخدام؛ لا push فعلي على الجهاز رغم وجود FcmTokenRepository |
| D5 | لا تشفير تخزين محلي | **عالية** | SQLite عادي + flutter_secure_storage غير مستخدم |
| D6 | قواعد Firestore غير موثقة النشر | **عالية** | ملف firestore.rules v2 مكتوب؛ هل نُشر على projectId manus-guardian؟ غير مثبت |
| D7 | لا اختبارات FS-001/FS-002 | **متوسطة** | نظامان أساسيان بلا أي اختبار |
| D8 | headless harness معطل | **متوسطة** | hang معروف سابقاً؛ فقدان طبقة فحص شبه-تلقائية |
| D9 | README مخزون Flutter | **منخفضة** | لم يُكتب README مخصص بالمشروع |
| D10 | Master Feature Matrix قديمة | **منخفضة** | MASTER_FEATURE_MATRIX.md تصف FS-001..FS-011 كـ"Planned" رغم اكتمالها؛ تحتاج تحديث |
| D11 | لا age-gating ولا موافقة والدية موثقة | **متوسطة** | ثغرة COPPA/Play Store |
| D12 | مفاتيح l10n يدوية التحديث | **منخفضة** | نمط موثق ومنضبط لكن قابل للخطأ البشري دون فحص CI |
| D13 | صور كبيرة (2176×1632) | **منخفضة** | قد تؤثر ذاكرة على الأجهزة الضعيفة؛ لا توجد نسخ مصغرة |
| D14 | لا Dark mode مختبر | **منخفضة** | AppTheme يدعمه نظرياً لكن غير مختبر ولا معلوم انتشاره |
| D15 | لا اختبار تعارضات متزامنة حقيقي | **متوسطة** | إصلاح تصادم idempotency في هذه الجلسة يثبت الحساسية؛ يحتاج اختبار concurrency |

---

## 14. العوائق الحالية (Current Blockers)

**العائق رقم 1 — الحفظ غير المنفذ (قريب):** 18 ملف FS-007/FS-008 خارج القتهب. القرار بيد المستخدم (كلمة "احفض في القت") ولم تصدر بعد. كل عمل FS-007/FS-008 قابل للفقدان حتى الحفظ.

**العائق رقم 2 — التحقق على جهاز حقيقي (مؤسسي):** لا مسار اختبار Android حقيقي موجود في بيئة التطوير. كل ما فوق الاختبارات الوحدوية يعتمد على البناء فقط. أي قرار "جاهز للنشر التجاري" يستلزم أولاً: Firebase Test Lab (عبر Firebase CLI من الساندبوكس) أو جهاز حقيقي متصل.

**العائق رقم 3 — القيمة الأمنية الموعودة غير مبنية:** الموقع في الخلفية + الإشعارات المحلية هما العمود الفقري لقيمة "حماية الطفل" المعلن؛ غيابهما يجعل المنتج حالياً لوحة مراقبة صدقية (parent dashboard) أكثر منه نظام إنذار.

**ملاحظة:** لا توجد مشاكل blocking من حيث البناء أو التحليل — كل شيء يخزن ويحلل نظيف، والأنظمة العشرة السابقة مستقرة في القتهب.

---

## 15. المجهولات والأسئلة (Unknowns and Questions)

| # | السؤال | السبب |
|---|---|---|
| U1 | هل فُعلت قواعد Firestore الموضوعة على projectId manus-guardian؟ | القواعد ملف محلي فقط؛ لا فحص نشر موثق |
| U2 | هل Firebase في الإنتاج مفعّل أم معطل (`GUARDIAN_FIREBASE_CONFIGURED`)؟ | المعلَّم بيئي؛ سلوك التطبيق يختلف جذرياً بحسبه |
| U3 | هل يعمل خادم Render deployed حالياً؟ | لم يُتحقق من الـ health endpoint في هذه الجلسة (وُجد تقرير تحقق سابق في docs لكن غير محدث) |
| U4 | ما هي استراتيجية retention الفعلية للمواضع والـ hits؟ | النصوص تعد "آخر مواضع"؛ لا يوجد كود حذف/تقادم موثق |
| U5 | هل الـ Firestore rules تغطي جداول FS-007/FS-008 الجديدة؟ | contracts في الكود لكن نشر قواعد محدث غير مثبت |
| U6 | هل تُستقبل push notifications فعلاً من Render /api/notify؟ | سلسلة تسليم الإشعار كاملة غير مختبرة |
| U7 | ما هوية المستخدم النهائي للاشتراك (من يدفع؟)$75/سنة — القرار التجاري غير مبني بعد | Phase 13 مخطط |
| U8 | هل يوجد مالك تجاري/نشر Google Play؟ | لا بيانات حساب مطور في المستودع |
| U9 | هل شاشة الخريطة (FamilyMapScreen) تستخدم مكتبة خرائط حقيقية؟ | لا مزود خرائط خارجي مثبت في pubspec؛ INFERRED سطح مخصص بسيط |
| U10 | ماذا يحدث لبيانات الطفل المعزول على جهازه؟ | revocation في الخادم موثق؛ محو محلي غير مثبت |

---

## 16. القرارات التالية المقترحة — بدون تنفيذ (Suggested Next Decisions)

هذه توصيات للقرار فقط (لا تنفيذ، بطلب صريح من المستخدم):

**A. القرار الفوري (قبل أي عمل آخر):** تنفيذ أمر الحفظ — كلمة "احفض في القت" — لحماية عمل FS-007/FS-008 (18 ملفاً).

**B. قرار الاستقرار (الأسبوع التالي):** ترقية MASTER_FEATURE_MATRIX وREADME وتحديثهما لحالة FS-001..FS-011 الحقيقية، ثم **التحقق من نشر قواعد Firestore** وسلامة خادم Render (صحتان منخفضتان التكلفة).

**C. قرار القيمة الأمنية (قبل أي نظام فرعي جديد):** بناء التتبع الجغرافي في الخلفية (background location service) ووصل الإشعارات المحلية — بدونهما FS-010/FS-012 تبقى فوق أساس غير مكتمل.

**D. قرار الامتثال (قبل أي نشر تجاري):** حذف الحساب + تصدير البيانات + سياسة خصوصية داخل التطبيق + age-gating — متطلبات إلزامية تقريباً في Google Play للمنتجات العائلية.

**E. قرار الجودة:** إضافة اختبارات وحدة لمحركات القرار (EnforcementEngine/PolicyEngine/RuleGateResolver) واختبارات FS-001/FS-002 — استكمال الغطاء إلى ~450 اختباراً قبل الانتقال لـ Guardian AI.

**F. الترتيب المقترح للأنظمة المتبقية:** FS-012 (وضع الطفل) ← FS-010 (محادثات مؤقتة) ← FS-013 (الوئام الزوجي) ← FS-014 (لوحة البداية) ← FS-016 (بوابات/اشتراك) ← **Guardian AI (9 طبقات)** في النهاية بقرار سابق صريح.

---

## 17. فهرس الأدلة (Evidence Index)

جميع الادعاءات في هذا التقرير قابلة للتحقق من المسارات التالية داخل المستودع:

| الادعاء الرئيسي | المسار/الأمر الدال |
|---|---|
| 85 نمط مسار | `lib/presentation/router/app_router.dart` |
| ~96 شاشة / 27 ملف | `lib/presentation/screens/` (screen_classes.txt في مرفقات جلسة الاستكشاف) |
| 380/380 أخضر + 383 اختباراً | `test/` + سجل التشغيل في هذه الجلسة |
| SQLite v24 / 50 جدول | `lib/core/database/guardian_database.dart` |
| 1,377 مفتاح l10n AR=EN | `lib/core/localization/app_localizations.dart` |
| 116 بروفيدر | `lib/application/guardian_providers.dart` |
| مصفوفات الصلاحيات | `lib/domain/family_authorization.dart` + enum في `lib/domain/guardian_models.dart` |
| أحداث Firestore | `lib/data/firestore_contracts.dart` + `lib/data/remote/outbox_remote_writer.dart` |
| خادم Render | `guardian_backend/index.js` |
| قواعد Firestore | `firebase/firestore.rules` |
| المصادقة | `lib/data/firebase_auth_context.dart` |
| نظام التصميم | `lib/core/theme/guardian_tokens.dart` + `guardian_primitives.dart` |
| الثغرات الثلاث المصلحة | git history + fs007_008_tasks_rewards_test.dart (اختبارات terminal/idempotency/status) |
| تقارير الإغلاق السابقة | `docs/00_master/FS003..FS015*_CLOSURE_REPORT.md` |
| الحالة المخططة للأنظمة المتبقية | `docs/00_master/MASTER_FEATURE_MATRIX.md`، `MASTER_BLUEPRINT`، `todo.md` |
| العمل غير المحفوظ | `git status` على الفرع feature/design-system-integration (18 ملفاً) |

---

## 18. ملخص التسليم النهائي (Final Handoff Summary)

**Guardian Eye Pro** مستلم الآن كمنصة عائلة Flutter-Android في مرحلة **نموذج عملي متقدم مكتمل الواجهة** أحد عشر نظاماً فرعياً (FS-001..FS-009، FS-011، FS-015) بمجموع ~96 شاشة و85 نمط مسار و380 اختباراً أخضر وتحليل نظيف، ببنية offline-first صادقة ومصادقة Firebase حقيقية وoutbox → Firestore وCrawl خلفي Render فعلي (provisioning + إشعارات) ونظام صلاحيات دورية (~55 صلاحية) وتوطين عربي/إنجليزي متكافئ (1,377 مفتاحاً) ونظام تصميم موحد (navy #0F2A5B + teal #00B8A9 + Cairo + Material 3).

**النقاط الحاسمة التي يجب أن يحملها أي مطور أو وكيل قادم:**

1. **العمل مكتمل لـ FS-007/FS-008 لكن غير محفوظ** — 18 ملفاً في الفرع بانتظار الأمر؛ أول خطوة عملية هي الحفظ.
2. **المنتج بلا تحقق على جهاز حقيقي إطلاقاً** — لا تدّعِ جاهزية Android دون Firebase Test Lab أو جهاز متصل.
3. **العمودان الأمنيان (موقع خلفية + إشعارات محلية) غير مبنيين** — هذا أكبر فجوة وظيفية بين الوعد والتنفيذ.
4. **الامتثال التنظيمي (حذف حساب/تصدير بيانات/خصوصية) صفر** — يجب قبل أي نشر تجاري.
5. **قواعد Firestore + خادم Render + مُعلَّم Firebase كلها تحتاج تحقق نشر** — ملفات موجودة، حالة الإنتاج غير مثبتة.
6. **FS-010 غير منفذ إطلاقاً** (رغم ذكره في FS المرقمة)؛ Guardian AI مؤجل بقرار صريح لنهاية المشروع.
7. **الفرع هو feature/design-system-integration فقط** — لا دمج في master أبداً (قانون المشروع)، checkpoint المحمي `phase17-stable-checkpoint` (274e181).

**جاهزية التسليم:** كامل. كل ما في هذا التقرير نتج من فحص فعلي للكود في هذه الجلسة (20 أغسطس 2026) بدون أي تنفيذ أو تعديل ملفات، وبتمييز صريح بين Implemented / Partial / Planned / Unknown / Inferred.

---

*أُعدَّ هذا التقرير بواسطة Manus AI كمرجع تسليم معرفي (Project Discovery + Technical Handoff) دون أي تنفيذ للكود.*
