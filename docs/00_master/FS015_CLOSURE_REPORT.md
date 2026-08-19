# تقرير إغلاق المرحلة FS-015 — ربط الأجهزة والتسجيل (Device Linking & Enrollment)

**الحالة:** مكتمل ومتوافق مع معايير المنصة
**الفرع:** `feature/design-system-integration` (لم يتم الدمج مع master)
**التاريخ:** 19 أغسطس 2026
**الإعداد:** Manus AI

---

## 1. ملخص تنفيذي

أنجزت مرحلة **FS-015 (ربط الأجهزة والتسجيل)** كامل نظام ربط أجهزة العائلة بمنصة Guardian Eye Pro. تغطي هذه المرحلة دورة حياة الجهاز الكاملة: إصدار رمز الإقران، قفل المحاولات بعد الأخطاء المتكررة، تسجيل الجهاز بالرمز، اختيار الدور، تسجيل جهاز الزوج/الزوجة، سلم الأذونات، لوحة صحة الأجهزة، إلغاء الربط، ونقل التسجيل إلى جهاز جديد.

المرحلة مبنية بالكامل على البنية الحالية: لم تضف أي جداول قاعدة بيانات جديدة (قاعدة البيانات تبقى عند الإصدار 20)، ولم تغيّر أي قواعد Firebase أو مخطط Firestore أو الـ Backend على Render، وأُضيفت حالة واحدة جديدة فقط إلى عقد التوزيع: `device.transferred`.

| المؤشر | النتيجة |
| --- | --- |
| الشاشات المنفذة | 11 شاشة (DL-001 … DL-011) |
| اختبارات FS-015 الجديدة | 10/10 خضراء |
| التراجع الكامل (Regression) | 331/331 خضراء |
| أخطاء `flutter analyze` | 0 |
| مفاتيح الترجمة | 71 مفتاح `dl_*` بالعربية والإنجليزية |
| جداول قاعدة بيانات جديدة | لا يوجد (تُستخدم الجداول الموجودة في v20) |
| تغييرات قواعد Firebase / Render | لا يوجد |
| دمج مع master | لم يحدث (ممنوع وفق سياسة المشروع) |

## 2. الشاشات المنفذة

| المعرف | المسار | الشاشة | الوظيفة |
| --- | --- | --- | --- |
| DL-001 | `/safety/pairing/:familyId` | `pairing_screen.dart` (موسَّعة) | إصدار رمز الإقران مع شريط مخزون الجلسات المعلّقة الحي وشريط القفل |
| DL-002 | `/safety/pairing/:familyId/lockout` | `DeviceLockoutScreen` | شاشة القفل الصادقة بعد 5 محاولات خاطئة مع عداد المحاولات |
| DL-003 | `/enroll/:familyId/:code` | `DeviceEnrollmentScreen` | إدخال رمز الستة أرقام وتحقق صادق (4 أخطاء = معلقة، الخطأ الخامس = مرفوضة) |
| DL-004 | `/enroll/:familyId/:code/confirm` | `DeviceEnrollConfirmScreen` | اختيار نوع الجهاز (جهاز الوالد / جهاز الطفل) بعد التحقق |
| DL-005 | `/couple/:familyId/link-device` | `SpouseLinkScreen` | إصدار رمز لجهاز الزوج/الزوجة بنفس آلية الوالد |
| DL-006 | `/couple/:familyId/enroll` | `SpouseEnrollScreen` | تسجيل جهاز الزوج/الزوجة بالرمز |
| DL-007 | `/couple/:familyId/role` | `SpouseRoleScreen` | تأكيد قراءة فقط لصلاحية الزوج/الزوجة |
| DL-008 | `/onboard/device-permissions` | `DevicePermissionOnboardingScreen` | سلم أذونات Android الصادق (ليس نجاحًا مزيفًا) |
| DL-009 | `/settings/device/:deviceId/unlink` | `DeviceUnlinkScreen` | إلغاء ربط الجهاز بشفافية كاملة |
| DL-010 | `/settings/devices` | `DeviceHealthDashboardScreen` | لوحة صحة الأجهزة لجميع أجهزة العائلة |
| DL-011 | `/settings/device/:deviceId/transfer` | `DeviceTransferScreen` | نقل تسجيل الطفل إلى جهاز جديد مع إبطال القديم |

جميع الشاشات تستخدم نظام التصميم الموحّد: الأزرق الكحلي `#0F2A5B` والفيروزي `#00B8A9`، بطاقات Material 3 بزوايا مدوّرة 16، خط Cairo، ودعم RTL كامل للعربية. كل شاشة تمرّ عبر بوابة التفويض `FamilyRuntimeContext.can()` ولا تعيد تنفيذ فحوص الأدوار محليًا.

## 3. طبقة البيانات

### 3.1 قاعدة البيانات المحلية (SQLite)

لم يُنشأ أي جدول جديد. تعتمد FS-015 كليًا على الجداول الموجودة منذ الإصدار 20:

- `pairing_sessions` — جلسات الإقران (الرمز، الحالة، عداد الفشل، الجهاز المسجَّل).
- `devices` — سجل الأجهزة (الدور، حالة المزامنة، آخر مزامنة، الإبطال).
- `child_device_states` — حالة دورة حياة جهاز الطفل.
- `outbox` — طابور المزامنة الصادق؛ يُدخل نقل الجهاز عبر العملية `device.transferred`.

### 3.2 مستودع PairingRepository

عُيّنت على `PairingRepository` في `guardian_repositories.dart` الدوال التالية: `sessionForCode`، `resetFailedAttempts`، `devicesForFamily`، `deviceById`، `lifecycleForDevice`، `markDeviceSynced`، `transferDeviceEnrollment`، `pendingRequestsForFamily`، و`latestSessionForFamily`. السلوك الصادق موثّق ومختبر: أول 4 محاولات برمز خاطئ تبقي الجلسة `pending` بسبب `code_mismatch`، والمحولة الخامسة ترفض الجلسة بسبب `too_many_attempts`.

### 3.3 عقد Firestore

أُضيفت حالة واحدة جديدة فقط إلى توزيع `firestore_contracts.dart` بعد `device.revoked` وهي `device.transferred`، لتحمل ملاحظة النقل الصادقة. لا تغيير على المخطط الموجود.

## 4. نموذج المجال (Domain)

ملف `lib/domain/device_linking.dart` يحتوي على النماذج الخالصة (pure) الجديدة:

- `DeviceHealth` و`DeviceHealthKind` (`healthy` / `stale` / `offline` / `revoked`) — سُلطة صحة الجهاز المشتقة من طوابع المزامنة الفعلية، لا من ادعاءات.
- `PermissionLadderStep` و`LadderStepState` و`PermissionLadderRow` — خطوات سلم الأذونات.
- `DeviceTransferResult` — نتيجة نقل التسجيل.
- `DeviceLinkingLifecycle` — دوال آلة الحالة لدورة الحياة.

مصفوفة الصلاحيات في `family_authorization.dart` امتدت بصلاحييتين: `viewDeviceLinking` لجميع أدوار البالغين (الوالد الأساسي / الوالد المشارك / الزوج)، و`viewOwnPermissions` لدور الطفل. كلاهما أُضيفتا إلى تعداد `FamilyPermission` في `guardian_models.dart` مع دور الجهاز (`DeviceRole`: parentDevice / childDevice / spouseDevice / coParentDevice).

## 5. مزودو Riverpod الجدد

| المزود | الوظيفة |
| --- | --- |
| `pendingPairingRequestsProvider` | مخزون حي للجلسات المعلّقة للعائلة |
| `latestPairingSessionProvider` | آخر جلسة إقران للعائلة |
| `familyDevicesProvider` | أجهزة العائلة المسجلة |
| `deviceByIdProvider` / `deviceLifecycleProvider` | بيانات الجهاز ودورة حياته |
| `familyDeviceHealthProvider` | سجل صحة واحد صادق لكل جهاز (DL-010) |
| `deviceSyncMarkerProvider` | تحديث علامة المزامنة |
| `deviceTransferProvider` + `setDeviceTransferScope` | نقل تسجيل الطفل إلى جهاز جديد (DL-011) |

## 6. الترابط مع المنصة

- **لوحة التحكم:** أُضيفت مجموعة تنقّل «الأجهزة» بعد مجموعة SOS في `dashboard_screen.dart`، مدعومة بالصلاحية الجديدة.
- **شاشة الإقران (DL-001):** تعرض مخزون الجلسات المعلّقة مباشرة من `pendingPairingRequestsProvider` مع شريط القفل عند `too_many_attempts`.
- **النقل (DL-011):** يُبطل الجهاز القديم (يُحفظ سجّله ولا يُحذف) ويُدخل العملية `device.transferred` إلى `outbox` ليحمله منفذ المزامنة للـ Backend.
- **الإلغاء (DL-009):** يمر عبر نفس بوابة التفويض وسجل `devices`.

## 7. الاختبارات والتحقق

### 7.1 اختبارات FS-015 (10/10 خضراء)

| المجموعة | الاختبارات |
| --- | --- |
| الإصدار والبحث | 2 (إصدار رمز / البحث بمجزأ صحيح) |
| القفل | 3 (4 أخطاء تبقى معلّقة، الخامس يرفض، إعادة التعيين) |
| التسجيل | 2 (رمز صحيح ينجح، صلاحية `viewDeviceLinking`) |
| الصحة | 1 (اشتقاق `DeviceHealth` من صفوف حقيقية) |
| النقل | 1 (إبطال القديم + عملية outbox صادقة) |
| دورة الحياة | 1 (آلة حالة `DeviceLinkingLifecycle`) |

### 7.2 التراجع الكامل

جميع حزم الاختبارات (مع استثناء `headless_validation_test.dart` المعلّق سابقًا) تعمل خضراء: **331/331** دون أي فارق عن ما قبل المرحلة.

```
All tests passed!
```

كما أن `flutter analyze` يمر دون أي أخطاء (0 errors).

## 8. الترجمة (l10n)

أُدخلت **71 مفتاح ترجمة** من عائلة `dl_*` في الخريطتين العربية والإنجليزية باستخدام النمط المعتمد في المشروع (إدخال برمجيات anchoring على رقم السطر في رأس كل خريطة، وليس الذيل، وبصيغة `'key': 'value',`).

## 9. القيود المعروفة

- التحقق يتم عبر `flutter_test` في البيئة الحالية؛ لم يُجرَ اختبار على جهاز Android فعلي في هذه الجلسة (وفق قرار المستخدم المسبق).
- `headless_validation_test.dart` معلّق بشكل مسبق (pre-existing hang) ويُستثنى من حزم التراجع؛ لم يُستثمر وقت في إصلاحه بناءً على تعليمات المستخدم.
- تُركت تسمية المشروع بعيدة عن وصف «جاهزة للإنتاج» لأن التحقق الحقيقي على أجهزة Android لم يُجرَ بعد.

## 10. الخلاصة

مرحلة FS-015 مكتملة وفق الخطة: 11 شاشة، لا جداول جديدة، حالة Firestore واحدة مضافة، صلاحيات جديدة موثقة، 10 اختبارات خضراء، تراجع 331/331 خضراء، و0 أخطاء تحليل. الكود جاهز للحفظ في GitHub على الفرع `feature/design-system-integration` فور موافقة المستخدم.

المرحلة التالية المقترحة (وفق الخطة المعتمدة مع تأجيل الذكاء الاصطناعي 9 طبقات إلى النهاية):

- **FS-009 — التقارير وPDF** (7 شاشات): تقارير أسبوعية/شهرية تستهلك بيانات FS-002…FS-006.
- **FS-011 — قواعد العائلة ومحرك السياسات** (7 شاشات).
- **FS-012 — وضع الطفل وجهاز الطفل** (5 شاشات).
