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
      'settings': 'الإعدادات',
      'accountSession': 'الحساب والجلسة',
      'languagePreference': 'اللغة',
      'appPreferences': 'تفضيلات التطبيق',
      'signOut': 'تسجيل الخروج',
      'signedInAs': 'مسجّل الدخول',
      'notSignedIn': 'غير مسجّل الدخول',
      'settingsSaved': 'حُفظت الإعدادات',
      'settingsLanguageChanged': 'تغيّرت لغة التطبيق',
      'settingsLanguageAr': 'العربية',
      'settingsLanguageEn': 'English',
      'goHome': 'العودة إلى الشاشة الرئيسة',
      'pageNotFound': 'الصفحة غير موجودة',
      'pageNotFoundBody': 'تعذّر العثور على هذه الصفحة. يمكنك العودة إلى الشاشة الرئيسة بأمان.',
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
      'syncNow': 'مزامنة الآن',
      'syncInProgress': 'جارٍ المزامنة…',
      'dataSync': 'مزامنة البيانات',
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
      'createdFamily': 'تاريخ الإنشاء',
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
      ,'approvalNature': 'تُقدَّم الموافقة كإعفاء مؤقت من السياسة فقط، ولا تعني أن التطبيق حُظر أو أُلغي حظره على الجهاز.',
      'familyIdentity': 'هوية العائلة',
      'childOverview': 'نظرة على الأطفال',
      'safetySignal': 'إشارة السلامة',
      'safeToday': 'لا توجد حوادث نشطة اليوم',
      'attentionRequired': 'توجد حوادث نشطة تحتاج انتباهك',
      'noDevicesLinked': 'لا يوجد جهاز مربوط بعد',
      'todayScreenTime': 'وقت الشاشة اليوم',
      'screenTimeUnavailable': 'غير متوفر اليوم',
      'lastSync': 'آخر مزامنة',
      'dataFresh': 'حديثة',
      'syncUnavailable': 'المزامنة غير متاحة',
      'childDetails': 'تفاصيل الطفل',
      'childContext': 'سياق الطفل',
      'lastSyncAt': 'آخر مزامنة',
      'lastSyncNever': 'لم تتم المزامنة بعد',
      'noRecentIncidents': 'لا توجد حوادث حديثة تحتاج انتباهك',
      'familyLevelIncidents': 'حوادث على مستوى الأسرة تهم بيئة هذا الطفل',
      'activitySummary': 'ملخص النشاط',
      'comingSoon': 'قريبًا',
      'comingSoonSection': 'إمكانات قادمة — غير متوفرة بعد',
      'backToDashboard': 'العودة إلى لوحة التحكم',
      'severityLow': 'منخفضة',
      'severityMedium': 'متوسطة',
      'severityHigh': 'عالية',
      'severityCritical': 'حرجة',
      'categoryViolence': 'عنف',
      'categoryAdultContent': 'محتوى للبالغين',
      'categoryDangerousContent': 'محتوى خطير',
      'categoryBullying': 'تنمر',
      'categorySuspiciousLanguage': 'لغة مشبوهة',
      'bedtime': 'وضع النوم',
      'webFiltering': 'تصفية المحتوى',
      'locationTracking': 'تتبع الموقع',
      'deviceControls': 'أدوات الجهاز',
      'weeklyReports': 'تقارير أسبوعية',
      'sosAlerts': 'تنبيهات طوارئ',
      'safetyActions': 'إجراءات السلامة',
      'sosTitle': 'نداء استغاثة',
      'sosConfirmation': 'هل تريد إرسال نداء استغاثة إلى الوالدين الآن؟',
      'sosDescription': 'يُرسل هذا نداء استغاثة فوريًا إلى الوالدين في العائلة.',
      'sendSos': 'إرسال نداء الاستغاثة',
      'sosStored': 'تم حفظ نداء الاستغاثة محليًا وهو بانتظار المزامنة.',
      'syncResult': 'نتيجة المزامنة',
      'aiMonitoring': 'المراقبة الذكية',
      'redeemDevice': 'ربط جهاز الطفل',
      'redeemTitle': 'ربط هذا الجهاز بالعائلة',
      'enterPairingCode': 'أدخل رمز الربط المكوّن من 6 أرقام',
      'redeemConfirm': 'ربط الجهاز',
      'redeemValidating': 'جارٍ التحقق من الرمز…',
      'redeemSuccess': 'تم ربط الجهاز بنجاح',
      'redeemSuccessBody': 'الجهاز مرتبط الآن بالطفل المختار. قد تستغرق المزامنة مع الخادم بعض الوقت إذا لم يكن اتصال الشبكة متاحًا.',
      'codeInvalid': 'الرمز غير صالح',
      'codeInvalidBody': 'تأكد من إدخال الرمز المكوّن من 6 أرقام بشكل صحيح، أو اطلب رمزًا جديدًا من جهاز الوالد.',
      'codeExpired': 'انتهت صلاحية الرمز',
      'codeExpiredBody': 'رموز الربط صالحة لمدة 10 دقائق فقط. اطلب رمزًا جديدًا من جهاز الوالد.',
      'codeLocked': 'تم إيقاف هذا الرمز',
      'codeLockedBody': 'تجاوزت المحاولات الفاشلة الحد المسموح به. اطلب رمزًا جديدًا من جهاز الوالد.',
      'codeAlreadyUsed': 'تم استخدام هذا الرمز مسبقًا',
      'codeAlreadyUsedBody': 'كل رمز ربط صالح لاستخدام واحد فقط. اطلب رمزًا جديدًا من جهاز الوالد.',
      'alreadyEnrolled': 'هذا الجهاز مرتبط بالفعل',
      'alreadyEnrolledBody': 'لجهاز الطفل رابط نشط مع هذه العائلة. يمكن للوالد إلغاء الربط القديم أولًا ثم إصدار رمز جديد.',
      'unauthorizedRedeem': 'غير مصرح بالربط',
      'unauthorizedRedeemBody': 'لا يمكن ربط هذا الجهاز في الوقت الحالي. تحقّق من الحساب وطلب الربط من جهاز الوالد.',
      'networkUnavailable': 'الشبكة غير متاحة',
      'networkUnavailableBody': 'تم حفظ الربط محليًا وسيكتمل عند عودة الاتصال بالخادم. حالة المزامنة: بانتظار المزامنة.',
      'pendingSync': 'بانتظار المزامنة',
      'retryRedeemLater': 'إعادة المحاولة لاحقًا',
      'unknownRedeemError': 'تعذّر إكمال الربط',
      'unknownRedeemErrorBody': 'حدث خطأ غير متوقع. تحقّق من الشبكة ثم أعد المحاولة، أو اطلب رمزًا جديدًا.',
      'provisioningServerError': 'تعذّر إنشاء رمز الربط على الخادم. تحقّق من الاتصال وأعد المحاولة.',
      'redeemPairingCode': 'إدخال رمز الربط',
      'pairForChild': 'جهاز الطفل',
      'noChildToPair': 'لم يتم إنشاء ملف طفل بعد.',
      'selectChild': 'اختر الطفل',
      'pairingExpiry': 'الصلاحية',
      'pairingExpiryExpiresAt': 'تنتهي الصلاحية بعد {minutes} دقيقة',
      'pairingRedeemHint': 'أدخل هذا الرمز على جهاز الطفل أو امسح الرمز ضوئيًا',
      'linkedDevice': 'الجهاز المرتبط',
      'deviceLifecycle': 'حالة الجهاز',
      'unlinkDevice': 'إلغاء ربط الجهاز',
      'unlinkConfirmTitle': 'إلغاء ربط هذا الجهاز؟',
      'unlinkConfirmBody': 'يُفقد الجهاز الثقة ويُسجّل كملغٍ. يُحفظ التغيير محليًا ويُرسل عند عودة الاتصال.',
      'unlinkCancel': 'إبقاء الربط',
      'unlinkConfirmed': 'أُلغي ربط الجهاز — بانتظار المزامنة',
      'unauthorizedActor': 'غير مصرح',
      'unauthorizedActorBody': 'هذا الإجراء متاح للوالد فقط. سجّل الدخول بحساب والِد من هذه العائلة.',
      'linkedStatus': 'مرتبط',
      'redemptionPendingHint': 'الربط في انتظار اكتمال المزامنة مع الخادم قبل منح الثقة الكاملة.',
      // — M5 Family Management (append-only) —
      'familyOverview': 'نظرة عامة على العائلة',
      'familyStatus': 'حالة العائلة',
      'familyStatusActive': 'نشطة',
      'memberCount': 'عدد الأعضاء',
      'childCount': 'عدد الأطفال',
      'deviceCount': 'عدد الأجهزة',
      'roleUpdateTitle': 'تحديث الدور',
      'roleUpdated': 'تم تحديث دور العضو محليًا وبانتظار المزامنة',
      'roleUpdateOwnerOnly': 'تغيير الأدوار متاح للمالك فقط',
      'invitationHistory': 'سجل الدعوات',
      'invitationAll': 'الكل',
      'invitationHistoryEmpty': 'لا يوجد سجل دعوات بعد.',
      'invitationCancelledConfirm': 'إلغاء هذه الدعوة نهائيًا؟',
      'revokeConfirmBody': 'سيُفقد العضو إمكانية الوصول وتُحجب أجهزته المرتبطة. يُحفظ التغيير محليًا ويُرسل عند عودة الاتصال.',
      'memberRevoked': 'أُلغي وصول العضو محليًا — بانتظار المزامنة',
      'offlineHint': 'أنت بلا اتصال. التغييرات محفوظة محليًا وتُرسل تلقائيًا عند عودة الاتصال.',
      'onlineAgain': 'عاد الاتصال — جاري إرسال التغييرات المحفوظة.',
      'inviteMemberHint': 'تُدعى الأدوار البالغة فقط: والد أو والد مشارك.',
      'invitedPending': 'دعوة معلقة — تنتظر قبول المستلم بعد المزامنة',
      'memberSavedLocal': 'حُفظ محليًا',
      'memberPendingSync': 'بانتظار المزامنة',
      'memberSynced': 'متزامن',
      'memberSyncFailed': 'فشلت المزامنة',
      'familyNotFound': 'لا توجد عائلة مسجلة بعد',
      'familyNotFoundHint': 'أنشئ عائلتك أولًا من لوحة التحكم الرئيسة.'
      // — M6 Screen-Time Administration (append-only) —
      ,'screenTimeAdmin': 'وقت الشاشة'
      ,'screenTimeManage': 'إدارة وقت الشاشة'
      ,'policiesSummary': 'السياسات'
      ,'policiesActiveCount': 'سياسة نشطة'
      ,'policiesActiveCountPlural': 'سياسات نشطة'
      ,'effectiveDecisionNow': 'القرار الفعّال الآن'
      ,'decisionSampleNote': 'معاينة حسب السياسة الحالية — ليست فرضًا فعليًا على الجهاز'
      ,'noPoliciesForChild': 'لا توجد سياسات لهذا الطفل بعد'
      ,'addFirstPolicy': 'أضف أول سياسة'
      ,'policySchedule': 'الجدول'
      ,'policyActiveStatus': 'نشطة'
      ,'policyInactiveStatus': 'غير مفعّلة'
      ,'enablePolicy': 'تفعيل'
      ,'disablePolicy': 'إيقاف السياسة'
      ,'deletePolicyUnavailable': 'التعطيل هو الطريقة المعتمدة لإيقاف السياسة — لا يوجد حذف دائم في هذه المرحلة'
      ,'policySavedSuccessfully': 'حُفظت السياسة محليًا وبانتظار المزامنة'
      ,'policyEditedSuccessfully': 'عُدّلت السياسة محليًا وبانتظار المزامنة'
      ,'policyDisabledNotice': 'أوقفت السياسة — ستتوقف عن كونها نشطة من الآن'
      ,'policyEnabledNotice': 'فُعّلت السياسة — ستعود للتحكم في الأوقات المحددة'
      ,'policyValidationFailed': 'أكمل الحقول المطلوبة وتحقق من الجدول الزمني'
      ,'policyNameEmpty': 'اسم السياسة مطلوب'
      ,'policyScheduleInvalid': 'التوقيت غير صالح'
      ,'noLimit': 'بدون حد يومي'
      ,'minutesShort': 'دقيقة'
      ,'hoursMinutesFormat': '{hours}س {minutes}د'
      ,'hoursMinutesZero': '0س 0د'
      ,'overrideGrant': 'سماح مؤقت'
      ,'overrideGrantFor': 'سماح مؤقت لـ {target}'
      ,'overrideDuration': 'مدة السماح'
      ,'overrideExpiresAt': 'ينتهي السماح في {time}'
      ,'activeOverride': 'استثناء مؤقت نشط حتى {time}'
      ,'noActiveOverrides': 'لا توجد استثناءات مؤقتة نشطة'
      ,'exceptionRequestsTitle': 'طلبات الاستثناء'
      ,'pendingExceptionBadge': 'طلب معلق'
      ,'pendingExceptionBadgePlural': 'طلبات معلقة'
      ,'noPendingExceptions': 'لا توجد طلبات استثناء معلقة'
      ,'exceptionRequestDetails': 'تفاصيل الطلب'
      ,'exceptionApprove': 'موافقة'
      ,'exceptionDeny': 'رفض'
      ,'exceptionApproved': 'تمت الموافقة محليًا — استثناء مؤقت أُنشئ وبانتظار المزامنة'
      ,'exceptionDenied': 'تم الرفض محليًا وبانتظار المزامنة'
      ,'exceptionReviewFailed': 'تعذر مراجعة الطلب — حاول مجددًا'
      ,'exceptionReviewTitle': 'طلب وقت إضافي'
      ,'exceptionChildWantsTime': 'يطلب وقتًا إضافيًا لـ {target}'
      ,'overrideMinutes15': '15 دقيقة'
      ,'overrideMinutes30': '30 دقيقة'
      ,'overrideMinutes60': 'ساعة واحدة'
      ,'overrideMinutes120': 'ساعتان'
      ,'overrideMinutes240': '4 ساعات'
      ,'overrideSavedLocally': 'حُفظ الاستثناء المؤقت محليًا وبانتظار المزامنة'
      ,'overrideGrantUnavailable': 'يحتاج إنشاء استثناء مؤقت حساب والِد موثقًا لهذه العائلة'
      ,'effectiveDecisionRestricted': 'مقيد'
      ,'effectiveDecisionAllowed': 'مسموح'
      ,'effectiveDecisionNoPolicy': 'لا توجد سياسة نشطة'
      ,'effectiveDecisionOverride': 'سماح مؤقت نشط'
      ,'childUnlinkedPolicyNotice': 'لا يوجد جهاز مرتبط لهذا الطفل — تُدار السياسات لكنها لا تُسلَّم قبل ربط الجهاز'
      ,'screenTimeAdminUnavailable': 'إدارة وقت الشاشة غير متاحة لك'
      ,'screenTimeAdminUnavailableBody': 'يحتاج هذا القسم صلاحية إدارة السياسات. سجّل الدخول بحساب والِد من هذه العائلة أو اطلب من الوالد مراجعته'
      ,'m7UsageToday': 'استخدام اليوم'
      ,'m7NoObservation': 'لا توجد بيانات قياس لهذا اليوم'
      ,'m7StaleData': 'بيانات قديمة'
      ,'m7OfflineCached': 'محفوظة بدون اتصال'
      ,'m7SyncPending': 'بانتظار المزامنة'
      ,'m7SyncFailed': 'فشل تسليم المزامنة'
      ,'m7PermissionRequired': 'يلزم إذن إحصاءات الاستخدام'
      ,'m7PermissionRequiredBody': 'السماح بإحصاءات الاستخدام لقياس وقت الشاشة اليومي لهذا الجهاز فقط'
      ,'m7PermissionDenied': 'الإذن مرفوض'
      ,'m7PermissionDeniedBody': 'رُفض إذن إحصاءات الاستخدام، ولا يمكن قياس وقت الشاشة قبل الموافقة عليه من إعدادات النظام'
      ,'m7Unsupported': 'القياس غير مدعوم على هذا الجهاز'
      ,'m7UnsupportedBody': 'لا يوفّر هذا الجهاز إحصاءات استخدام التطبيقات. يمكن قياس وقت الشاشة عبر تطبيق مخصص بدلًا منها'
      ,'m7GrantUsageAccess': 'منح الوصول'
      ,'m7UsageAccessPurpose': 'لقياس وقت الشاشة اليومي لهذا الجهاز فقط'
      ,'m7WithinLimit': 'ضمن الحد المسموح'
      ,'m7NearLimit': 'قريب من الحد'
      ,'m7OverLimit': 'تجاوز الحد'
      ,'m7NoActivePolicy': 'لا توجد سياسة نشطة'
      ,'m7UnableToEvaluate': 'تعذّر التقييم'
      ,'m7BreakdownTitle': 'التفاصيل حسب الفئة'
      ,'m7TotalScreenTime': 'إجمالي وقت الشاشة'
      ,'m7UsageUnavailable': 'القياس غير متاح حاليًا'
      ,'m7UsageUnavailableBody': 'تعذّر جلب بيانات الاستخدام لهذا الجهاز الآن. أعد المحاولة أو تحقق من ربط الجهاز'
      ,'m7LastObserved': 'آخر قياس'
      ,'m7MeasuredZero': 'صفر دقائق مقاسة'
      ,'m7Observing': 'جارٍ القياس'
      ,'m7ConditionDetected': 'حالة سياسة مكتشفة'
      ,'m7RefreshMeasurement': 'تحديث القياس'
      ,'m7UsageMinutes': '{count} دقيقة'
      ,'m8EnforcementTitle': 'حالة الحماية'
      ,'m8EnforcementSubtitle': 'التزام الجهاز بقواعد وقت الشاشة'
      ,'m8StateNotRequested': 'لم يُطلب تفعيل الحماية'
      ,'m8StateNotRequestedDetail': 'لم يُتَّخذ بعدُ قرار بتطبيق حدٍّ على هذا الجهاز اليوم.'
      ,'m8StatePermissionRequired': 'الحماية بانتظار الإذن'
      ,'m8StatePermissionRequiredDetail': 'يتطلب تفعيل الحماية صلاحيات نظام لم تُمنح بعد.'
      ,'m8StateEvaluationReady': 'جاهز للتقييم'
      ,'m8StateEvaluationReadyDetail': 'لا يوجد قيد ساري الآن؛ السياسة جاهزة للتطبيق إذا تغيَّر الاستخدام.'
      ,'m8StateEnforcementApplied': 'تم التطبيق والتحقق'
      ,'m8StateEnforcementAppliedDetail': 'أكَّد النظام على الجهاز أن الحدّ قيد التفعيل، ولا يلغيه فقدان الاتصال.'
      ,'m8StateEnforcementFailed': 'تعذَّر التطبيق'
      ,'m8StateEnforcementFailedDetail': 'حاول النظام تطبيق الحدّ على الجهاز ولم يتمكَّن من تأكيد ذلك.'
      ,'m8StatePolicyStale': 'السياسة بحاجة إلى تحديث'
      ,'m8StatePolicyStaleDetail': 'السياسة المحلّية قديمة جدًّا ولا يُتَّخذ بموجبها أي إجراء؛ اطلب إعادة المزامنة.'
      ,'m8StateDeviceOffline': 'الجهاز غير متاح'
      ,'m8StateDeviceOfflineDetail': 'لا يمكن التواصل مع الجهاز حاليًّا؛ تُحفظ آخر حالة معروفة.'
      ,'m8StateUnsupported': 'غير مدعوم على هذا الجهاز'
      ,'m8StateUnsupportedDetail': 'إصدار النظام لا يتيح هذه الإمكانية.'
      ,'m8StatePermissionDenied': 'الإذن غير ممنوح'
      ,'m8StatePermissionDeniedDetail': 'سُحبت صلاحية النظام المطلوبة؛ الحماية معلَّقة حتى تمنحها مجددًّا.'
      ,'m8RefreshEnforcement': 'تحديث الحالة'
      ,'m8EnforcementUnavailable': 'حالة الحماية غير متاحة حاليًّا.'
      ,'m8NotVerified': 'بانتظار التأكيد'
      ,'m8VerificationNote': 'طُلب الإجراء ولا يزال بانتظار تأكيد النظام على الجهاز.'
      ,'m8SyncedNow': 'آخر مزامنة: الآن'
      ,'m8SyncPending': 'بانتظار المزامنة'
      ,'m8SyncFailed': 'فشلت المزامنة'
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
      'settings': 'Settings',
      'accountSession': 'Account & session',
      'languagePreference': 'Language',
      'appPreferences': 'App preferences',
      'signOut': 'Sign out',
      'signedInAs': 'Signed in',
      'notSignedIn': 'Not signed in',
      'settingsSaved': 'Settings saved',
      'settingsLanguageChanged': 'App language changed',
      'settingsLanguageAr': 'العربية',
      'settingsLanguageEn': 'English',
      'goHome': 'Go to home',
      'pageNotFound': 'Page not found',
      'pageNotFoundBody': 'This page could not be found. You can return safely to the home screen.',
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
      'syncNow': 'Sync now',
      'syncInProgress': 'Syncing…',
      'dataSync': 'Data sync',
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
      'createdFamily': 'Created',
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
      ,'approvalNature': 'Approval creates a temporary policy allowance. It is not evidence that Android blocked or unblocked an app.',
      'familyIdentity': 'Family identity',
      'childOverview': 'Children overview',
      'childContext': 'Child context',
      'lastSyncAt': 'Last sync',
      'lastSyncNever': 'Never synced',
      'noRecentIncidents': 'No recent incidents need your attention',
      'familyLevelIncidents': 'Family-level incidents concerning this child',
      'activitySummary': 'Activity summary',
      'comingSoon': 'Coming soon',
      'comingSoonSection': 'Upcoming capabilities — not yet available',
      'backToDashboard': 'Back to dashboard',
      'severityLow': 'Low',
      'severityMedium': 'Medium',
      'severityHigh': 'High',
      'severityCritical': 'Critical',
      'categoryViolence': 'Violence',
      'categoryAdultContent': 'Adult content',
      'categoryDangerousContent': 'Dangerous content',
      'categoryBullying': 'Bullying',
      'categorySuspiciousLanguage': 'Suspicious language',
      'bedtime': 'Bedtime mode',
      'webFiltering': 'Content filtering',
      'locationTracking': 'Location tracking',
      'deviceControls': 'Device controls',
      'weeklyReports': 'Weekly reports',
      'sosAlerts': 'Emergency alerts',
      'safetyActions': 'Safety actions',
      'sosTitle': 'SOS alert',
      'sosConfirmation': 'Send an SOS alert to the parents now?',
      'sosDescription': 'This sends an immediate SOS alert to the family parents.',
      'sendSos': 'Send SOS',
      'sosStored': 'SOS stored locally and queued for sync.',
      'syncResult': 'Sync result',
      'aiMonitoring': 'Smart monitoring',
      'safetySignal': 'Safety signal',
      'safeToday': 'No active incidents today',
      'attentionRequired': 'Active incidents need your attention',
      'noDevicesLinked': 'No device linked yet',
      'todayScreenTime': 'Screen time today',
      'screenTimeUnavailable': 'Unavailable today',
      'lastSync': 'Last sync',
      'dataFresh': 'Up to date',
      'syncUnavailable': 'Sync unavailable',
      'childDetails': 'Child details',
      'redeemDevice': 'Link child device',
      'redeemTitle': 'Link this device to your family',
      'enterPairingCode': 'Enter the 6-digit pairing code',
      'redeemConfirm': 'Link device',
      'redeemValidating': 'Checking the code…',
      'redeemSuccess': 'Device linked successfully',
      'redeemSuccessBody': 'The device is now linked to the chosen child. Sync with the server may take a few moments if the network is unavailable.',
      'codeInvalid': 'Code is invalid',
      'codeInvalidBody': 'Check that you entered the 6-digit code correctly, or ask the parent device for a new code.',
      'codeExpired': 'Code has expired',
      'codeExpiredBody': 'Pairing codes are valid for 10 minutes only. Ask the parent device for a new code.',
      'codeLocked': 'This code has been locked',
      'codeLockedBody': 'Too many failed attempts. Ask the parent device for a new code.',
      'codeAlreadyUsed': 'This code was already used',
      'codeAlreadyUsedBody': 'Each pairing code can only be redeemed once. Ask the parent device for a new code.',
      'alreadyEnrolled': 'This device is already linked',
      'alreadyEnrolledBody': 'A child device is already linked to this family. The parent can revoke the old link first, then issue a new code.',
      'unauthorizedRedeem': 'Not authorized to link',
      'unauthorizedRedeemBody': 'This device cannot be linked right now. Verify the account and request a new code from the parent device.',
      'networkUnavailable': 'Network unavailable',
      'networkUnavailableBody': 'The link was saved locally and will complete when the server connection returns. Sync state: pending synchronization.',
      'pendingSync': 'Pending synchronization',
      'retryRedeemLater': 'Retry later',
      'unknownRedeemError': 'Unable to complete the link',
      'unknownRedeemErrorBody': 'An unexpected error occurred. Check your network and try again, or ask for a new code.',
      'provisioningServerError': 'Could not create the pairing code on the server. Check your connection and try again.',
      'redeemPairingCode': 'Enter pairing code',
      'pairForChild': 'Child device',
      'noChildToPair': 'No child profile has been created yet.',
      'selectChild': 'Choose a child',
      'pairingExpiry': 'Valid until',
      'pairingExpiryExpiresAt': 'Expires in {minutes} minutes',
      'pairingRedeemHint': 'Enter this code on the child device, or scan the QR code',
      'linkedDevice': 'Linked device',
      'deviceLifecycle': 'Device status',
      'unlinkDevice': 'Unlink device',
      'unlinkConfirmTitle': 'Unlink this device?',
      'unlinkConfirmBody': 'The device loses trust and is recorded as revoked. The change is saved locally and sent when connectivity returns.',
      'unlinkCancel': 'Keep linked',
      'unlinkConfirmed': 'Device unlinked — pending synchronization',
      'unauthorizedActor': 'Not authorized',
      'unauthorizedActorBody': 'This action is available to a parent only. Sign in with a parent account from this family.',
      'linkedStatus': 'Linked',
      'redemptionPendingHint': 'The link is waiting to finish syncing with the server before it is fully trusted.',
      // — M5 Family Management (append-only) —
      'familyOverview': 'Family overview',
      'familyStatus': 'Family status',
      'familyStatusActive': 'Active',
      'memberCount': 'Members',
      'childCount': 'Children',
      'deviceCount': 'Devices',
      'roleUpdateTitle': 'Change role',
      'roleUpdated': 'Member role updated locally — pending sync',
      'roleUpdateOwnerOnly': 'Role changes are available to the family owner only',
      'invitationHistory': 'Invitation history',
      'invitationAll': 'All',
      'invitationHistoryEmpty': 'No invitation history yet.',
      'invitationCancelledConfirm': 'Cancel this invitation permanently?',
      'revokeConfirmBody': 'The member loses access and their linked devices are blocked. The change is saved locally and sent when connectivity returns.',
      'memberRevoked': 'Member access revoked locally — pending sync',
      'offlineHint': 'You are offline. Changes are saved locally and sent automatically when connectivity returns.',
      'onlineAgain': 'Back online — sending saved changes.',
      'inviteMemberHint': 'Only adult roles can be invited: parent or co-parent.',
      'invitedPending': 'Invitation pending — awaiting recipient acceptance after sync',
      'memberSavedLocal': 'Saved locally',
      'memberPendingSync': 'Pending sync',
      'memberSynced': 'Synced',
      'memberSyncFailed': 'Sync failed',
      'familyNotFound': 'No family registered yet',
      'familyNotFoundHint': 'Create your family first from the main dashboard.'
      // — M6 Screen-Time Administration (append-only) —
      ,'screenTimeAdmin': 'Screen time'
      ,'screenTimeManage': 'Manage screen time'
      ,'policiesSummary': 'Policies'
      ,'policiesActiveCount': 'active policy'
      ,'policiesActiveCountPlural': 'active policies'
      ,'effectiveDecisionNow': 'Effective decision now'
      ,'decisionSampleNote': 'Preview under the current policy — not an enforcement claim on the device'
      ,'noPoliciesForChild': 'No policies for this child yet'
      ,'addFirstPolicy': 'Add first policy'
      ,'policySchedule': 'Schedule'
      ,'policyActiveStatus': 'Active'
      ,'policyInactiveStatus': 'Inactive'
      ,'enablePolicy': 'Enable'
      ,'disablePolicy': 'Disable policy'
      ,'deletePolicyUnavailable': 'Disabling is the supported way to pause a policy — no permanent delete in this phase'
      ,'policySavedSuccessfully': 'Policy saved locally — pending sync'
      ,'policyEditedSuccessfully': 'Policy edited locally — pending sync'
      ,'policyDisabledNotice': 'Policy disabled — it no longer applies'
      ,'policyEnabledNotice': 'Policy enabled — it now governs the scheduled window'
      ,'policyValidationFailed': 'Complete the required fields and fix the schedule'
      ,'policyNameEmpty': 'Policy name is required'
      ,'policyScheduleInvalid': 'The schedule is invalid'
      ,'noLimit': 'No daily limit'
      ,'minutesShort': 'min'
      ,'hoursMinutesFormat': '{hours}h {minutes}m'
      ,'hoursMinutesZero': '0h 0m'
      ,'overrideGrant': 'Temporary allow'
      ,'overrideGrantFor': 'Temporarily allow {target}'
      ,'overrideDuration': 'Allowance duration'
      ,'overrideExpiresAt': 'Allowance expires at {time}'
      ,'activeOverride': 'Active temporary allowance until {time}'
      ,'noActiveOverrides': 'No active temporary allowances'
      ,'exceptionRequestsTitle': 'Exception requests'
      ,'pendingExceptionBadge': 'pending request'
      ,'pendingExceptionBadgePlural': 'pending requests'
      ,'noPendingExceptions': 'No pending exception requests'
      ,'exceptionRequestDetails': 'Request details'
      ,'exceptionApprove': 'Approve'
      ,'exceptionDeny': 'Deny'
      ,'exceptionApproved': 'Approved locally — a temporary allowance was created and queued for sync'
      ,'exceptionDenied': 'Denied locally — pending sync'
      ,'exceptionReviewFailed': 'The request could not be reviewed — try again'
      ,'exceptionReviewTitle': 'Time extension request'
      ,'exceptionChildWantsTime': 'is asking for more time for {target}'
      ,'overrideMinutes15': '15 minutes'
      ,'overrideMinutes30': '30 minutes'
      ,'overrideMinutes60': '1 hour'
      ,'overrideMinutes120': '2 hours'
      ,'overrideMinutes240': '4 hours'
      ,'overrideSavedLocally': 'Temporary allowance saved locally — pending sync'
      ,'overrideGrantUnavailable': 'Granting an allowance requires a verified parent account for this family'
      ,'effectiveDecisionRestricted': 'Restricted'
      ,'effectiveDecisionAllowed': 'Allowed'
      ,'effectiveDecisionNoPolicy': 'No active policy'
      ,'effectiveDecisionOverride': 'Temporary allowance active'
      ,'childUnlinkedPolicyNotice': 'No device is linked for this child — policies are managed but not delivered until a device is linked'
      ,'screenTimeAdminUnavailable': 'Screen-time management unavailable'
      ,'screenTimeAdminUnavailableBody': 'This section requires policy management permission. Sign in with a parent account from this family or ask a parent to manage it'
      ,'m7UsageToday': "Today's usage"
      ,'m7NoObservation': 'No measurement data for today'
      ,'m7StaleData': 'Stale data'
      ,'m7OfflineCached': 'Offline cached'
      ,'m7SyncPending': 'Sync pending'
      ,'m7SyncFailed': 'Sync delivery failed'
      ,'m7PermissionRequired': 'Usage statistics access required'
      ,'m7PermissionRequiredBody': 'Allow usage statistics access to measure daily screen time for this device only'
      ,'m7PermissionDenied': 'Permission denied'
      ,'m7PermissionDeniedBody': 'Usage statistics permission was denied. Screen-time measurement is not possible until it is approved in system settings'
      ,'m7Unsupported': 'Measurement unsupported on this device'
      ,'m7UnsupportedBody': 'This device does not expose app usage statistics. Screen time can be measured through a dedicated app instead'
      ,'m7GrantUsageAccess': 'Grant access'
      ,'m7UsageAccessPurpose': 'To measure this device own daily screen time only'
      ,'m7WithinLimit': 'Within limit'
      ,'m7NearLimit': 'Near limit'
      ,'m7OverLimit': 'Over limit'
      ,'m7NoActivePolicy': 'No active policy'
      ,'m7UnableToEvaluate': 'Unable to evaluate'
      ,'m7BreakdownTitle': 'Breakdown by category'
      ,'m7TotalScreenTime': 'Total screen time'
      ,'m7UsageUnavailable': 'Measurement unavailable right now'
      ,'m7UsageUnavailableBody': 'Could not gather usage data for this device right now. Retry or check that the device is linked'
      ,'m7LastObserved': 'Last observed'
      ,'m7MeasuredZero': 'Zero minutes measured'
      ,'m7Observing': 'Observing'
      ,'m7ConditionDetected': 'Policy condition detected'
      ,'m7RefreshMeasurement': 'Refresh measurement'
      ,'m7UsageMinutes': '{count} min'
      ,'m8EnforcementTitle': 'Protection status'
      ,'m8EnforcementSubtitle': 'Device compliance with screen-time rules'
      ,'m8StateNotRequested': 'Protection not requested'
      ,'m8StateNotRequestedDetail': 'No limit has been decided for this device today.'
      ,'m8StatePermissionRequired': 'Protection awaiting permission'
      ,'m8StatePermissionRequiredDetail': 'Enforcement requires system permissions that have not been granted yet.'
      ,'m8StateEvaluationReady': 'Ready for evaluation'
      ,'m8StateEvaluationReadyDetail': 'No active restriction right now; the policy will apply if usage changes.'
      ,'m8StateEnforcementApplied': 'Applied and verified'
      ,'m8StateEnforcementAppliedDetail': 'The device confirmed the limit is active; losing the network will not relax it.'
      ,'m8StateEnforcementFailed': 'Application failed'
      ,'m8StateEnforcementFailedDetail': 'The system attempted to apply the limit on the device and could not confirm it.'
      ,'m8StatePolicyStale': 'Policy needs refresh'
      ,'m8StatePolicyStaleDetail': 'The local policy is too old to drive any action; request a re-sync.'
      ,'m8StateDeviceOffline': 'Device unavailable'
      ,'m8StateDeviceOfflineDetail': 'The device cannot be reached right now; the last known state is kept.'
      ,'m8StateUnsupported': 'Unsupported on this device'
      ,'m8StateUnsupportedDetail': 'The system version does not support this capability.'
      ,'m8StatePermissionDenied': 'Permission not granted'
      ,'m8StatePermissionDeniedDetail': 'The required system permission was revoked; protection is paused until you grant it again.'
      ,'m8RefreshEnforcement': 'Refresh status'
      ,'m8EnforcementUnavailable': 'Protection status is not available right now.'
      ,'m8NotVerified': 'Awaiting confirmation'
      ,'m8VerificationNote': 'The action was requested and is still awaiting device-side system confirmation.'
      ,'m8SyncedNow': 'Last sync: now'
      ,'m8SyncPending': 'Pending sync'
      ,'m8SyncFailed': 'Sync failed'
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
