# FS-004 — Screenshot & Camera Control (لقطات الشاشة والتحكم بالكاميرا): تقرير التنفيذ

**Commit:** pending (feature/design-system-integration) · **Author:** Manus AI · **Date:** 2026-08-19

> **إعلان صادق عن النطاق:** جزء من FS-004 (جلسة الشاشة الحية SC-004، التحكم بالكاميرا SC-005، جلسة الطفل النشطة SC-006، الجدولة SC-008) يعتمد على وكيل جهاز الطفل (child device agent) الذي ينفّذ capture/stream على أندرويد — هذا خارج منصة الوالد التي نبنيها. ما ينفَّذ هنا هو **كل ما يخص المنصة**: الشاشات التسع كاملة، طبقة البيانات المحلية (SQLite v18) بجداول الالتقاط والجلسات وجدول الطلبات وتاريخ الأدلة، عقد Firestore (`monitoring.*`)، جسر Firebase الحقيقي المحروس بجاهزية Firebase، والمزودات — بحيث يستقبل النظام البيانات فورًا عندما يرسلها وكيل الجهاز لاحقًا، دون أي إعادة بناء. كل شاشة تعرض الحالات الصادقة: waiting (بانتظار أول التقاطة)، empty، offline، no-agent.

## 1. المواصفة UX (SC-001 … SC-009)

| ID | الشاشة | المسار | الغرض | التركيب | الحالات الصادقة |
|---|---|---|---|---|---|
| SC-001 | لوحة المراقبة | `/monitoring/:familyId` | ملخص: أجهزة متصلة، آخر التقاطة لكل طفل، قائمة الانتظار | GuardianHeroCard + GuardianStatTiles + بطاقات أطفال GuardianStatusChip | loading / empty / offline |
| SC-002 | خط زمني اللقطات | `/monitoring/:familyId/screenshots` | التسلسل الزمني لكل العائلة، ترشيح بالطفل واليوم | قائمة grouped باليوم + GuardianCard + شريحة التاريخ | loading / empty / offline |
| SC-003 | عارض اللقطة | `/monitoring/:familyId/screenshots/:shotId` | عرض اللقطة بحجمها + بياناتها (جهاز، وقت، طلب) + إجراء تدقيق | HeroGuardianCard للصورة + قسم metadata | loading / missing (تُحذف) |
| SC-004 | جلسة الشاشة الحية | `/monitoring/:familyId/live` | طلب جلسة live لجهاز + عرض الحالة | GuardianCard حالة الجلسة + زر طلب/إنهاء + timeline الأحداث | no-agent / session-started / timeout |
| SC-005 | التحكم بالكاميرا | `/monitoring/:familyId/camera` | طلب لقطة كاميرا (أمامية) للجهاز | GuardianCard + سجل طلبات الكاميرا | no-agent / pending / delivered |
| SC-006 | جلسة الطفل النشطة | `/monitoring/:familyId/:childId/session` | كل ما يحدث الآن على جهاز طفل واحد (تطبيق نشط، نشاط آخر 30 دقيقة) | GuardianCard sections | loading / empty |
| SC-007 | تاريخ طلبات الالتقاط | `/monitoring/:familyId/requests` | سجل كل الطلبات (لقطة/كاميرا/live) بحالة كل طلب | GuardianSection timeline | loading / empty |
| SC-008 | جدولة الالتقاط | `/monitoring/:familyId/schedule` | فترات تلقائية يلتقط فيها الوكيل لقطات | GuardianCard محررات فترة + قائمة المجدولات | loading / empty |
| SC-009 | طابور مراجعة الأدلة | `/monitoring/:familyId/evidence` | لقطات/أحداث تحتاج مراجعة الوالد (علامتها evidence) | قائمة مراجعة + actions (review/dismiss) | loading / empty / done |

**قاعدة التصميم:** primitives فقط (GuardianCard/GuardianHeroCard/GuardianStatusChip/GuardianStateView/GuardianIconBadge/GuardianStatTile/GuardianSection/GuardianOfflineBanner) + نفس نمط AR/EN مع مفاتيح `mn_*`، والإذن `viewChildStatus` للقراءة و`managePolicies` للكتابة (نفس مصفوفة FS-003 دون إضافة صلاحيات جديدة).

## 2. المواصفة التقنية

### 2.1 طبقة البيانات (SQLite v18)

| الجدول | الغرض | المفاتيح |
|---|---|---|
| `monitoring_shots` | لقطات الشاشة المسلمة من الوكيل | PK(family_id, shot_id) + index family+captured_at DESC |
| `monitoring_sessions` | جلسات الشاشة الحية وطلبات الكاميرا | PK id + FK device |
| `monitoring_requests` | طلبات الالتقاط/الكاميرا/live بحالة كل طلب | PK(family_id, request_id) |
| `monitoring_schedules` | الفترات المجدولة | PK(family_id, schedule_id) |
| `monitoring_evidence_queue` | طابور مراجعة الأدلة | PK(family_id, evidence_id) |

كل جدول يحمل `sync_state TEXT NOT NULL DEFAULT 'queued'` بنفس نمط الصدق المتبع (FS-001/002/003). الترقية: `version: 18` + `if (oldVersion < 18)` في `onUpgrade`.

### 2.2 المستودع والجسر

`MonitoringRepository` (lib/data/monitoring_repository.dart): domain classes ثابتة `fromMap` (MonitoringShot, MonitoringSession, MonitoringRequest, MonitoringSchedule, MonitoringEvidence) + دوال استعلام per-family وper-child + دوال طلبات تكتب محليًا queued وتسجل audit evidence + سجل تدقيق events في جدول موحد `monitoring_requests`. جسر Firebase (lib/data/monitoring_remote_service.dart): `FirestoreMonitoringRemoteReader` محروس بـ `GuardianFirebaseBootstrap.current.isReady` مع stub `_Unavailable` عند عدم الجاهزية، ومزوّد pull يطبق النتائج محليًا بنفس نمط web/app bridges.

### 2.3 عقد Firestore

خمس حالات جديدة في `firestore_contracts.dart`: `monitoring.shot`, `monitoring.session`, `monitoring.request`, `monitoring.schedule`, `monitoring.evidence` — تكتب داخل مجموعات موجودة عبر `FirestorePaths` دون قواعد/مخطط جديد (نفس نمط FS-002/003).

### 2.4 المزودات

`monitoringRepositoryProvider` + مزودات عائلية: `monitoringShotsProvider`, `monitoringSessionsProvider`, `monitoringRequestsProvider`, `monitoringSchedulesProvider`, `monitoringEvidenceProvider`, `monitoringChildActivityProvider` — جميعها على نمط FutureProvider مع honest-error.

## 3. المواصفة الأمنية

1. **Fail-closed authorization:** كل شاشة تقرأ `FamilyRuntimeContext.can()` حصريًا — `viewChildStatus` للقراءة، `managePolicies` للطلبات والجدولة، SC-006 fail-closed إن لم يكن الوالد هو صاحب الجلسة.
2. **لا كشف معلومات عبر الأجهزة:** الشاشات تستعلم per-family مع تحقق ملكية الجهاز للـ familyId، وSC-006 مقيد بـ childId من المسار.
3. **Offline-first honesty:** الطلبات تكتب محليًا بحالة queued وتُعرض كـ pending حتى يصل دليل التسليم — لا نجاح مزيف.
4. **لا تعديل قواعد Firebase:** الكتابة داخل مجموعات موجودة بصلاحيات موجودة.
5. **خصوصية اللقطات:** اللقطات تُعامل كمحتوى حساس — لا تُعرض في أي سطح غير SC-002/003/009 المؤذن له.

## 4. الترجمة والتنقل

~75 مفتاح `mn_*` AR+EN في `AppLocalizations`. 9 مسارات جديدة في `app_router.dart` داخل ShellRoute + بطاقة دخول `monitoring` في لوحة العائلة بنفس نمط webProtection/appControl.

## 5. الإثبات والفحوصات

- اختبار جديد `test/fs004_monitoring_test.dart` (~10 اختبارات): دورة حفظ/حل اللقطات، طلبات بحالة queued، جدولة، طابور الأدلة، وجود جداول v18 ومؤشريها، ترقية v18 من v17.
- التراجع الكامل يجب أن يبقى أخضر + `flutter analyze` 0 أخطاء.
