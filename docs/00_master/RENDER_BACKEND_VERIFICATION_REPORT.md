# تقرير التحقق من خدمة Render والـ Backend

**التاريخ:** 2026-08-19 | **الخدمة:** `guardian-eye-djg8.onrender.com` (مشروع Firebase: `manus-guardian`)

## 1. النتيجة الإجمالية

خدمة Render **حية وتعمل بالكامل في بيئة الإنتاج**. تم إجراء تحقق حقيقي عبر الشبكة (HTTP) ضد الخدمة المنشورة مباشرة، باستخدام مصادقة Firebase ID Token حقيقية من مستخدم اختبار موثق، وأكملنا **الدورة الكاملة للإصدار والاسترداد (Issue → Redeem) بنجاح** — من طلب مصادقة خاطئ حتى إنشاء سجل حقيقي في Firestore.

## 2. نتائج الاختبارات الحية (Real Production Probes)

| الاختبار | الطلب | النتيجة |
|---|---|---|
| صحة الخدمة | `GET /` | **HTTP 200** → `{"status":"ok","service":"guardian-backend"}` |
| غلاف المصادقة | `POST /api/provision-child` بدون Authorization | **HTTP 401** → `unauthenticated: Missing or invalid Authorization header` |
| التحقق من رمز Firebase | نفس المسار + رمز Bearer **مزيف** | **HTTP 401** → `invalid_token: ID token verification failed` |
| التحقق من العائلة | نفس المسار + رمز حقيقي + عائلة وهمية | **HTTP 404** → `family_not_found: Family does not exist` |
| الإصدار (Issue) | رمز حقيقي + العائلة الحقيقية `ff70cf2b-…` | **HTTP 201** → `pairingId` + كود من 6 أرقام + تاريخ انتهاء (10 دقائق) |
| الاسترداد بكود خاطئ | `POST /api/redeem-child` بكود `999999` | **HTTP 400** → `invalid_code: Provisioning code is invalid` |
| الاسترداد بالكود الصحيح | الكود الصحيح الصادر | **HTTP 200** → `state: enrolled` مع `deviceId` و`targetMemberId` |

أي أن الخلفية تتحقق فعلًا من رمز Firebase ID عبر Firebase Admin SDK، وتبحث في Firestore عن العائلة، وتصدر جلسة اقتران موثوقة، وترفض الأكواد الخاطئة، وتسجل الاسترداد الناجح في معاملات ذرية.

## 3. ملاحظات مهمة على البنية

**مصدر خدمة Render ليس داخل هذا المستودع.** لا يوجد `render.yaml` أو أي كود خادم في مستودع `Guardian-Eye` — الخدمة منشورة من مستودع/بيئة منفصلة على Render. هذا يعني أن أي تعديل على منطق الخادم (إضافة مسارات جديدة مثل مراقبة الشاشة لـ FS-004) يحتاج تحديث تلك البيئة المنفصلة.

**دوال Firebase Cloud Functions في المستودع غير منشورة.** الملف `firebase/functions/src/index.ts` يحتوي على تنفيذي `onCall` (createChildDeviceProvisioning / redeemChildDeviceProvisioning) لكنهما **لم يُنشرا** لأن Cloud Build وArtifact Registry يتطلبان خطة Blaze (موثق في `docs/04_backend/FIREBASE_REAL_ENVIRONMENT_SETUP.md`). خدمة Render REST هي المسار التشغيلي الوحيد للإصدار عن بُعد، وكود Flutter (RemoteProvisioningService) يستدعيها مباشرة عبر `POST /api/provision-child` و`POST /api/redeem-child`.

**تطابق العقد بين الخادم والتطبيق:** خدمة Render تستجيب بالضبط بما يتوقعه التطبيق — أسماء الحقول `pairingId/provisioningCode/expiresAt` في الإصدار و`state:'enrolled'/deviceId/targetMemberId` في الاسترداد، ورموز الأخطاء (`unauthenticated`، `invalid_token`، `family_not_found`، `invalid_code`) مطابقة جميعها لخرائط الخطأ في `remote_provisioning_service.dart`. لا توجد فجوة عقد هنا.

## 4. بيانات اختبار أُنشئت في الإنتاج

اكتمال دورة الاسترداد الناجحة كتب سجلات حقيقية في Firestore (بغرض التحقق):

- جلسة اقتران: `families/ff70cf2b-…/device_pairings/df2abbab-…` (تنتهي صلاحيتها تلقائيًا خلال 10 دقائق)
- مستند عضو: `families/…/members/{childUid}` — `role: child`، `displayName: Render Live Test Child`
- مستند جهاز: `families/…/devices/render-live-test-device` — `role: childDevice`

**هذه سجلات اختبار يمكن حذفها يدويًا** من وحدة Firestore Console دون أي تأثير على التطبيق، أو يمكن اعتبارها سجلًا حيًا لدليل العمل. الجلسة (pairing) تنتهي ذاتيًا خلال دقائق.

## 5. سلامة المستودع بعد الفحص

- `flutter analyze`: **0 أخطاء**، 9 تحذيرات موجودة مسبقًا فقط
- الاختبارات: **293/293 أخضر** (282 أساسية + 11 FS-004)
- لا تغييرات في الكود ناتجة عن هذا الفحص — كان فحصًا خارجيًا فقط

## 6. التوصيات

1. **اختبار APK على جهاز حقيقي** (Firebase Test Lab) هو الخطوة التالية المطلوبة — كل الفحوصات الحالية هي وحدة ووظائف REST، وسلوك Android الحقيقي (تصاريح، خدمات خلفية، M8 Enforcement) ما زال يحتاج جهازًا فعليًا.
2. **نشر دوال Firebase Functions** يرفع درجة الاحتياط: عند تفعيل خطة Blaze تصبح دوال `onCall` داخل repo متاحة كبديل عن Render، لكن هذا خارج نطاق المرحلة الحالية (قرار تسوية/ميزانية خاص بك).
3. **استضافة كود خادم Render داخل مستودع موحد** تسهّل المراجعة والتسليم لأي وكيل (arena.ai) وتبقي كل التاريخ في مكان واحد.
4. يمكن تنظيف سجلات الاختبار (البند 4) من Firestore Console عند الفراغ.
