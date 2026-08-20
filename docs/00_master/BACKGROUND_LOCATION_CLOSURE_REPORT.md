# تقرير إغلاق الميزة: التتبع الخلفي للموقع (Background Location Tracking)

**المشروع:** Guardian Eye Pro — منصة أمان عائلي  
**الفرع:** `feature/design-system-integration` (لم يتم الدمج في master)  
**التاريخ:** 20 أغسطس 2026  
**الحالة:** التنفيذ مكتمل ومُختبر برمجيًا — **لم يُتحقق من السلوك على جهاز أندرويد حقيقي**

---

## 1. نبان الشفافية (Honesty Banner)

> **تنبيه صريح:** لم يتم التحقق من سلوك التتبع الخلفي على جهاز أندرويد حقيقي ولا على محاكٍ. ما تم التحقق منه هو: (1) صحة الكود عبر `flutter analyze` (صفر أخطاء)، (2) 22 اختبار وحدة جديدًا كلها خضراء، (3) 402/402 اختبار انحدار شامل أخضر، (4) مراجعة سطر بسطر للتكامل مع خط أنابيب البيانات الموجود. **سلوك الخدمة الأمامية في أندرويد (Foreground Service type=location) يتطلب جهازًا حقيقيًا للتحقق من الصلاحيات وجمع الإحداثيات فعلًا.** لا يمكن الادعاء بأن التتبع الخلفي يعمل فعلاً حتى يختبر على جهاز حقيقي.

---

## 2. ملخص الميزة

أصبح التطبيق قادرًا على التقاط إحداثيات أفراد العائلة بشكل مستمر في الخلفية عبر خدمة أمامية (Foreground Service) من نوع `location` تعمل في أندرويد، مع استمرار التسجيل في قاعدة البيانات المحلية (offline-first) ومزامنة الإدخالات مع Firestore عبر صندوق الصادر (outbox) القائم في FS-001 — دون أي تعديل على قواعد Firebase أو مخطط البيانات أو Backend في Render.

الميزة تكمل أيضًا **حلقة تنبيهات الجيوفنس** التي كانت مفقودة في FS-001: كانت الدالة `recordAlert` موجودة لكن لا أحد يستدعيها، فلم يُسجَّل أي تنبيه دخول/خروج فعلي. الآن يُقيَّم كل موقع خلفي مقابل الجيوفنسات النشطة وتُسجَّل التنبيهات وتُحدَّث حالة الجيوفنس (active → entered → exited).

## 3. المبدأ التصميمي: الصِّدق (Honesty-First)

- لا يُعرض التتبع "مفعّل" إلا إذا أكدت الطبقة الأصلية (Kotlin) بدء الخدمة فعليًا (`status = 'started'`).
- عند رفض الصلاحيات يُعرض `permissionRequired` مع زر يفتح إعدادات التطبيق — لا نجاح زائف أبدًا.
- لا يُسجَّل أي إحداثيات إلا إذا أكدتها منظومة التشغيل نفسها (`latestLatitude != null`)؛ لا إحداثيات مُختلَقة أبدًا.
- حالة "لا يوجد تثبيت موقع بعد" تُعرض للمستخدم بشفافية.

## 4. الملفات المنفذة

### 4.1 طبقة أندرويد الأصلية (Kotlin/XML)

| الملف | النوع | الوصف |
|---|---|---|
| `android/.../LocationTrackingService.kt` | جديد (~240 سطر) | خدمة أمامية من نوع `location` (Android 14+)، تلتقط الموقع عبر `LocationManager` (GPS + NETWORK) كل 60 ثانية (قابل للضبط 30–300 ثانية)، وتكتب النتائج إلى تفضيلات `guardian_tracking` (enabled / interval / latest point) |
| `android/.../MainActivity.kt` | معدّل | قناة `com.guardianeye.app/location_tracking` بثلاث طرق: `getLocationTrackingState` / `startLocationTracking(intervalMs)` / `stopLocationTracking`، مع دوال فحص الصلاحيات وبناء الحالة الصريحة |
| `android/.../BootReceiver.kt` | معدّل | يعيد تشغيل خدمة التتبع عند إقلاع الجهاز متى كانت مفعّلة |
| `android/.../AndroidManifest.xml` | معدّل | أُضيفت: `ACCESS_COARSE_LOCATION`، `ACCESS_FINE_LOCATION`، `ACCESS_BACKGROUND_LOCATION`، `FOREGROUND_SERVICE_LOCATION`، وتسجيل الخدمة بـ `foregroundServiceType="location"` |
| `android/.../strings.xml` | معدّل | سلاسل الإشعار: اسم القناة ووصفها ونص إشعار "تتبع الموقع العائلي نشط" |

### 4.2 طبقة Dart

| الملف | النوع | الوصف |
|---|---|---|
| `lib/core/platform/android_location_tracking_adapter.dart` | جديد | نموذج `TrackingState` (enable/interval/آخر إحداثيات/الصلاحيات/السبب) ونموذج `TrackingStartResult` والمنصة المجردة |
| `lib/core/platform/location_tracking_channel.dart` | جديد | جسر MethodChannel (مطابق لنمط `enforcement_platform_channel`) |
| `lib/application/background_location_service.dart` | جديد | المنسّق: طلب الصلاحيات (whenInUse + always) → تشغيل الخدمة الأصلية → مؤقت فحص دوري → تسجيل النقاط عبر `recordPoint(source='background')` → تقييم العبور |
| `lib/application/location_tracking_evaluation.dart` | جديد | مُقيِّم عبور الجيوفنس بدالة هافرساين (Dart نقي، 6076م لدائرة الأرض) |
| `lib/data/location_repository.dart` | معدّل | أُضيفت `evaluateCrossingsForPoint`: تنبيه + تحديث حالة الجيوفنس + صف outbox `geofence.crossed` — أغلقت الحلقة المفتوحة في FS-001 |
| `lib/application/guardian_providers.dart` | معدّل | أُضيف `backgroundLocationTrackingChannelProvider` و`backgroundLocationServiceProvider` |
| `lib/presentation/screens/location_screens.dart` | معدّل | بطاقة "التتبع الخلفي" في شاشة إعدادات الموقع بحالات صادقة (إيقاف/تفعيل/صلاحية مطلوبة/خطأ/تحميل) |

### 4.3 الترجمة والاختبارات

- **34 مفتاح ترجمة جديد** (17 عربي + 17 إنجليزي) بصيغة `m9Tracking*` أُدخلت في رؤوس الخرائط بالطريقة المعتادة.
- **22 اختبار وحدة جديد** في `test/fs_background_location_test.dart`: تحليل النماذج، ضغط الفترة الزمنية، دقة هافرساين (تم التحقق من قيمة Riyadh–Abu Dhabi الفعلية ≈708.6كم)، سيناريوهات العبور (دخول/خروج/كتم/تعطيل/عدم إعادة التنبيه/استقلالية الجيوفنسات)، وسلوك المنسّق (التفكيك الأولي، رفض الصلاحيات بدون تفعيل، التسجيل عند التثبيت الحقيقي فقط، عدم اختلاق بيانات، التفكيك الفوري عند فشل البدء).

## 5. النتائج

| الفحص | النتيجة |
|---|---|
| `flutter analyze` على الملفات المعدلة | صفر أخطاء (معلومات موجودة مسبقًا فقط) |
| اختبارات الميزة الجديدة | 22/22 أخضر |
| الانحدار الشامل (402 اختبارًا) | **402/402 أخضر** (كانت 380 قبل إضافة هذه الميزة) |
| تعديلات Firebase/Render/قواعد الحماية | لا شيء — صفر تغيير |

## 6. نقاط التكامل مع الأنظمة السابقة

- **FS-001 (Location & Geofencing):** التسجيل عبر `recordPoint` نفسه (الجدول `location_points` + outbox بمفتاح `location.updated`)، وإغلاق حلقة التنبيهات المفقودة. تحديث نضارة الموقع (LocationFreshness) يتحسن تلقائيًا بفضل الالتقاط الدوري.
- **M8 (Enforcement):** نمط الخدمة الأمامية وقناة الـ MethodChannel منسوخان من سابقتهما بدقة.
- **FS-011 (Rules & Policy Engine):** تنبيهات العبور تُسجَّل كـ `geofence_entry`/`geofence_exit` بمرجع `geofenceId` لتغذي لاحقًا سياسة التنبيهات.

## 7. ما تبقى للتحقق على جهاز حقيقي (قائمة الصدق)

1. تدفق طلب صلاحيات الموقع (whenInUse ثم Always) عبر حوارات أندرويد الفعلية.
2. ظهور الإشعار الدائم ونوع الخدمة `location` وسلوكها في الخلفية/القفل/وضع توفير الطاقة.
3. استمرار الخدمة بعد إعادة التشغيل (BootReceiver) فعليًا.
4. دقة الفترات الزمنية وتحميل البطارية.
5. سلوك Android 14+ مع قيد الخلفية الجديدة (تجربة المستخدم).

---

*هذا التقرير جزء من توثيق المشروع ولا يُعد شهادة جاهزية إنتاج على أندرويد. التحقق الحقيقي يتطلب جهازًا فعليًا.*
