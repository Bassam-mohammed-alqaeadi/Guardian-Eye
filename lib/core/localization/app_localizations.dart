import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;
  static const delegate = _AppLocalizationsDelegate();
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  static const _values = <String, Map<String, String>>{
    'ar': {
      'appTitle': 'Guardian Eye Pro',
      'welcome': 'حماية عائلتك بوضوح وثقة',
      'createFamily': 'إنشاء عائلة',
      'familyName': 'اسم العائلة',
      'parentName': 'اسم الوالد/الوالدة',
      'continue': 'متابعة',
      'dashboard': 'لوحة العائلة',
      'children': 'الأطفال',
      'incidentsToday': 'حوادث اليوم',
      'syncQueue': 'عمليات بانتظار المزامنة',
      'addChild': 'إضافة طفل',
      'childName': 'اسم الطفل',
      'pairDevice': 'ربط جهاز',
      'permissions': 'الأذونات',
      'noChildren': 'لم تُضف ملفات أطفال بعد.',
      'noFamily': 'ابدأ بإعداد عائلتك. لا تُنشأ أي بيانات تجريبية.',
      'offlineFirst':
          'البيانات تُحفظ محليًا أولًا، وتبقى المزامنة متوقفة حتى إعداد Firebase.',
      'pairingRequest': 'طلب ربط محلي',
      'pairingNotice':
          'هذا الطلب صالح 10 دقائق ويحتاج تحققًا خادميًا قبل منح الثقة لجهاز جديد.',
      'pairingPending': 'لا توجد جلسة ربط نشطة.',
      'generatePairing': 'إنشاء رمز ربط',
      'permissionsTitle': 'سُلّم الأذونات',
      'request': 'طلب/فتح الإعداد',
      'granted': 'ممنوح',
      'notGranted': 'غير ممنوح',
      'unsupported': 'غير متاح على هذا الجهاز',
      'settingsRequired': 'يتطلب إعدادًا يدويًا',
      'refresh': 'تحديث',
      'notification': 'الإشعارات',
      'location': 'الموقع',
      'microphone': 'الميكروفون',
      'usageStats': 'إحصاءات الاستخدام',
      'accessibility': 'إمكانية الوصول',
      'overlay': 'الظهور فوق التطبيقات',
      'screenCapture': 'التقاط الشاشة',
      'language': 'English',
      'setupRequired': 'يتطلب إعداد Firebase',
      'error': 'تعذر إتمام العملية',
      'safetyPolicies': 'سياسات الأمان',
      'managePolicies': 'إدارة السياسات',
      'noPolicies': 'لا توجد سياسات أمان بعد.',
      'createPolicy': 'إنشاء سياسة',
      'editPolicy': 'تعديل السياسة',
      'policyName': 'اسم السياسة',
      'policyTargets': 'التطبيقات أو الفئات المقيدة',
      'priority': 'الأولوية',
      'startTime': 'وقت البداية',
      'endTime': 'وقت النهاية',
      'policyEnabled': 'السياسة مفعّلة',
      'savePolicy': 'حفظ التكوين',
      'policySavedLocal': 'تم حفظ تكوين السياسة محليًا.',
      'policyExplanation': 'القرار الحالي',
      'noActivePolicy': 'لا توجد سياسة نشطة لهذا الهدف الآن.',
      'restrictedByPolicy': 'مقيد بسياسة نشطة.',
      'allowedByOverride': 'مسموح باستثناء مؤقت.',
      'temporaryOverride': 'سماح مؤقت',
      'overrideUntil': 'ينتهي في',
      'createOverride': 'إنشاء استثناء مؤقت',
      'overrideCreated': 'تم حفظ الاستثناء المؤقت محليًا.',
      'syncLocalOnly': 'محلي فقط',
      'syncQueued': 'بانتظار المزامنة',
      'syncSynced': 'متزامن',
      'syncBlocked': 'المزامنة محجوبة',
      'syncFailed': 'فشلت المزامنة',
      'policyNotDeviceEnforced':
          'هذا تكوين سياسة. لا يتم ادعاء تطبيقه على جهاز الطفل قبل التحقق من تكامل Android.',
      'video': 'فيديو',
      'social': 'تواصل اجتماعي',
      'games': 'ألعاب',
      'browser': 'متصفح',
      'validationRequired':
          'أكمل الحقول المطلوبة واختر هدفًا واحدًا على الأقل.',
      'retry': 'إعادة المحاولة',
      'childDeviceStatus': 'حالة جهاز الطفل',
      'noChildDevices': 'لا توجد أجهزة أطفال مرتبطة محليًا بعد.',
      'childEnforcementNotice':
          'تعرض هذه الشاشة حالة السياسة والتجهيز محليًا. لا تمثل دليلاً على أن Android حظر تطبيقًا.',
      'usageStatsReady': 'إحصاءات الاستخدام متاحة للملاحظة عند الطلب.',
      'usageStatsConsentRequired':
          'يلزم منح الوصول من إعدادات Android قبل الملاحظة.',
      'capabilityNotReady': 'تعذر التحقق من جاهزية القدرة على هذا الجهاز.',
      'deviceUnlinked': 'غير مرتبط',
      'devicePairingPending': 'الربط قيد الانتظار',
      'deviceEnrolled': 'تم التسجيل — بانتظار الاسترداد',
      'deviceActive': 'نشط محليًا',
      'deviceOffline': 'دون اتصال — تستخدم آخر سياسة صالحة',
      'deviceRestricted': 'طلبت السياسة تقييدًا',
      'deviceSuspended': 'معلّق',
      'deviceRevoked': 'أُلغي الجهاز',
      'deviceRecovering': 'قيد الاسترداد',
      'policyVersion': 'أدنى إصدار سياسة',
      'lastValidPolicy': 'آخر سياسة صالحة',
      'lastEvaluation': 'آخر تقييم',
      'enforcementDecision': 'قرار النطاق',
      'statusReason': 'سبب الحالة',
      'noData': 'لا توجد بيانات',
      'noEvaluation': 'لم يكتمل تقييم بعد'
      ,'dailyLimitMinutes': 'الحد اليومي بالدقائق (اختياري)'
      ,'policyPackageId': 'معرّف حزمة Android للقياس (مثال: com.google.android.youtube)'
      ,'addPolicyTarget': 'إضافة هدف'
      ,'dailyLimitRequiresPackage': 'يتطلب الحد اليومي معرّف حزمة Android واحدًا على الأقل.'
      ,'screenTimeToday': 'استخدام اليوم'
      ,'screenTimeEvaluate': 'قياس الاستخدام وتقييم السياسة'
      ,'screenTimeNoUsage': 'لا توجد ملاحظات استخدام محلية لهذا اليوم.'
      ,'screenTimeMeasured': 'تم القياس محليًا؛ لا يعني ذلك أن Android حظر تطبيقًا.'
      ,'enforcementStatus': 'حالة الإنفاذ'
      ,'permissionRequired': 'يلزم منح الوصول'
      ,'enforcementUnsupported': 'الإنفاذ غير مدعوم على هذا الجهاز'
      ,'familyMembers': 'أعضاء الأسرة'
      ,'inviteMember': 'دعوة عضو'
      ,'memberRole': 'الدور'
      ,'memberStatus': 'الحالة'
      ,'memberDevices': 'أجهزة مرتبطة'
      ,'noMembers': 'لا يوجد أعضاء ظاهرون في هذه العائلة بعد.'
      ,'pendingInvitations': 'دعوات معلقة'
      ,'invitationPending': 'بانتظار القبول'
      ,'invitationAccepted': 'مقبولة'
      ,'invitationExpired': 'منتهية الصلاحية'
      ,'invitationCancelled': 'ملغاة'
      ,'cancelInvitation': 'إلغاء الدعوة'
      ,'revokeAccess': 'إلغاء الوصول'
      ,'changeRole': 'تغيير الدور'
      ,'notConnected': 'غير متصل'
      ,'inviteAdult': 'دعوة بالغ'
      ,'targetEmail': 'البريد الإلكتروني للمستلم'
      ,'proposedRole': 'الدور المقترح'
      ,'sendInvitation': 'حفظ الدعوة'
      ,'invitationCreated': 'حُفظت الدعوة محليًا وتنتظر المزامنة. لا يوجد إرسال بريد في هذه المرحلة.'
      ,'acceptInvitation': 'قبول الدعوة'
      ,'rejectInvitation': 'رفض الدعوة'
      ,'invitationExpiry': 'تنتهي في'
      ,'roleParent': 'والد/والدة'
      ,'roleCoParent': 'والد/والدة مشارك'
      ,'roleOwner': 'مالك العائلة'
      ,'roleChild': 'طفل'
      ,'roleSpouse': 'شريك'
      ,'statusActive': 'نشط'
      ,'statusInvited': 'تمت الدعوة'
      ,'statusRevoked': 'أُلغي الوصول'
      ,'confirmRevoke': 'هل تريد إلغاء وصول هذا العضو؟ سيُلغى وصول أجهزته المرتبطة محليًا.'
      ,'confirm': 'تأكيد'
      ,'cancel': 'إلغاء'
      ,'invitationActionUnavailable': 'يلزم أن يفتح المستلم الدعوة من حسابه الموثق بعد مزامنتها.'
      ,'actorVerificationRequired': 'تُعرض البيانات المحلية للقراءة فقط حتى يتم التحقق من حساب Firebase وعضوية الأسرة المطابقة على الخادم.'
      ,'dailySafety': 'السلامة اليومية'
      ,'safetyTimeline': 'الخط الزمني للسلامة'
      ,'exceptionUnsupportedNotice': 'طلبات الاستثناء تُحفظ وتُراجع محليًا فقط. لا يوجد تسليم فعلي للتطبيق على الجهاز قبل تكامل Android.'
      ,'reviewRequests': 'مراجعة الطلبات'
      ,'noRequests': 'لا توجد طلبات استثناء.'
      ,'requestDuration': 'المدة المطلوبة'
      ,'requestReason': 'سبب الطلب'
      ,'reasonDetail': 'تفاصيل السبب'
      ,'reasonHomework': 'واجب مدرسي'
      ,'reasonSchoolAssignment': 'مهمة دراسية'
      ,'reasonFamilyActivity': 'نشاط عائلي'
      ,'reasonImportantCommunication': 'تواصل مهم'
      ,'reasonOther': 'أخرى'
      ,'requestPending': 'بانتظار مراجعة الوالد'
      ,'requestApproved': 'تمت الموافقة على الطلب'
      ,'requestDenied': 'تم رفض الطلب'
      ,'requestExpired': 'انتهت صلاحية الطلب'
      ,'requestCancelled': 'أُلغي الطلب'
      ,'approveRequest': 'موافقة'
      ,'denyRequest': 'رفض'
      ,'requestDecisionSaved': 'تم حفظ القرار محليًا وينتظر المزامنة.'
      ,'requestSavedLocal': 'حُفظ الطلب محليًا وينتظر مراجعة الوالد والمزامنة.'
      ,'requestAdditionalTime': 'طلب وقت إضافي'
      ,'submitRequest': 'إرسال الطلب'
      ,'temporaryExceptionUntil': 'ينتهي السماح في'
      ,'currentPolicy': 'السياسة الحالية'
      ,'pendingRequests': 'طلبات معلقة'
      ,'activeException': 'استثناء نشط'
      ,'noActiveException': 'لا يوجد استثناء نشط'
      ,'notMeasuredYet': 'لم يُقاس بعد'
      ,'childPolicy': 'سياسة الطفل'
      ,'childPolicyExplanation': 'هذه القاعدة تساعد عائلتك على إدارة الوقت بوضوح. لا تعني تلقائيًا أن Android حظر تطبيقًا.'
      ,'remainingTime': 'الوقت المتبقي'
      ,'policyConfigured': 'السياسة مُعدّة'
      ,'policyDelivered': 'تم إعداد السياسة'
      ,'approvalNature': 'تُقدَّم الموافقة كإعفاء مؤقت من السياسة فقط، ولا تعني أن التطبيق حُظر أو أُلغي حظره على الجهاز.'
    },
    'en': {
      'appTitle': 'Guardian Eye Pro',
      'welcome': 'Protect your family with clarity and trust',
      'createFamily': 'Create family',
      'familyName': 'Family name',
      'parentName': 'Parent name',
      'continue': 'Continue',
      'dashboard': 'Family dashboard',
      'children': 'Children',
      'incidentsToday': 'Incidents today',
      'syncQueue': 'Queued sync operations',
      'addChild': 'Add child',
      'childName': 'Child name',
      'pairDevice': 'Pair device',
      'permissions': 'Permissions',
      'noChildren': 'No child profiles have been added.',
      'noFamily': 'Start by setting up your family. No sample data is created.',
      'offlineFirst':
          'Data is stored locally first. Sync remains unavailable until Firebase is configured.',
      'pairingRequest': 'Local pairing request',
      'pairingNotice':
          'This request is valid for 10 minutes and needs server verification before a new device can be trusted.',
      'pairingPending': 'No active pairing session.',
      'generatePairing': 'Generate pairing code',
      'permissionsTitle': 'Permission ladder',
      'request': 'Request / open settings',
      'granted': 'Granted',
      'notGranted': 'Not granted',
      'unsupported': 'Unavailable on this device',
      'settingsRequired': 'Manual setup required',
      'refresh': 'Refresh',
      'notification': 'Notifications',
      'location': 'Location',
      'microphone': 'Microphone',
      'usageStats': 'Usage statistics',
      'accessibility': 'Accessibility',
      'overlay': 'Display over apps',
      'screenCapture': 'Screen capture',
      'language': 'العربية',
      'setupRequired': 'Firebase setup required',
      'error': 'Unable to complete the action',
      'safetyPolicies': 'Safety policies',
      'managePolicies': 'Manage policies',
      'noPolicies': 'No safety policies have been created yet.',
      'createPolicy': 'Create policy',
      'editPolicy': 'Edit policy',
      'policyName': 'Policy name',
      'policyTargets': 'Restricted apps or categories',
      'priority': 'Priority',
      'startTime': 'Start time',
      'endTime': 'End time',
      'policyEnabled': 'Policy enabled',
      'savePolicy': 'Save configuration',
      'policySavedLocal': 'Policy configuration saved locally.',
      'policyExplanation': 'Current decision',
      'noActivePolicy': 'No active policy for this target right now.',
      'restrictedByPolicy': 'Restricted by an active policy.',
      'allowedByOverride': 'Allowed by a temporary override.',
      'temporaryOverride': 'Temporary allow',
      'overrideUntil': 'Expires',
      'createOverride': 'Create temporary override',
      'overrideCreated': 'Temporary override saved locally.',
      'syncLocalOnly': 'Local only',
      'syncQueued': 'Queued for sync',
      'syncSynced': 'Synced',
      'syncBlocked': 'Sync blocked',
      'syncFailed': 'Sync failed',
      'policyNotDeviceEnforced':
          'This is policy configuration. It is not claimed to be enforced on a child device before Android integration is verified.',
      'video': 'Video',
      'social': 'Social',
      'games': 'Games',
      'browser': 'Browser',
      'validationRequired':
          'Complete the required fields and select at least one target.',
      'retry': 'Retry',
      'childDeviceStatus': 'Child device status',
      'noChildDevices': 'No child devices are linked locally yet.',
      'childEnforcementNotice':
          'This screen shows local policy and readiness state. It is not evidence that Android blocked an application.',
      'usageStatsReady':
          'Usage statistics are ready for on-demand observation.',
      'usageStatsConsentRequired':
          'Grant access in Android Settings before observation can run.',
      'capabilityNotReady':
          'Capability readiness could not be verified on this device.',
      'deviceUnlinked': 'Unlinked',
      'devicePairingPending': 'Pairing pending',
      'deviceEnrolled': 'Enrolled — recovery pending',
      'deviceActive': 'Locally active',
      'deviceOffline': 'Offline — using last valid policy',
      'deviceRestricted': 'Policy requests restriction',
      'deviceSuspended': 'Suspended',
      'deviceRevoked': 'Device revoked',
      'deviceRecovering': 'Recovering',
      'policyVersion': 'Minimum policy version',
      'lastValidPolicy': 'Last valid policy',
      'lastEvaluation': 'Last evaluation',
      'enforcementDecision': 'Domain decision',
      'statusReason': 'Status reason',
      'noData': 'No data',
      'noEvaluation': 'No evaluation yet'
      ,'dailyLimitMinutes': 'Daily limit in minutes (optional)'
      ,'policyPackageId': 'Android package ID to measure (for example: com.google.android.youtube)'
      ,'addPolicyTarget': 'Add target'
      ,'dailyLimitRequiresPackage': 'A daily limit requires at least one Android package ID.'
      ,'screenTimeToday': 'Today’s usage'
      ,'screenTimeEvaluate': 'Measure usage and evaluate policy'
      ,'screenTimeNoUsage': 'No local usage observations for today.'
      ,'screenTimeMeasured': 'Measured locally; this does not mean Android blocked an app.'
      ,'enforcementStatus': 'Enforcement status'
      ,'permissionRequired': 'Permission is required'
      ,'enforcementUnsupported': 'Enforcement is unsupported on this device'
      ,'familyMembers': 'Family members'
      ,'inviteMember': 'Invite member'
      ,'memberRole': 'Role'
      ,'memberStatus': 'Status'
      ,'memberDevices': 'Linked devices'
      ,'noMembers': 'No family members are visible yet.'
      ,'pendingInvitations': 'Pending invitations'
      ,'invitationPending': 'Pending acceptance'
      ,'invitationAccepted': 'Accepted'
      ,'invitationExpired': 'Expired'
      ,'invitationCancelled': 'Cancelled'
      ,'cancelInvitation': 'Cancel invitation'
      ,'revokeAccess': 'Revoke access'
      ,'changeRole': 'Change role'
      ,'notConnected': 'Not connected'
      ,'inviteAdult': 'Invite an adult'
      ,'targetEmail': 'Recipient email'
      ,'proposedRole': 'Proposed role'
      ,'sendInvitation': 'Save invitation'
      ,'invitationCreated': 'The invitation is saved locally and awaits sync. Email delivery is not part of this phase.'
      ,'acceptInvitation': 'Accept invitation'
      ,'rejectInvitation': 'Reject invitation'
      ,'invitationExpiry': 'Expires'
      ,'roleParent': 'Parent'
      ,'roleCoParent': 'Co-parent'
      ,'roleOwner': 'Family owner'
      ,'roleChild': 'Child'
      ,'roleSpouse': 'Spouse'
      ,'statusActive': 'Active'
      ,'statusInvited': 'Invited'
      ,'statusRevoked': 'Access revoked'
      ,'confirmRevoke': 'Revoke this member’s access? Their associated devices will also be revoked locally.'
      ,'confirm': 'Confirm'
      ,'cancel': 'Cancel'
      ,'invitationActionUnavailable': 'The recipient must open the invitation from their authenticated account after it synchronizes.'
      ,'actorVerificationRequired': 'Local data is read-only until the Firebase account and matching family membership are verified on the server.'
      ,'dailySafety': 'Daily safety'
      ,'safetyTimeline': 'Safety timeline'
      ,'exceptionUnsupportedNotice': 'Exception requests are stored and reviewed locally only. No actual app delivery exists on the device before Android integration.'
      ,'reviewRequests': 'Review requests'
      ,'noRequests': 'No exception requests.'
      ,'requestDuration': 'Requested duration'
      ,'requestReason': 'Request reason'
      ,'reasonDetail': 'Reason detail'
      ,'reasonHomework': 'Homework'
      ,'reasonSchoolAssignment': 'School assignment'
      ,'reasonFamilyActivity': 'Family activity'
      ,'reasonImportantCommunication': 'Important communication'
      ,'reasonOther': 'Other'
      ,'requestPending': 'Awaiting parent review'
      ,'requestApproved': 'Request approved'
      ,'requestDenied': 'Request denied'
      ,'requestExpired': 'Request expired'
      ,'requestCancelled': 'Request cancelled'
      ,'approveRequest': 'Approve'
      ,'denyRequest': 'Deny'
      ,'requestDecisionSaved': 'Decision saved locally and queued for sync.'
      ,'requestSavedLocal': 'Request saved locally. It awaits parent review and sync.'
      ,'requestAdditionalTime': 'Request additional time'
      ,'submitRequest': 'Submit request'
      ,'temporaryExceptionUntil': 'Allowance expires at'
      ,'currentPolicy': 'Current policy'
      ,'pendingRequests': 'Pending requests'
      ,'activeException': 'Active exception'
      ,'noActiveException': 'No active exception'
      ,'notMeasuredYet': 'Not measured yet'
      ,'childPolicy': 'Child policy'
      ,'childPolicyExplanation': 'Approval creates a temporary policy allowance. It is not evidence that Android blocked or unblocked an app.'
      ,'remainingTime': 'Remaining time'
      ,'policyConfigured': 'Policy configured'
      ,'policyDelivered': 'Policy configured'
      ,'approvalNature': 'Approval creates a temporary policy allowance. It is not evidence that Android blocked or unblocked an app.'
    },
  };
  String t(String key) => _values[locale.languageCode]?[key] ?? key;
  String translate(String key) => t(key);
  bool get isRtl => locale.languageCode == 'ar';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) =>
      AppLocalizations._values.containsKey(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
