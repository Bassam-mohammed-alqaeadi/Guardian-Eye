# Human Action Required — Guardian Eye Pro

## Android build and physical validation

The source contains an Android host project and explicit consent-oriented permission declarations. To complete device validation, install JDK 17 and Android SDK platform-tools, build-tools, platform `android-36`, and the NDK version requested by Flutter. Then run:

```bash
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Use a physical Android device to test permission denial, Usage Stats settings, Accessibility settings, overlay consent, background recovery, Doze, notification delivery, pairing revocation, and offline-to-online synchronization. Do not enable device-owner, media projection, or accessibility monitoring without a reviewed consent flow and current Play policy assessment.

## iPhone build and device validation

iOS compilation and signing require macOS. On a macOS machine, install Xcode, CocoaPods, Flutter, and an Apple Developer signing team. Register the iOS bundle identifier, then run:

```bash
flutter pub get
cd ios && pod install && cd ..
flutter build ios --debug --no-codesign
```

For device installation, configure signing in Xcode or App Store Connect. Validate the camera pairing prompt, location prompt, microphone prompt, Firebase delivery, secure storage, notifications, and only Apple-supported transparent functionality. iOS does not grant system-wide app blocking, hidden capture, or Android-style accessibility/device-owner control.

## Firebase and AI artifacts

Create a Firebase project, register `com.guardianeye.app` and the chosen iOS bundle identifier, and place the platform configuration files outside source control. Run FlutterFire configuration to generate a real `firebase_options.dart`; review and deploy the included Firestore and Storage rule templates before enabling sync. Provide a reviewed TensorFlow Lite model artifact, labels, licensing, model card, input contract, confidence thresholds, and test corpus before enabling any safety inference.

### Firebase Phase 7 setup

1. Create or select a Firebase project, then enable **Email/Password** (and only any approved additional provider) in Firebase Authentication.
2. Register the Android package `com.guardianeye.app` and the final iOS bundle identifier. Download `google-services.json` and `GoogleService-Info.plist` into their required platform locations without committing them.
3. Install the required CLIs, then generate application options from the selected project:

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
flutterfire configure --project=<FIREBASE_PROJECT_ID> --platforms=android,ios
```

4. استخدم ملف `firebase.json` الموجود بالفعل من جذر المشروع؛ لا تُعد تنفيذ `firebase init` لأنه قد يستبدل إعدادات القواعد والدوال الموجودة. اربط الاسم المستعار، ثم افحص مصدر الدوال والقواعد محليًا:

```bash
firebase use --add <FIREBASE_PROJECT_ID>
cd firebase/functions && npm ci && npm run lint && cd ../..
firebase emulators:exec --project <FIREBASE_PROJECT_ID> --only firestore "cd firebase/tests && npm ci && npm test"
```

5. بعد مراجعة نتائج Emulator، انشر فقط القواعد والفهارس ومصدر الدوال ذي الرمز البرمجي `guardian`. لا تنشر قبل مراجعة هوية الطفل، حفظ الأسر، والأثر الخصوصي:

```bash
firebase deploy --only firestore:rules,firestore:indexes,functions:guardian
```

6. شغّل بعد ذلك Auth وFirestore وFunctions Emulator مع تكوين Flutter غير إنتاجي. نفّذ كل حالة في `docs/backend/FIREBASE_EMULATOR_TEST_PLAN.md`، وأضف تنفيذ عقد الربط الخلفي للطفل/الجهاز، واحفظ المخرجات وأعد ضبط البيانات بين الحالات. لا توجّه أي اختبار إلى Firebase الإنتاجي.

```bash
firebase emulators:start --only auth,firestore,functions
```

7. نفّذ وسيط pairing-broker مميّزًا قبل منح جهاز الطفل حق إنشاء `incidents` أو `sos`: يجب أن يتحقق من جلسة الاقتران ذات الاستخدام الواحد، ويربط Firebase UID للطفل بعضوه وجهازه في معاملة واحدة، ويرفض إعادة التشغيل. بعده فقط اختبر دورة التطبيق Flutter ↔ Emulator الكاملة.

8. فعّل Cloud Messaging. لأجهزة iOS ارفع مفتاح مصادقة APNs في Firebase Cloud Messaging وفعّل صلاحية Push المطلوبة في ملف Apple signing. اختبر تسجيل الرمز، تحديثه، قبول الدالة الخلفية للطلب، التسليم في المقدمة/الخلفية، والتأكيد على أجهزة فعلية كحالات منفصلة. تستهلك دوال الخلفية `notification_events` وتستخدم Admin SDK داخل بيئة الخادم فقط؛ لا تضع اعتماديات Firebase Admin أو مفاتيح FCM الخادمية في Flutter. [1] [2]

## Release and business integrations

Obtain signing keys, configure App Store Connect and Google Play products, add a public privacy policy and data-safety disclosures, configure APNs/FCM, and obtain merchant credentials plus official API documentation before enabling Haseb, Jawal Pay, or OneCash adapters. No credentials may be added to the Flutter application source.

## بوابة المرحلة الثامنة: تحقق Firebase الحقيقي والجهاز الفعلي

**شرط البداية:** لا يحتوي المستودع الحالي على Firebase project alias أو `firebase_options.dart` أو ملفات Google الخاصة بـAndroid/iOS. لا تنفذ أي أمر نشر على مشروع تجريبي مشترك أو إنتاجي قبل مراجعة القواعد ودوران Emulator. احفظ مخرجات كل خطوة في قناة هندسية خاصة ولا تسجل رموز FCM أو أكواد pairing أو محتوى الطفل.

| # | الإجراء الدقيق | الأمر أو إجراء Console | النتيجة المتوقعة | طريقة التحقق | التراجع/حل المشكلة |
|---:|---|---|---|---|---|
| 1 | إنشاء/اختيار المشروع | في Firebase Console أنشئ مشروعًا باسم تشغيلي، واختر Billing account إذا كانت Functions v2 مطلوبة. | يظهر **Project ID** ثابت يملكه الفريق. | انسخ Project ID إلى سجل أسرار الفريق، لا إلى Git. | إن اختير مشروع خاطئ، أزل alias المحلي فقط بـ`firebase use --clear` ولا تحذف مشروعًا يحوي بيانات. |
| 2 | تقييد الوصول | في Google Cloud IAM امنح أقل دور لازم للمطور واحتفظ بمالكَين بشريين على الأقل. | لا يملك تطبيق Flutter أي دور إداري. | راجع IAM audit log والأدوار. | أزل الدور الزائد فورًا؛ بدّل مفتاح حساب خدمة مكشوف إن وُجد. |
| 3 | إنشاء Firestore | Firebase Console → Build → Firestore Database → Create database، واختر المنطقة بعد مراجعة متطلبات الإقامة. | قاعدة Firestore متاحة بالموقع المختار. | Console يعرض Database ID `(default)` والمنطقة. | المنطقة لا تتغير بعد الإنشاء؛ إن كانت خاطئة أوقف قبل إدخال بيانات حساسة وصعّد القرار. |
| 4 | تفعيل Auth | Firebase Console → Authentication → Sign-in method → فعّل **Email/Password** فقط ما لم يعتمد مزود آخر رسميًا. | يصبح إنشاء/دخول حساب الاختبار ممكنًا. | أنشئ حساب اختبار منفصل أو استخدم Emulator أولًا. | عطّل المزود غير المعتمد وأزل حسابات الاختبار عند الانتهاء. |
| 5 | تسجيل Android | Project settings → Your apps → Android، package هو `com.guardianeye.app`، ثم نزّل `google-services.json` إلى `android/app/`. | يطابق التطبيق Android Firebase المشروع الصحيح. | `flutterfire configure` وGradle يحددان التطبيق دون mismatch. | احذف الملف المحلي غير الصحيح؛ لا ترفعه إلى مصدر عام. |
| 6 | تسجيل iOS | Project settings → Your apps → iOS، أدخل Bundle ID النهائي، ثم ضع `GoogleService-Info.plist` في `ios/Runner/`. | يتطابق iOS Firebase مع signing النهائي. | Xcode target يحتوي الملف وFirebase initializes على iPhone. | احذف plist غير الصحيح؛ لا تدّع نجاح iOS من Linux. |
| 7 | توليد FlutterFire | من جذر المشروع: `dart pub global activate flutterfire_cli` ثم `flutterfire configure --project=<FIREBASE_PROJECT_ID> --platforms=android,ios`. | يولَّد `lib/firebase_options.dart` وتُحدّث ملفات المنصة اللازمة. | راجع diff: لا Admin SDK أو سر خادمي، ثم `flutter analyze`. | أعد الأمر مع Project ID الصحيح؛ لا تعدّل identifiers يدويًا إذا فشل. |
| 8 | ربط Firebase CLI | `npx firebase-tools login` ثم `npx firebase-tools use --add <FIREBASE_PROJECT_ID>`. | ينشأ alias محلي مرتبط فقط بالمشروع المقصود. | `npx firebase-tools projects:list` و`npx firebase-tools use`. | `npx firebase-tools use --clear` يلغي alias المحلي؛ لا تشارك refresh token. |
| 9 | فحص Emulator قبل النشر | `npx firebase-tools emulators:exec --project <FIREBASE_PROJECT_ID> --only auth,firestore,functions "cd firebase/functions && npm run test:emulator && cd ../tests && npm test"`. | تمر اختبارات provisioning وincident/SOS والقواعد قبل الإنتاج. | exit code `0` وحفظ المخرجات؛ لا يلامس الأمر بيانات الإنتاج. | صحح الاختبار أو القاعدة أولًا؛ لا تتجاوز الاختبار بـ`--force`. |
| 10 | نشر القواعد والفهارس | بعد مراجعة PR: `npx firebase-tools deploy --only firestore:rules,firestore:indexes --project <FIREBASE_PROJECT_ID>`. | تنشر القواعد والفهارس المحددة فقط. | Console → Firestore Rules وIndexes، ثم اختبارات allow/deny بحسابات اختبار. | أعد نشر نسخة القواعد المراجعة السابقة من Git؛ لا تفتح القواعد مؤقتًا. |
| 11 | نشر الدوال | `cd firebase/functions && npm ci && npm run lint && npm run build && cd ../.. && npx firebase-tools deploy --only functions:guardian --project <FIREBASE_PROJECT_ID>`. | تنشر callable provisioning وtriggers تحت codebase `guardian`. | Console → Functions وCloud Logging بلا أخطاء deployment. | انشر إصدارًا سابقًا صالحًا أو عطّل trigger المحدد؛ لا تضع Admin credential في Flutter. |
| 12 | اختبار Flutter ↔ Emulator | بعد ملفات FlutterFire: `flutter run --dart-define=GUARDIAN_FIREBASE_CONFIGURED=true --dart-define=GUARDIAN_FIREBASE_USE_EMULATORS=true --dart-define=GUARDIAN_FIREBASE_EMULATOR_HOST=<LAN_HOST>`؛ استخدم `10.0.2.2` لمحاكي Android على نفس المضيف أو IP الشبكة لجهاز فعلي. | التطبيق يهيئ Firebase ويستخدم Auth/Firestore Emulator فقط. | سجّل الدخول، أنشئ عائلة/طفل، اضغط Sync، واقرأ الوثائق من Emulator UI. | إن اتصل بتكوين حقيقي أوقف التطبيق، راجع dart-defines وامسح بيانات الاختبار. |
| 13 | إثبات الخلفية الحقيقية | شغّل build بلا `GUARDIAN_FIREBASE_USE_EMULATORS` ومع `GUARDIAN_FIREBASE_CONFIGURED=true` بعد نشر القواعد. | Auth UID حقيقي → family → primary membership → child → Outbox → Firestore write/read-back. | وثّق Project ID (منقحًا)، UID hash، document IDs منقحة، وقت، ونتيجة read-back. | أوقف الاختبار أو أعد قواعد النسخة السابقة عند `permission-denied` غير متوقع؛ لا تحذف بيانات الأسرة بصلاحيات عامة. |
| 14 | إعداد FCM وAPNs | فعّل Cloud Messaging. في iOS ارفع APNs Auth Key وفعّل Push Notifications في Apple signing. | يمكن للخادم فقط محاولة FCM بعد token device حقيقي. | اختبر منفصلًا: token stored، notification event، backend accepted، received، displayed، acknowledged. | ألغِ APNs key المعرّض أو token غير صالح؛ لا تفسر `backendAccepted` على أنه عرض للمستخدم. |
| 15 | جهاز Android/iOS فعلي | Android: ثبّت SDK/ADB وابنِ `flutter build apk --debug` ثم `adb install -r build/app/outputs/flutter-apk/app-debug.apk`. iOS: استخدم macOS/Xcode وجهازًا مسجلاً. | APK/IPA يثبت ويُشغّل على جهاز محدد. | سجّل الطراز/OS/build hash ونتائج offline/recovery/Doze/push tap. | أزل build الاختبار من الجهاز وامسح بياناته؛ لا ترفع الإصدار للمتجر قبل مراجعة الخصوصية وسياسات المتجر. |

### مصفوفة إثبات الإشعارات

| الحالة | مصدر الدليل المقبول | لا تعني |
|---|---|---|
| `Notification Requested` | incident/SOS محلي وOutbox | أنه وصل Firestore. |
| `Notification Event Created` | Firestore document أو Functions Emulator | أن FCM قَبِل الرسالة. |
| `FCM Accepted` | استجابة Admin SDK مع `acceptedCount > 0` | أن الجهاز استلم أو عرض إشعارًا. |
| `Device Received` و`User Saw Notification` | سجل جهاز فعلي/لقطة مسجلة بعد موافقة المستخدم | أن المستخدم أقر الحدث. |
| `Acknowledged` | حدث تطبيق منفصل من المستخدم المصرح | أن الإشعار أُرسل مرة أخرى أو حُلّ الحادث. |

## Checklist المرحلة التاسعة — لا تُعلّم بندًا بلا دليل

- [x] تثبيت Android SDK 36 وBuild Tools 36.0.0 وplatform-tools وNDK 28.2.13676358 وCMake 3.22.1 على عامل البناء.
- [x] تثبيت JDK 17 وتوجيه Flutter إليه؛ يظهر Android toolchain صالحًا في `flutter doctor -v`.
- [x] تصحيح registrant Android قديم غير متوافق مع Workmanager وتمكين AndroidX وcore-library desugaring.
- [ ] اختيار Firebase Project ID اختبار ومراجع من مالك المشروع.
- [ ] تسجيل الدخول إلى Firebase CLI وربط alias بالمشروع المختار فقط.
- [ ] تفعيل Email/Password Authentication وFirestore في Console.
- [ ] تسجيل Android package `com.guardianeye.app` ووضع `google-services.json` الصحيح محليًا.
- [ ] تسجيل iOS bundle ID ووضع `GoogleService-Info.plist` الصحيح على macOS.
- [ ] تشغيل `flutterfire configure` وتدقيق `firebase_options.dart` المولد.
- [ ] نشر Firestore rules/indexes إلى Project ID المراجع بعد Emulator evidence.
- [ ] نشر `functions:guardian` والتحقق من Cloud Logging بلا أخطاء.
- [ ] إكمال Flutter → Emulator vertical slice مع عنوان host صحيح للجهاز أو AVD.
- [ ] إنتاج APK arm64/release على عامل بذاكرة كافية وتسجيل hash والحجم و`aapt` metadata.
- [ ] توصيل جهاز Android أو AVD حتى يظهر في `adb devices -l`.
- [ ] تثبيت APK وتشغيله وتسجيل device model/API/ABI ونتيجة launch.
- [ ] إنشاء parent وchild test identities حقيقية، وتنفيذ family/Outbox/Firestore read-back.
- [ ] تسجيل FCM token مادي وإثبات requested/event/accepted/received/displayed/tap كحالات منفصلة.
- [ ] اختبار offline ثم network recovery وprocess death/force-stop/Doze المنفذ فعليًا فقط.
- [ ] تنفيذ iOS/APNs على macOS وiPhone منفصلين؛ Linux لا يثبت هذا المسار.

## بوابة المرحلة العاشرة — تفويض Firebase CLI للمشروع المراجع

| ما يحتاجه المالك | أين | القيمة أو الإجراء الدقيق | لماذا | كيف سيتحقق النظام بعده |
|---|---|---|---|---|
| تفويض Firebase CLI | نفس بيئة التطوير التي تحوي `/home/ubuntu/guardian_eye_flutter`. | **مكتمل:** Firebase CLI authorized وProject ID `manus-guardian` matched. | مكّن توليد FlutterFire ونشر Firestore واختبارات backend. | Evidence recorded in `REAL_FIREBASE_VALIDATION.md`. |
| تفعيل Blaze لنشر Guardian Functions | Firebase Console → `manus-guardian` → Usage and billing. | راجع التكلفة ثم فعّل خطة Blaze للمشروع إذا وافق المالك؛ لا ترسل بطاقة أو بيانات دفع في المحادثة. | Cloud Build وArtifact Registry مطلوبان لنشر Cloud Functions v2؛ CLI أوقف `functions:guardian` قبل النشر. | أعيد تشغيل deploy المحصور ثم `functions:list` وأختبر provisioning وnotification events بدون ادعاء FCM device delivery. |

## المراجع

[1]: https://firebase.google.com/docs/cloud-messaging "Firebase Cloud Messaging documentation"
[2]: https://firebase.google.com/docs/admin/setup "Firebase Admin SDK setup"
