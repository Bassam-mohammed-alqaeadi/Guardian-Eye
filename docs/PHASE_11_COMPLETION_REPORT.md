# ملحق المرحلة 11 — سياسة Emulator-first

هذا الملحق يحدّث تقرير المرحلة 11 في `docs/phases/PHASE_11_COMPLETION_REPORT.md` ولا يستبدل أدلة Firebase الحقيقية السابقة.

| العنصر | مستوى الدليل | النتيجة |
|---|---|---|
| `manus-guardian` Auth/Firestore/Rules/Indexes | VERIFIED ON REAL BACKEND | يبقى موثقًا وغير معدل. |
| نموذج environment صريح | VERIFIED LOCALLY | development/test يتطلبان Emulator host، والـreal/production يتطلبان approvals منفصلة. |
| Firestore authorization Emulator | VERIFIED IN EMULATOR | 8 اختبارات ناجحة، تشمل role وmember UID immutability. |
| Functions Emulator | VERIFIED IN EMULATOR | 2 اختبارات ناجحة: Incident/SOS contracts وchild provisioning/replay rejection. |
| FCM device delivery | BLOCKED | Emulator لا يثبت التسليم؛ Functions production يتطلب Blaze وجهازًا حقيقيًا. |
| APK/device runtime | BLOCKED | لا APK من sandbox ولا جهاز متصل. |

استخدم `LOCAL_FIREBASE_DEVELOPMENT.md` للتطوير والاختبارات اليومية، و`REAL_FIREBASE_VALIDATION.md` للـsmoke tests المقصودة فقط.
