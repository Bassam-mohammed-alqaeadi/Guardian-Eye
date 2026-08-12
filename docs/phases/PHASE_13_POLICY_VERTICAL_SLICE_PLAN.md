# خطة الشريحة الرأسية للمرحلة 13 — إدارة سياسة السلامة العائلية

## الهدف المحدود

تضيف هذه الشريحة للوالد إدارة **تكوين** سياسة screen-time/bedtime/custom mode: اسم، مستوى أولوية، وقت بداية/نهاية، أهداف مقيدة، تفعيل/تعطيل، وtemporary override محدود زمنيًا. تقيس الواجهة القرار الفعلي عبر `PolicyEngine` وتعرض مصدره، ثم تحفظ التغيير محليًا وتضع mutation كاملة في Outbox للمزامنة مع Firestore Emulator.

> لا تشمل الشريحة فرض منع التطبيقات أو قفل الشاشة أو قراءة Usage Stats. أي شاشة تقول إن وقت الشاشة أو bedtime “مطبّق على جهاز طفل” ستكون ادعاءً زائفًا خارج النطاق.

## تدفق الحالة

```text
Parent policy editor
  → PolicyDraft validation
  → PolicyRepository transaction
  → SQLite policies / policy_overrides
  → outbox full business event
  → OutboxSyncExecutor
  → Firestore policy / override document in Emulator
  → UI shows local/queued/synced/blocked/failure state only
```

## عقد البيانات

| الكيان | الحقول الأساسية | قواعد التحقق |
|---|---|---|
| `DigitalPolicy` | id, name, familyId, priority, enabled, startMinute, endMinute, restrictedTargets, version | اسم غير فارغ، priority غير سالب، دقائق في `[0,1439]`، هدف واحد على الأقل، منع targets فارغة |
| `TemporaryOverride` | id, familyId, target, allowed, expiresAt, createdByMemberId | target غير فارغ وexpiry مستقبلية؛ لا يدّعي الإنفاذ خارج محرك القرار |
| policy mutation | familyId, policyId, name, priority, enabled, schedule, restrictedTargets, version | payload كامل، idempotency key من outbox |
| override mutation | familyId, overrideId, target, allowed, expiresAt, createdByMemberId | payload كامل، لا يكتب UI إلى notification events |

## الصلاحيات

القواعد الحالية تسمح لمسار `families/{familyId}/policies/{policyId}` للـparent family roles فقط. تختبر الشريحة owner/parent allow، child deny، وcross-family deny. لا توسع هذه المرحلة القاعدة، ولا تخلط role الـFirebase مع `memberId` محلي مصطنع.

## واجهة المستخدم

تضاف شاشة Policy Manager من `DashboardScreen` مع:

1. قائمة سياسات حقيقية من SQLite، لا cards افتراضية.
2. empty state عندما لا توجد سياسة.
3. editor يعرض النوع القابل للتسمية (screen-time/bedtime/custom)، الوقت، priority، targets، وحالة enabled.
4. override sheet مع انتهاء زمني صريح.
5. effective-decision card يقرأ من `PolicyEngine` ويذكر `no_active_policy` أو `highest_priority_policy` أو `temporary_override`.
6. Local/queued/synced/blocked/error state مبني على Outbox، وليس وعدًا بالتسليم.
7. Arabic RTL وEnglish LTR عبر المصدر المحلي الحالي.

## الاختبارات ومعايير الأدلة

| المستوى | الاختبارات |
|---|---|
| Domain | validation، overnight schedule، priority، override expiry، effective decision |
| SQLite repository | create/update/toggle/override، transaction/outbox payload/idempotency، reload |
| Widget | empty/list/editor validation/effective decision/queued state، بلا بيانات مثال |
| Firestore Emulator | parent allow، child/cross-family deny، policy document shape وidempotency write |
| Sync executor | successful policy mutation وblocked unauthenticated behavior |

## حالات الفشل

إذا Firebase غير مهيأ، تبقى السياسة محفوظة محليًا وتعرض queue غير مرسل. إذا لم توجد authenticated identity، لا يغير executor outbox إلى synced. إذا رفض Firestore Emulator الكتابة، تعرض حالة blocked/failed الصادقة. لا يعرض UI “تم تطبيق وقت الشاشة”؛ يذكر “تم حفظ تكوين السياسة” فقط.

## خارج النطاق

لا device enforcement ولا Usage Stats، لا background worker، لا real Firebase write في اختبارات Emulator اليومية، لا FCM delivery، لا child pairing redemption، ولا تعديل بنية البيئة.
