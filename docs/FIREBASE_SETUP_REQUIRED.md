# إعداد Firebase المطلوب — Guardian Eye Pro

**الحالة الحالية:** لا يوجد في المستودع Project ID أو `.firebaserc` أو `lib/firebase_options.dart` أو `android/app/google-services.json` أو `ios/Runner/GoogleService-Info.plist`. لذلك لا يستطيع التطبيق تشغيل Firebase حقيقيًا، ويستمر `GuardianFirebaseBootstrap` في وضع fail-closed إلى أن ينفذ مالك المشروع هذه الخطوات.

> لا تضع ملف Service Account أو FCM server key أو APNs key أو كلمة مرور اختبار في Flutter أو Git. Android/iOS configuration files ليست اعتماديات إدارية، لكن تعامل معها كملفات بيئة ولا تشاركها في مستودع عام.

## الحد الأدنى قبل أول عمودية حقيقية

| الترتيب | إجراء المالك | أمر/Console محدد | النتيجة المتوقعة | التحقق |
|---:|---|---|---|---|
| 1 | اختر مشروع اختبار Firebase | Firebase Console → Create/Select Project ثم سجل `<FIREBASE_PROJECT_ID>` داخل secret manager/team vault. | Project ID معروف للمالك فقط. | Console project switcher يطابق الاسم المختار. |
| 2 | فعّل Firestore وAuth | Console → Firestore Database → Create؛ Console → Authentication → Sign-in method → Email/Password. | Firestore/Auth متاحان لحسابات الاختبار. | أنشئ حساب parent اختبار في Console أو أول تشغيل تطبيق. |
| 3 | سجل Android | Console → Project settings → Android app → package `com.guardianeye.app`؛ نزّل `google-services.json` إلى `android/app/`. | Android يطابق Firebase المشروع. | تحقق من package داخل JSON ولا تضعه في Git عام. |
| 4 | سجل iOS | Console → Project settings → iOS app → Bundle ID النهائي؛ ضع `GoogleService-Info.plist` في `ios/Runner/`. | iOS يطابق المشروع عند توفر macOS. | Xcode target يضم الملف لاحقًا. |
| 5 | ثبت CLIs محليًا | `npm install -g firebase-tools` و`dart pub global activate flutterfire_cli`. | تتوفر أوامر Firebase وFlutterFire. | `firebase --version` و`flutterfire --version`. |
| 6 | أنشئ خيارات التطبيق | من root: `flutterfire configure --project=<FIREBASE_PROJECT_ID> --platforms=android,ios`. | يولَّد `lib/firebase_options.dart` وتُحدّث المنصات عند الحاجة. | راجع diff ثم `flutter analyze`. |
| 7 | اربط CLI بالمشروع الصحيح | `firebase login` ثم `firebase use --add <FIREBASE_PROJECT_ID>`. | alias محلي فقط للمشروع المصرح به. | `firebase use` يعرض Project ID قبل أي deploy. |
| 8 | تحقق Emulator أولًا | `firebase emulators:exec --project <FIREBASE_PROJECT_ID> --only auth,firestore,functions "cd firebase/functions && npm run test:emulator && cd ../tests && npm test"`. | Auth/Firestore/Functions tests تمر بلا بيانات إنتاج. | exit code صفر ومخرجات محفوظة. |
| 9 | انشر القواعد والفهارس | `firebase deploy --only firestore:rules,firestore:indexes --project <FIREBASE_PROJECT_ID>`. | قواعد وفهارس Guardian Eye فقط منشورة. | Firestore Rules/Indexes Console ومراجعة allow/deny بحسابات اختبار. |
| 10 | انشر الدوال | `cd firebase/functions && npm ci && npm run lint && npm run build && cd ../.. && firebase deploy --only functions:guardian --project <FIREBASE_PROJECT_ID>`. | provisioning وnotification triggers منشورة. | Console → Functions وCloud Logging بلا فشل deployment. |

## تشغيل تطبيق Flutter مقابل البيئة المطلوبة

### Emulator فقط

لا تختبر client Emulator من هاتف مادي باستخدام `127.0.0.1`. مرر عنوان المضيف الذي يستطيع الهاتف الوصول إليه:

```bash
flutter run \
  --dart-define=GUARDIAN_FIREBASE_CONFIGURED=true \
  --dart-define=GUARDIAN_FIREBASE_USE_EMULATORS=true \
  --dart-define=GUARDIAN_FIREBASE_EMULATOR_HOST=<LAN_HOST_OR_10.0.2.2>
```

التحقق المطلوب هو: تسجيل parent → إنشاء family/child محليًا → Sync → Firestore Emulator UI read-back. عند توقف التطبيق، يجب أن تبقى أحداث Outbox غير المرسلة محلية ولا تتحول إلى `synced` بلا تأكيد.

### مشروع Firebase حقيقي

بعد نشر القواعد والدوال على **مشروع الاختبار المراجع فقط**:

```bash
flutter run --dart-define=GUARDIAN_FIREBASE_CONFIGURED=true
```

يجب إثبات: UID متحقق، family + membership، child، outbox، Firestore write/read-back، ورفض Family B والطلب غير المصادق عليه. لا تستخدم build flag Emulator، ولا تكتب `<FIREBASE_PROJECT_ID>` في source، ولا تخلط مشروع الاختبار بمشروع إنتاج.

## FCM وAndroid

فعّل Cloud Messaging بعد نشر الدوال واختبر التسلسل المنفصل: token stored → notification event → backend accepted → device received → displayed → tap/acknowledged. يتطلب آخر ثلاثة جهاز Android فعليًا. لا تعني Cloud Functions أو FCM API success أن المستخدم رأى الإشعار.[1]

## التراجع

إذا اختير Project ID خاطئ، نفّذ `firebase use --clear` واحذف ملفات config المحلية الخاطئة، ثم أعد FlutterFire. إن نشرت قاعدة غير صحيحة، أعد نشر النسخة المراجعة السابقة من Git؛ لا توسع القواعد مؤقتًا. إذا تعرض key أو token للكشف، ألغِه من Console ولا تحاول تنظيفه من تاريخ Git فقط.

## المراجع

[1]: https://firebase.google.com/docs/cloud-messaging/send-message "Firebase Cloud Messaging delivery semantics"
[2]: https://firebase.google.com/docs/flutter/setup "Add Firebase to a Flutter app"
[3]: https://firebase.google.com/docs/emulator-suite "Firebase Local Emulator Suite"
