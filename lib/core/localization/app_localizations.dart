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
      'navDashboard': 'العائلة',
      'navChildren': 'الأطفال',
      'navSafety': 'السلامة',
      'navTimeline': 'السجل',
      'navSettings': 'إعدادات',
      'familySetupRequired': 'أدخل اسم العائلة واسم الوالد.',
      'children': 'الأطفال',
      'incidentsToday': 'حوادث اليوم',
      'syncQueue': 'عمليات بانتظار المزامنة',
      'addChild': 'إضافة طفل',
      'childName': 'اسم الطفل',
      'pairDevice': 'ربط جهاز',
      'permissions': 'الأذونات',
      'noChildren': 'لم تُضف ملفات أطفال بعد.',
      'noFamily': 'ابدأ بإعداد عائلتك. لا تُنشأ أي بيانات تجريبية.',
      'familyDecisionCenter': 'مركز القرار العائلي',
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
      'categoryAdultContentDesc': 'محتوى صريح للكبار غير مناسب للأطفال.',
      'categoryGamblingDesc': 'مواقع القمار والمراهنة ومواقع المراهنات.',
      'categoryViolenceDesc': 'محتوى عنيف أو صادم.',
      'categoryDrugsDesc': 'المخدرات والكحول والمواد الضارة.',
      'categoryDangerousContentDesc': 'محتوى خطير يضر بالسلامة أو الصحة.',
      'categoryBullyingDesc': 'تنمر أو إساءة أو إهانة موجهة.',
      'categoryTeenContentDesc': 'محتوى مناسب للمراهقين ويحتاج إشرافًا.',
      'categoryDatingDesc': 'تطبيقات ومواقع المواعدة.',
      'categoryGamingDesc': 'ألعاب ومواقع الألعاب الإلكترونية.',
      'categoryStreamingDesc': 'مواقع البث والفيديو والترفيه.',
      'categorySocialDesc': 'شبكات التواصل والدردشة.',
      'categorySuspiciousLanguageDesc': 'لغة مشبوهة أو محتوى يحتمل الخطورة.',
      'categoryDangerousContent': 'محتوى خطير',
      'categoryBullying': 'تنمر',
      'categorySuspiciousLanguage': 'لغة مشبوهة',
      'bedtime': 'وضع النوم',
      'webFiltering': 'تصفية المحتوى',
      'locationTracking': 'تتبع الموقع',
      'deviceControls': 'أدوات الجهاز',
      'weeklyReports': 'تقارير أسبوعية',
      'sosAlerts': 'تنبيهات طوارئ',
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
      ,'loading': 'جارٍ التحميل...'
      ,'nothingHereYet': 'لا يوجد شيء هنا بعد.'
      ,'offlineMode': 'أنت غير متصل بالإنترنت حاليًا.'
      ,'offlineChangesSaved': 'تُسجَّل التغييرات محليًا وتُزامن تلقائيًا عند العودة.'
      ,'somethingWentWrong': 'حدث خطأ غير متوقع. جرّب مرة أخرى.',
      'webProtection': 'حماية الويب',
      'webFilteringDashboard': 'لوحة حماية الويب',
      'protectionLevel': 'مستوى الحماية',
      'protectionLevelStrong': 'حماية قوية',
      'protectionLevelModerate': 'حماية معتدلة',
      'protectionLevelBasic': 'حماية أساسية',
      'protectionLevelNone': 'الحماية غير مفعّلة',
      'blockedToday': 'محجوب اليوم',
      'blockedCount': '%d محجوب',
      'allowedTemporarily': 'سُمح مؤقتًا',
      'authorizationFailure': 'لا يملك حسابك صلاحية الوصول إلى هذه الشاشة.',
      'categoryEnabledFor': 'مفعّلة لـ %d أطفال',
      'childProtectionOff': 'الحماية غير مفعّلة',
      'childProtectionOn': 'محمي',
      'childProtectionPartial': 'حماية جزئية',
      'everyChild': 'كل الأطفال',
      'hitBlockedFor': 'حُجب لـ %s',
      'roleNotAllowed': 'دورك لا يسمح بهذه العملية.',
      'webProtectionStatus': 'حالة الحماية',
      'webProtectionSummary': 'تصفية المحتوى تحمي أطفالك من المواقع غير المناسبة.',
      'contentCategories': 'فئات المحتوى',
      'categoriesDescription': 'فعّل أو أوقف فئات المحتوى لكل طفل على حدة.',
      'categorySettings': 'إعدادات الفئات',
      'blockedSites': 'المواقع المحجوبة',
      'blockedSitesDescription': 'مواقع محددة تحجبها يدويًا.',
      'trustedSites': 'المواقع الموثوقة',
      'trustedSitesDescription': 'مواقع مسموحة دائمًا تتجاوز كل الفلاتر.',
      'webSettings': 'إعدادات الويب',
      'webSettingsDescription': 'البحث الآمن وسلوك صفحة الحجب وطلبات الاستثناء.',
      'blockHistory': 'سجل الحجب',
      'blockHistoryDescription': 'ماذا حُجب، ومتى، ومَن.',
      'blockHitsEmpty': 'لا توجد أي عمليات حجب اليوم. هذه علامة صحية على تصفّح آمن.',
      'addDomain': 'إضافة موقع',
      'domainHint': 'مثال: example.com',
      'domain': 'الموقع',
      'reason': 'السبب (اختياري)',
      'noDomainsYet': 'لم تضف أي موقع بعد.',
      'addFirstDomain': 'أضف أول موقع',
      'removeDomain': 'إزالة',
      'deleteDomainConfirm': 'سيتم إزالة هذا الموقع من القائمة.',
      'safeSearch': 'البحث الآمن',
      'safeSearchEnforced': 'فرض البحث الآمن في محركات البحث',
      'safeSearchOff': 'غير مفعّل',
      'blockedPageBehavior': 'عند حجب موقع',
      'blockedPageExplain': 'اشرح للطفل سبب الحجب (موصى به)',
      'blockedPageSilent': 'حجب صامت دون شرح',
      'exceptionRequestsAllowed': 'السماح للأطفال بطلب استثناء',
      'exceptionRequestsOn': 'مفعّل — يمكن للطفل طلب استثناء',
      'exceptionRequestsOff': 'معطّل',
      'perChildPolicy': 'سياسة الويب لكل طفل',
      'perChildPolicyDescription': 'قاعدة فئة لكل طفل حسب عمره.',
      'blockedPage': 'تم حجب الموقع',
      'blockedPageExplanation': 'حُجب هذا الموقع لأن إدارة العائلة قيّدت فئته.',
      'blockedPageRule': 'القاعدة المطبقة',
      'blockedPageAskParent': 'يمكنك طلب استثناء من والديك.',
      'requestException': 'طلب استثناء',
      'requestSent': 'أُرسل طلب الاستثناء إلى والديك.',
      'allowOnce': 'السماح مرة واحدة',
      'allowFor': 'السماح لمدة',
      'keepBlocked': 'إبقاء الحجب',
      'temporaryAllow': 'السماح المؤقت',
      'allowDescription': 'تتجاوز هذه الموافقة الحجب مؤقتًا وتنتهي تلقائيًا.',
      'expiry': 'تنتهي بعد',
      'fifteenMinutes': '15 دقيقة',
      'oneHour': 'ساعة واحدة',
      'confirmAllow': 'تأكيد السماح',
      'allowGranted': 'سُمح مؤقتًا بالوصول حتى تنتهي المدة.',
      'allowExpired': 'انتهت الموافقة المؤقتة؛ عاد الحجب.',
      'blockedPageChild': 'هذه الصفحة محجوبة',
      'blockedPageChildBody': 'لا يمكن فتح هذا الموقع الآن لأن والديك فعّلا الحماية.',
      'domainAdded': 'أُضيف الموقع.',
      'domainRemoved': 'أُزيل الموقع.',
      'categoryEnabled': 'مفعّلة',
      'categoryDisabled': 'معطّلة',
      'categoryToggleSaved': 'حُفظ تغيير الفئة محليًا.',
      'settingsSavedWeb': 'حُفظت الإعدادات محليًا.',
      'blockLevelStrict': 'صارم',
      'blockLevelModerate': 'متوازن',
      'blockLevelLenient': 'مرن',
      'sensitiveCategory': 'محتوى حساس',
      'ageCategory': 'مناسب للأعمار الأكبر',
      'socialCategory': 'التواصل الاجتماعي',
      'adultContentWarning': 'تفعيل هذه الفئات يحمي الأطفال من محتوى غير مناسب.',
      'protectionStrongBody': 'أغلب الفئات الحساسة مفعّلة للأطفال.',
      'protectionModerateBody': 'بعض الفئات مفعّلة وبعضها متروك للتقدير.',
      'protectionBasicBody': 'حماية أساسية فقط — يُنصح برفع المستوى.',
      'protectionNoneBody': 'لم تُفعّل أي سياسة ويب بعد.',
      'hitOverridden': 'سُمح به مؤقتًا',
      'webNotAllowedForChild': 'لم يُعثر على هذا الطفل في العائلة.',
      'noChildrenForWeb': 'أضف أطفالًا للعائلة أولًا لتفعيل حماية الويب.',
      'viewCategories': 'الفئات',
      'viewBlocklist': 'قائمة الحجب',
      'viewHistory': 'السجل',
      'domainMustBeValid': 'أدخل اسم موقع صالحًا (مثل example.com).',
      'webPolicySaved': 'حُفظت تغييرات حماية الويب محليًا وستُزامن عند الاتصال.',
      'accuracyMeters': '±{meters} م من النقطة',
      'acknowledge': 'اعتماد',
      'alertAcknowledged': 'تم اعتماد التنبيه',
      'alertOnEntry': 'تنبيه عند الدخول',
      'alertOnExit': 'تنبيه عند الخروج',
      'backgroundLocation': 'الوصول للموقع في الخلفية',
      'backgroundLocationDetail': 'يتيح رؤية موقع طفلك حتى عندما يكون التطبيق في الخلفية.',
      'batteryLevel': 'مستوى البطارية',
      'batterySaver': 'وضع توفير البطارية',
      'batterySaverDescription': 'يقلل وتيرة تحديث الموقع لإطالة عمر البطارية. قد يصبح العرض أقل دقة.',
      'childPrivacySeePrivacy': 'راجع سياسة الخصوصية لمعرفة ما نجمعه وما لا نجمعه.',
      'childSharingDescription': 'يمكنك إيقاف مشاركة موقعك في أي وقت. يصل أي طلب من والدك عند اتصال الجهاز.',
      'childSharingDisabled': 'تم إيقاف مشاركة موقعك.',
      'childSharingEnabled': 'مشاركة موقعك مفعّلة',
      'childSyncPending': 'أي تغيير يطلبه والدك يصل إليك فقط عندما يتصل جهازك بالإنترنت.',
      'coarseLocation': 'الموقع التقريبي',
      'coarseLocationDetail': 'موقع تقريبي داخل نطاق الشبكة الخلوية.',
      'createGeofence': 'إنشاء سياج جغرافي',
      'delete': 'حذف',
      'editGeofence': 'تعديل السياج',
      'familyMap': 'خريطة العائلة',
      'favoritePlaces': 'الأماكن المفضلة',
      'fineLocation': 'الموقع الدقيق',
      'fineLocationDetail': 'إحداثيات دقيقة على مستوى بضع أمتار.',
      'geofenceName': 'اسم السياج',
      'geofenceNameRequired': 'اسم السياج الجغرافي مطلوب.',
      'geofenceRadius': 'نصف القطر',
      'geofenceRadiusHint': 'نصف قطر بين 50 و5000 متر.',
      'geofenceRemoved': 'تم وضع علامة إزالة على السياج وسيتزامن عند الاتصال.',
      'geofenceSaved': 'تم حفظ السياج محليًا وسيتزامن عند الاتصال.',
      'geofenceTemplates': 'قوالب جاهزة',
      'geofences': 'السياج الجغرافي',
      'hoursAgo': 'منذ {n} ساعة',
      'justNow': 'الآن',
      'lastUpdated': 'آخر تحديث',
      'locationAlerts': 'تنبيهات الموقع',
      'locationAlertsNav': 'تنبيهات الموقع',
      'locationHistory': 'سجل الموقع',
      'locationPrivacy': 'خصوصية الموقع',
      'locationSettings': 'إعدادات الموقع',
      'locationSharing': 'مشاركة الموقع',
      'memberLocationDetails': 'تفاصيل موقع العضو',
      'memberNotNearAnyGeofence': 'هذا العضو ليس داخل أي سياج نشط.',
      'members': 'الأعضاء',
      'minutesAgo': 'منذ {n} دقيقة',
      'noAlertsYet': 'لا توجد تنبيهات موقع حتى الآن.',
      'noGeofencesYet': 'لا توجد سياج جغرافي بعد. أنشئ واحدًا من الأعلى.',
      'noLocationsYet': 'لم يصل أي موقع لهذا العضو بعد.',
      'noMembersYet': 'لا يوجد أعضاء يمكن مشاهدتهم على الخريطة.',
      'noPlacesYet': 'لا توجد أماكن مفضلة بعد. ثبّت موقعًا من الخريطة.',
      'permissionNotSupported': 'هذا الإذن غير مدعوم على هذا الجهاز.',
      'permissionOnboarding': 'إعداد إذن الموقع',
      'permissionRationale': 'لماذا نحتاج إذن الموقع؟',
      'permissionRationaleDetail': 'لن تعمل الخريطة ولا السياج الجغرافي ولا التنبيهات دون إذن موقع حقيقي ممنوح من إعدادات Android. لا نخترق الموقع — إن لم يُمنح الإذن سنعرض الحالة بصدق.',
      'privacyDeleteData': 'حذف بيانات الموقع',
      'privacyDeleteDataDetail': 'يمكنك حذف سجل المواقع في أي وقت من إعدادات هذا الجهاز. لا تُرسل البيانات إلى أطراف ثالثة.',
      'privacyLocationCollection': 'ماذا نجمع؟',
      'privacyLocationCollectionDetail': 'نجمع فقط آخر مواضع معلنة لكل عضو مفعّل له المشاركة، وفق وتيرة تحديث محددة في الإعدادات.',
      'privacyLocationRetention': 'مدة الاحتفاظ',
      'privacyLocationRetentionDetail': 'تُحفظ المواضع محليًا وتُزامن مع حسابات العائلة الموثقة فقط. لا تحتفظ العائلة بأي بيانات بعد حذف العضو.',
      'privacyParentAccess': 'من يرى ماذا؟',
      'privacyParentAccessDetail': 'الوالدان الموثقان فقط يرون المواقع. يراهما الشريك بحسب الصلاحيات الممنوحة. ولا يرى أي طفل موقع أي عضو آخر.',
      'privacyThirdParty': 'الأطراف الخارجية',
      'privacyThirdPartyDetail': 'لا تُباع البيانات ولا تُشارك مع معلنين أو وسطاء. تتم المزامنة فقط داخل بنية العائلة الخاصة بك.',
      'radiusMeters': '{radius} م',
      'routeTrace': 'مسار الحركة',
      'save': 'حفظ',
      'saveChanges': 'حفظ التعديلات',
      'selectPlaceOnMap': 'اختر الموقع على الخريطة',
      'setFavoritePlace': 'تثبيت كمفضّل',
      'sharingDisabled': 'تم إيقاف المشاركة لهذا العضو.',
      'sharingEnabled': 'تم تفعيل مشاركة الموقع.',
      'sharingMatrix': 'جدول الرؤية',
      'sharingRevoked': 'أُلغيت مشاركة هذا العضو. يتوقف العرض عند المزامنة التالية.',
      'tapToSetCenter': 'اضغط لتحديد الموقع',
      'templateSchoolHours': 'أوقات المدرسة',
      'templateHomeRange': 'النطاق الآمن حول المنزل',
      'templatePrayerPlace': 'المصلى',
      'templateSchoolHoursName': 'المدرسة — أوقات الدوام',
      'templateHomeRangeName': 'المنزل — النطاق الآمن',
      'templatePrayerPlaceName': 'المصلى',
      'viewAll': 'عرض الكل',
      'favoritePlacesNav': 'الأماكن المفضلة',
      'webProtectionNav': 'حماية الويب',
      'webFilterHistoryNav': 'سجل الرصد',
      'childDeviceExperience': 'الجهاز',
      'sosUtilityNotice': 'تسجيل حدث طوارئ ومزامنة الطابور المحلي.',
      'open': 'فتح',
      'appControlDashboard': 'التحكم بالتطبيقات',
      'blockedApps': 'تطبيقات محظورة',
      'blockedTodayApps': 'حظر اليوم',
      'appProtectionSummary': 'مستوى الحماية الحالية',
      'appProtectionActive': 'الحماية مفعّلة: بعض التطبيقات محظورة أو مقيّدة.',
      'appProtectionRelaxed': 'لا توجد سياسات حظر نشطة حالياً.',
      'installedAppsNav': 'جميع التطبيقات',
      'appsBlocked': '{count} تطبيق محظور',
      'noAppsBlocked': 'لا توجد تطبيقات محظورة',
      'protected': 'محمي',
      'notProtected': 'غير محمي',
      'limited': 'مقيّد',
      'appControlSyncFailed': 'تعذّر مزامنة التحكم بالتطبيقات',
      'installedApps': 'التطبيقات المثبّتة',
      'installedAppsDescription': 'تطبيقات الأجهزة المرتبطة بحالة كل تطبيق',
      'appAllowlist': 'قائمة السماح',
      'appAllowlistDescription': 'تطبيقات موثوقة لا تُحظر أبداً',
      'usageAlerts': 'تنبيهات الاستخدام',
      'usageAlertsDescription': 'عتبات تنبيه لكل تطبيق',
      'appBlockHistory': 'سجل حظر التطبيقات',
      'appBlockHistoryDescription': 'سجل تدقيق لجميع أحداث الإنفاذ',
      'noAppsUsage': 'لا توجد بيانات تطبيقات بعد',
      'noAppsUsageDescription': 'ستظهر التطبيقات فور إرسال الأجهزة بيانات الاستخدام الأولى.',
      'searchApps': 'ابحث عن تطبيق...',
      'appUsageChip': 'الاستخدام: {usage}',
      'allowed': 'مسموح',
      'blocked': 'محظور',
      'timeLimited': 'مقيّد زمنياً',
      'trusted': 'موثوق',
      'unrestricted': 'بدون قيود',
      'allowApp': 'السماح',
      'blockApp': 'حظر التطبيق',
      'appBlockedNotice': 'تمت إضافة التطبيق إلى قائمة الحظر (قيد المزامنة)',
      'appAllowedNotice': 'تم السماح بالتطبيق (قيد المزامنة)',
      'usageToday': 'استخدام اليوم',
      'policyAction': 'إجراء السياسة',
      'currentAction': 'الإجراء الحالي',
      'choosePolicyAction': 'اختر إجراء السياسة',
      'dailyAllowance': 'المهلة اليومية',
      'dailyTimeLimit': 'الحد اليومي',
      'syncEvidence': 'دليل المزامنة',
      'policySyncState': 'حالة المزامنة',
      'syncStateLabel': '{state}',
      'addTrustedApp': 'إضافة تطبيق موثوق',
      'appAllowlistSummary': 'تطبيقات لا تُحظر مهما تغيّرت الأوضاع',
      'noTrustedApps': 'لا توجد تطبيقات موثوقة بعد',
      'noTrustedAppsDescription': 'أضف تطبيقات المتجر والمدرسة حتى تبقى متاحة دائماً.',
      'noReasonGiven': 'بدون مبرر مسجّل',
      'removeFromAllowlist': 'إزالة من قائمة السماح',
      'trustAddedNotice': 'أُضيف التطبيق إلى قائمة السماح (قيد المزامنة)',
      'appTargetHint': 'معرف التطبيق (مثال: com.example.app)',
      'trustReasonHint': 'سبب الثقة (مسجّل في التدقيق)',
      'addTrustedAppAction': 'إضافة',
      'perChildRules': 'قواعد الطفل للتطبيقات',
      'childAppPolicies': 'السياسات',
      'noChildRules': 'لا توجد قواعد خاصة بهذا الطفل',
      'noChildRulesDescription': 'السياسات العامة للعائلة تنطبق حالياً.',
      'limitChip': 'الحد: {limit}',
      'actionChip': 'الإجراء: {action}',
      'noAlertsConfigured': 'لا توجد تنبيهات مهيّأة',
      'noAlertsConfiguredDescription': 'أضف عتبة تنبيه لتطبيق ما ليُنبهك عند تجاوزه.',
      'alertThresholdChip': 'العتبة: {threshold}',
      'usageAlertsSummary': 'تنبيه عند تجاوز الاستخدام لحد معيّن',
      'noUsageData': 'لا توجد بيانات استخدام بعد',
      'noUsageDataDescription': 'يحتاج تسجيل الاستخدام إلى أول حملة مزامنة من الأجهزة.',
      'alertSet': 'تنبيه مفعّل',
      'noBlockEvents': 'لا توجد أحداث حظر',
      'noBlockEventsDescription': 'لم يُسجَّل أي حدث إنفاذ بعد. سيظهر السجل هنا بأمانة.',
      'eventTypeLabel': 'حدث: {event}',
      'myAppRules': 'قواعد تطبيقي',
      'myAppRulesDescription': 'القواعد المطبّقة على تطبيقاتي فقط — لا شيء غير ذلك.',
      'appliedRules': 'القواعد المطبّقة',
      'noRulesApplied': 'لا توجد قواعد مطبّقة عليّ',
      'noRulesAppliedDescription': 'تطبيقاتي تعمل بحرية حالياً.',
      'exceptionRequestCta': 'طلب استثناء',
      'exceptionRequestDescription': 'هل تعتقد أن قاعدة خاطئة؟ اطلب مراجعة من الوالد.',
      'block': 'حظر',
      'unblock': 'إلغاء حظر',
      'override': 'تجاوز',
      'timeout': 'انتهاء المهلة',
      'addedToAllowlist': 'أُضيف لقائمة السماح',
      'removedFromAllowlist': 'أُزيل من قائمة السماح',
    },
'en': {
      'appTitle': 'Guardian Eye Pro',
      'welcome': 'Protect your family with clarity and trust',
      'createFamily': 'Create family',
      'familyName': 'Family name',
      'parentName': 'Parent name',
      'continue': 'Continue',
      'dashboard': 'Family dashboard',
      'navDashboard': 'Home',
      'navChildren': 'Kids',
      'navSafety': 'Safety',
      'navTimeline': 'Timeline',
      'navSettings': 'Settings',
      'familySetupRequired': 'Enter the family name and parent name.',
      'children': 'Children',
      'incidentsToday': 'Incidents today',
      'syncQueue': 'Queued sync operations',
      'addChild': 'Add child',
      'childName': 'Child name',
      'pairDevice': 'Pair device',
      'permissions': 'Permissions',
      'noChildren': 'No child profiles have been added.',
      'noFamily': 'Start by setting up your family. No sample data is created.',
      'familyDecisionCenter': 'Family Decision Center',
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
      ,'loading': 'Loading...'
      ,'nothingHereYet': 'Nothing here yet.'
      ,'offlineMode': 'You are currently offline.'
      ,'offlineChangesSaved': 'Changes are saved locally and sync automatically when you are back.'
      ,'somethingWentWrong': 'Something went wrong. Please try again.'
      ,'accuracyMeters': '±{meters} m of the point'
      ,'acknowledge': 'Acknowledge'
      ,'alertAcknowledged': 'Alert acknowledged'
      ,'alertOnEntry': 'Alert on entry'
      ,'alertOnExit': 'Alert on exit'
      ,'authorizationFailure': 'Authorization failure'
      ,'backgroundLocation': 'Background location'
      ,'backgroundLocationDetail': 'Allows the app to keep seeing your child’s position while it runs in the background.'
      ,'batteryLevel': 'Battery level'
      ,'batterySaver': 'Battery saver mode'
      ,'batterySaverDescription': 'Lowers the location update frequency to save battery. The view may become less precise.'
      ,'childPrivacySeePrivacy': 'See the privacy note for what is collected and what is never collected.'
      ,'childSharingDescription': 'You can stop sharing your location at any time. A parent’s stop request arrives when this device reconnects.'
      ,'childSharingDisabled': 'Your location sharing is now off.'
      ,'childSharingEnabled': 'Your location sharing is on'
      ,'childSyncPending': 'Any change a parent requests reaches this screen only when your device connects to the internet.'
      ,'coarseLocation': 'Approximate location'
      ,'coarseLocationDetail': 'An approximate position within the cellular network area.'
      ,'createGeofence': 'Create geofence'
      ,'delete': 'Delete'
      ,'editGeofence': 'Edit geofence'
      ,'familyMap': 'Family map'
      ,'favoritePlaces': 'Favorite places'
      ,'fineLocation': 'Precise location'
      ,'fineLocationDetail': 'Coordinates accurate to a few meters.'
      ,'geofenceName': 'Geofence name'
      ,'geofenceNameRequired': 'A geofence name is required.'
      ,'geofenceRadius': 'Radius'
      ,'geofenceRadiusHint': 'Radius must be between 50 and 5000 meters.'
      ,'geofenceRemoved': 'The geofence is marked for removal and will sync when connected.'
      ,'geofenceSaved': 'The geofence was saved locally and will sync when connected.'
      ,'geofenceTemplates': 'Ready-made templates'
      ,'geofences': 'Geofences'
      ,'hoursAgo': '{n} h ago'
      ,'justNow': 'Just now'
      ,'lastUpdated': 'Last updated'
      ,'locationAlerts': 'Location alerts'
      ,'locationAlertsNav': 'Location alerts'
      ,'locationHistory': 'Location history'
      ,'locationPrivacy': 'Location privacy'
      ,'locationSettings': 'Location settings'
      ,'locationSharing': 'Location sharing'
      ,'memberLocationDetails': 'Member location details'
      ,'memberNotNearAnyGeofence': 'This member is not inside any active geofence.'
      ,'members': 'Members'
      ,'minutesAgo': '{n} min ago'
      ,'noAlertsYet': 'No location alerts yet.'
      ,'noGeofencesYet': 'No geofences yet. Create one from above.'
      ,'noLocationsYet': 'No location points have arrived for this member yet.'
      ,'noMembersYet': 'There are no members to show on the map yet.'
      ,'noPlacesYet': 'No favorite places yet. Pin one from the map.'
      ,'permissionNotSupported': 'This permission is not supported on this device.'
      ,'permissionOnboarding': 'Location permission setup'
      ,'permissionRationale': 'Why we need location permission'
      ,'permissionRationaleDetail': 'The map, geofences and alerts cannot work without real location permission granted in Android settings. We never fabricate positions — if the permission is missing we say so honestly.'
      ,'privacyDeleteData': 'Delete location data'
      ,'privacyDeleteDataDetail': 'You can delete the location history at any time from this device’s settings. Data is never shared with third parties.'
      ,'privacyLocationCollection': 'What we collect'
      ,'privacyLocationCollectionDetail': 'We only collect the last announced positions of each member whose sharing is enabled, at the update frequency set in Location settings.'
      ,'privacyLocationRetention': 'Retention'
      ,'privacyLocationRetentionDetail': 'Positions are stored locally and synced only with verified family accounts. No location data is retained after a member is removed.'
      ,'privacyParentAccess': 'Who sees what'
      ,'privacyParentAccessDetail': 'Only verified parents see member locations. A spouse sees according to granted permissions. No child ever sees another member’s location.'
      ,'privacyThirdParty': 'Third parties'
      ,'privacyThirdPartyDetail': 'Data is never sold or shared with advertisers or brokers. Sync happens only within your own family infrastructure.'
      ,'radiusMeters': '{radius} m'
      ,'roleNotAllowed': 'Your family role is not allowed to view this page.'
      ,'routeTrace': 'Route trace'
      ,'save': 'Save'
      ,'saveChanges': 'Save changes'
      ,'selectPlaceOnMap': 'Pick the position on the map'
      ,'setFavoritePlace': 'Set as favorite'
      ,'sharingDisabled': 'Sharing is now off for this member.'
      ,'sharingEnabled': 'Location sharing is now on.'
      ,'sharingMatrix': 'Sharing matrix'
      ,'sharingRevoked': 'This member’s sharing was revoked. Their view stops at the next sync.'
      ,'tapToSetCenter': 'Tap to set the position'
      ,'templateSchoolHours': 'School hours'
      ,'templateHomeRange': 'Safe home range'
      ,'templatePrayerPlace': 'Prayer place'
      ,'templateSchoolHoursName': 'School — class hours'
      ,'templateHomeRangeName': 'Home — safe range'
      ,'templatePrayerPlaceName': 'Mosque'
      ,'viewAll': 'View all'
      ,'favoritePlacesNav': 'Favorite places'
      ,'webProtectionNav': 'Web protection'
      ,'webFilterHistoryNav': 'Block history'
      ,'childDeviceExperience': 'Device'
      ,'sosUtilityNotice': 'Record an emergency event and sync the local queue.'
      ,'open': 'Open'
      ,'appControlDashboard': 'App control'
      ,'blockedApps': 'Blocked apps'
      ,'blockedTodayApps': 'Blocked today'
      ,'appProtectionSummary': 'Current protection level'
      ,'appProtectionActive': 'Protection active: some apps are blocked or limited.'
      ,'appProtectionRelaxed': 'No active blocking policies right now.'
      ,'installedAppsNav': 'All apps'
      ,'appsBlocked': '{count} apps blocked'
      ,'noAppsBlocked': 'No apps blocked'
      ,'protected': 'Protected'
      ,'notProtected': 'Not protected'
      ,'limited': 'Limited'
      ,'appControlSyncFailed': 'App control sync failed'
      ,'installedApps': 'Installed apps'
      ,'installedAppsDescription': 'Apps on linked devices with each app status'
      ,'appAllowlist': 'Allowlist'
      ,'appAllowlistDescription': 'Trusted apps that are never blocked'
      ,'usageAlerts': 'Usage alerts'
      ,'usageAlertsDescription': 'Per-app alert thresholds'
      ,'appBlockHistory': 'App block history'
      ,'appBlockHistoryDescription': 'Audit log of all enforcement events'
      ,'noAppsUsage': 'No app data yet'
      ,'noAppsUsageDescription': 'Apps appear as soon as devices send their first usage report.'
      ,'searchApps': 'Search apps...'
      ,'appUsageChip': 'Usage: {usage}'
      ,'allowed': 'Allowed'
      ,'blocked': 'Blocked'
      ,'timeLimited': 'Time-limited'
      ,'trusted': 'Trusted'
      ,'unrestricted': 'Unrestricted'
      ,'allowApp': 'Allow'
      ,'blockApp': 'Block app'
      ,'appBlockedNotice': 'App added to the block list (syncing)'
      ,'appAllowedNotice': 'App allowed (syncing)'
      ,'usageToday': 'Usage today'
      ,'policyAction': 'Policy action'
      ,'currentAction': 'Current action'
      ,'choosePolicyAction': 'Choose policy action'
      ,'dailyAllowance': 'Daily allowance'
      ,'dailyTimeLimit': 'Daily limit'
      ,'syncEvidence': 'Sync evidence'
      ,'policySyncState': 'Sync state'
      ,'syncStateLabel': '{state}'
      ,'addTrustedApp': 'Add trusted app'
      ,'appAllowlistSummary': 'Apps that are never blocked regardless of conditions'
      ,'noTrustedApps': 'No trusted apps yet'
      ,'noTrustedAppsDescription': 'Add store and school apps so they always stay available.'
      ,'noReasonGiven': 'No reason recorded'
      ,'removeFromAllowlist': 'Remove from allowlist'
      ,'trustAddedNotice': 'App added to the allowlist (syncing)'
      ,'addTrustedAppAction': 'Add'
      ,'appTargetHint': 'App identifier (e.g. com.example.app)'
      ,'trustReasonHint': 'Reason for trust (recorded in audit)'
      ,'perChildRules': 'Child app rules'
      ,'childAppPolicies': 'Policies'
      ,'noChildRules': 'No rules specific to this child'
      ,'noChildRulesDescription': 'Family-wide policies apply for now.'
      ,'limitChip': 'Limit: {limit}'
      ,'actionChip': 'Action: {action}'
      ,'noAlertsConfigured': 'No alerts configured'
      ,'noAlertsConfiguredDescription': 'Add an alert threshold for an app to be notified when exceeded.'
      ,'alertThresholdChip': 'Threshold: {threshold}'
      ,'usageAlertsSummary': 'Alert when usage exceeds a set limit'
      ,'noUsageData': 'No usage data yet'
      ,'noUsageDataDescription': 'Usage tracking needs the first device sync batch.'
      ,'alertSet': 'Alert set'
      ,'noBlockEvents': 'No block events'
      ,'noBlockEventsDescription': 'No enforcement event recorded yet. The log will appear here honestly.'
      ,'eventTypeLabel': 'Event: {event}'
      ,'myAppRules': 'My app rules'
      ,'myAppRulesDescription': 'The rules applied to my apps only — nothing else.'
      ,'appliedRules': 'Applied rules'
      ,'noRulesApplied': 'No rules applied to me'
      ,'noRulesAppliedDescription': 'My apps are running freely right now.'
      ,'exceptionRequestCta': 'Request exception'
      ,'exceptionRequestDescription': 'Think a rule is wrong? Ask a parent to review it.'
      ,'block': 'Block'
      ,'unblock': 'Unblock'
      ,'override': 'Override'
      ,'timeout': 'Time limit'
      ,'addedToAllowlist': 'Added to allowlist'
      ,'removedFromAllowlist': 'Removed from allowlist'
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
