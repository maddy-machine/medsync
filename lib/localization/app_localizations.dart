import 'package:flutter/material.dart';

class AppLanguage {
  final String code;
  final String name;
  final String nativeName;
  final Locale locale;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.locale,
  });
}

class AppLanguages {
  static const supported = <AppLanguage>[
    AppLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      locale: Locale('en'),
    ),
    AppLanguage(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      locale: Locale('hi'),
    ),
    AppLanguage(
      code: 'as',
      name: 'Assamese',
      nativeName: 'অসমীয়া',
      locale: Locale('as'),
    ),
    AppLanguage(
      code: 'bn',
      name: 'Bengali',
      nativeName: 'বাংলা',
      locale: Locale('bn'),
    ),
    AppLanguage(
      code: 'mni',
      name: 'Meitei',
      nativeName: 'মৈতৈলোন্',
      locale: Locale('mni'),
    ),
    AppLanguage(
      code: 'kha',
      name: 'Khasi',
      nativeName: 'Khasi',
      locale: Locale('kha'),
    ),
    AppLanguage(
      code: 'lus',
      name: 'Mizo',
      nativeName: 'Mizo',
      locale: Locale('lus'),
    ),
    AppLanguage(
      code: 'ne',
      name: 'Nepali',
      nativeName: 'नेपाली',
      locale: Locale('ne'),
    ),
    AppLanguage(
      code: 'nag',
      name: 'Nagamese',
      nativeName: 'Nagamese',
      locale: Locale('nag'),
    ),
  ];

  static AppLanguage byCode(String code) {
    return supported.firstWhere(
      (language) => language.code == code,
      orElse: () => supported.first,
    );
  }
}

class AppLocalizations {
  final String languageCode;

  const AppLocalizations(this.languageCode);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final result = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );

    return result ?? const AppLocalizations('en');
  }

  String get(String key) {
    return _translations[languageCode]?[key] ??
        _translations['en']![key] ??
        key;
  }

  String languageName(String code) {
    return AppLanguages.byCode(code).name;
  }

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      // App
      'appTitle': 'MedSync OA Screening',
      'selectLanguage': 'Select Language',
      'language': 'Language',

      // General
      'continue': 'CONTINUE',
      'back': 'BACK',
      'next': 'NEXT',
      'done': 'DONE',
      'cancel': 'CANCEL',
      'start': 'START',
      'stop': 'STOP',
      'retry': 'RETRY',
      'save': 'SAVE',
      'close': 'CLOSE',
      'yes': 'Yes',
      'no': 'No',
      'notAvailable': 'Not available',

      // Assessment
      'patientAssessment': 'Patient Assessment',
      'patientAssessmentTitle': 'Tell us about your symptoms',
      'patientAssessmentSubtitle':
          'This information is combined with movement data for AI-assisted preliminary screening.',
      'age': 'Age',
      'sex': 'Sex',
      'female': 'Female',
      'male': 'Male',
      'preferNotToSay': 'Prefer not to say',
      'height': 'Height',
      'weight': 'Weight',
      'bmi': 'BMI',
      'pain': 'Pain',
      'stiffness': 'Stiffness',
      'functionalDifficulty': 'Functional difficulty',
      'activityRelatedPain': 'Pain related to activity',
      'morningStiffness': 'Morning stiffness',
      'enterAge': 'Enter age',
      'enterHeight': 'Enter height',
      'enterWeight': 'Enter weight',
      'selectSex': 'Select sex',
      'ratePain': 'Rate your pain',
      'rateStiffness': 'Rate your stiffness',
      'rateDifficulty': 'Rate your difficulty with movement',

      // Screening
      'readyForScreening': 'Ready for Screening?',
      'screeningIncludes':
          'The screening includes a chair stand and a fast walk movement assessment.',
      'startScreening': 'START SCREENING',
      'screeningComplete': 'SCREENING COMPLETE',
      'screeningDataCollected': 'Screening Data Collected',

      // Sensors
      'sensorSetup': 'Sensor Setup',
      'connectSensors': 'Connect Sensors',
      'sensorConnection': 'Sensor Connection',
      'connectToSensors':
          'Connect the wearable sensors before starting the movement assessment.',
      'thighSensor': 'Thigh sensor',
      'shinSensor': 'Shin sensor',
      'connected': 'Connected',
      'disconnected': 'Disconnected',
      'searching': 'Searching...',
      'connecting': 'Connecting...',
      'connectionSuccessful': 'Sensor connection successful.',
      'connectionFailed': 'Sensor connection failed.',
      'checkBluetooth':
          'Please check Bluetooth and make sure the sensors are powered on.',

      // Calibration
      'calibration': 'Calibration',
      'calibrating': 'Calibrating',
      'standStill': 'Stand still while the sensors calibrate.',
      'calibrationComplete': 'Calibration complete.',
      'calibrationFailed': 'Calibration failed.',
      'keepStill': 'Please remain still during calibration.',

      // Movement tests
      'movementAssessment': 'Movement Assessment',
      'movementTests': 'Movement Tests',
      'chairStand': '30-Second Chair Stand',
      'fastWalk': 'Fast Walk',
      'fastWalk20m': '20 m Fast Walk',
      'chairStandInstruction':
          'Sit on the chair and stand up and sit down repeatedly for 30 seconds.',
      'fastWalkInstruction':
          'Walk quickly and safely for 20 metres. Finish when you reach the end.',
      'sitStandRepeatedly':
          'Stand up and sit down repeatedly for 30 seconds.',
      'walkQuickly':
          'Walk quickly and safely for 20 metres.',
      'keepSensorsSecure':
          'Make sure both sensors are securely attached before starting.',
      'followInstructions':
          'Follow the instructions shown on the screen.',
      'safetyFirst':
          'Stop the test if you feel severe pain, dizziness, or unsafe.',
      'getReady': 'GET READY',
      'testRunning': 'TEST RUNNING',
      'testCompleted': 'TEST COMPLETED',
      'testFailed': 'TEST FAILED',
      'ready': 'READY',
      'samplesCollected': 'Samples collected',
      'duration': 'Duration',
      'samplingRate': 'Sampling rate',
      'startTest': 'START TEST',
      'stopTest': 'STOP TEST',

      // Results
      'results': 'Results',
      'screeningResults': 'Screening Results',
      'movementAssessmentComplete': 'Movement assessment complete',
      'bothTestsRecorded':
          'Both movement tests have been recorded and analysed.',
      'viewScreeningResults': 'VIEW SCREENING RESULTS',
      'yourMovementAssessment': 'Your movement assessment',
      'recordedMovementProcessed':
          'The recorded movement data has been processed and combined with your assessment information.',

      // Quality
      'dataQuality': 'Data Quality',
      'testQuality': 'Test Quality',
      'dataQualityScore': 'Data quality score',
      'recordedSamples': 'Recorded samples',
      'recordingDuration': 'Recording duration',
      'sampleCoverage': 'Sample coverage',
      'timestampRegularity': 'Timestamp regularity',
      'sensorSignalQuality': 'Sensor signal quality',
      'movementPresence': 'Movement presence',
      'good': 'Good',
      'acceptable': 'Acceptable',
      'repeatRecommended': 'Repeat recommended',
      'technicalQualityExplanation':
          'This score describes the technical quality of the recorded sensor data. It is not an AI confidence score and does not represent a clinical diagnosis.',

      // Analysis
      'kneeMovement': 'Knee movement',
      'rangeOfMotion': 'Range of motion',
      'minimumAngle': 'Minimum angle',
      'maximumAngle': 'Maximum angle',
      'movementVariability': 'Movement variability',
      'repetitions': 'Repetitions',
      'averageCycle': 'Average cycle',
      'walkDuration': 'Walk duration',
      'shinDynamicAcceleration': 'Shin dynamic acceleration',

      // AI
      'aiAssistedScreening': 'AI-Assisted Preliminary Screening',
      'aiScreening': 'AI Screening',
      'aiScreeningUnavailable': 'AI screening unavailable',
      'riskAssessment': 'Risk Assessment',
      'higherOARisk':
          'Higher OA-associated risk indicated',
      'lowerOARisk':
          'Lower OA-associated risk indicated',
      'modelEstimatedRisk':
          'model-estimated OA-associated risk probability',
      'screeningThreshold': 'Screening threshold',
      'keyContributingFactors': 'Key contributing factors',
      'noRiskScoreGenerated':
          'No artificial risk score has been generated.',
      'modelNotConnected':
          'A compatible trained AI model is not currently connected to this application.',

      // Clinical
      'clinicalInterpretation': 'Clinical interpretation',
      'clinicalEvaluationRecommended':
          'Clinical evaluation is recommended for interpretation and follow-up.',
      'clinicalValidation': 'Clinical Validation',
      'clinicalValidationText':
          'Technical prototype validation and clinical validation are separate requirements. Clinical validation requires clinically labelled participants, a predefined evaluation protocol, independent evaluation, and appropriate performance assessment.',
      'notClinicallyValidated':
          'The current prototype does not claim clinical validation or diagnostic accuracy.',
      'notDiagnosis':
          'AI-assisted preliminary screening • Not a diagnosis',

      // Report
      'downloadReport': 'DOWNLOAD REPORT',
      'generatingReport': 'Generating screening report...',
      'reportGenerated': 'Report generated successfully.',
      'reportError': 'Could not generate the report.',

      // Errors
      'invalidTestData': 'Test data invalid',
      'pleaseFinishCurrentTest':
          'Please finish or cancel the current test first.',
      'somethingWentWrong': 'Something went wrong.',
      'tryAgain': 'Please try again.',

      // Live sensor
      'liveSensorData': 'Live Sensor Data',
      'thigh': 'Thigh',
      'shin': 'Shin',
      'acceleration': 'Acceleration',
      'gyroscope': 'Gyroscope',
    },

    'hi': {
      'appTitle': 'MedSync OA Screening',
      'selectLanguage': 'भाषा चुनें',
      'language': 'भाषा',

      'continue': 'जारी रखें',
      'back': 'वापस',
      'next': 'आगे',
      'done': 'पूरा करें',
      'cancel': 'रद्द करें',
      'start': 'शुरू करें',
      'stop': 'रोकें',
      'retry': 'फिर से प्रयास करें',
      'save': 'सहेजें',
      'close': 'बंद करें',
      'yes': 'हाँ',
      'no': 'नहीं',
      'notAvailable': 'उपलब्ध नहीं',

      'patientAssessment': 'रोगी का मूल्यांकन',
      'patientAssessmentTitle': 'अपने लक्षणों के बारे में बताएं',
      'patientAssessmentSubtitle':
          'इस जानकारी को मूवमेंट डेटा के साथ मिलाकर AI-सहायित प्रारंभिक स्क्रीनिंग की जाती है।',
      'age': 'उम्र',
      'sex': 'लिंग',
      'female': 'महिला',
      'male': 'पुरुष',
      'preferNotToSay': 'बताना नहीं चाहते',
      'height': 'लंबाई',
      'weight': 'वजन',
      'bmi': 'BMI',
      'pain': 'दर्द',
      'stiffness': 'जकड़न',
      'functionalDifficulty': 'चलने-फिरने में कठिनाई',
      'activityRelatedPain': 'गतिविधि से संबंधित दर्द',
      'morningStiffness': 'सुबह की जकड़न',
      'enterAge': 'उम्र दर्ज करें',
      'enterHeight': 'लंबाई दर्ज करें',
      'enterWeight': 'वजन दर्ज करें',
      'selectSex': 'लिंग चुनें',
      'ratePain': 'अपने दर्द का स्तर बताएं',
      'rateStiffness': 'जकड़न का स्तर बताएं',
      'rateDifficulty': 'चलने-फिरने की कठिनाई का स्तर बताएं',

      'readyForScreening': 'स्क्रीनिंग के लिए तैयार?',
      'screeningIncludes':
          'स्क्रीनिंग में चेयर स्टैंड और तेज चलने का मूवमेंट टेस्ट शामिल है।',
      'startScreening': 'स्क्रीनिंग शुरू करें',
      'screeningComplete': 'स्क्रीनिंग पूरी',
      'screeningDataCollected': 'स्क्रीनिंग डेटा एकत्रित',

      'sensorSetup': 'सेंसर सेटअप',
      'connectSensors': 'सेंसर कनेक्ट करें',
      'sensorConnection': 'सेंसर कनेक्शन',
      'connectToSensors':
          'मूवमेंट टेस्ट शुरू करने से पहले पहनने वाले सेंसर कनेक्ट करें।',
      'thighSensor': 'जांघ का सेंसर',
      'shinSensor': 'पिंडली का सेंसर',
      'connected': 'कनेक्टेड',
      'disconnected': 'डिस्कनेक्टेड',
      'searching': 'खोज रहे हैं...',
      'connecting': 'कनेक्ट हो रहा है...',
      'connectionSuccessful': 'सेंसर कनेक्शन सफल रहा।',
      'connectionFailed': 'सेंसर कनेक्शन विफल रहा।',
      'checkBluetooth':
          'Bluetooth जांचें और सुनिश्चित करें कि सेंसर चालू हैं।',

      'calibration': 'कैलिब्रेशन',
      'calibrating': 'कैलिब्रेशन हो रहा है',
      'standStill': 'सेंसर कैलिब्रेट होने तक स्थिर खड़े रहें।',
      'calibrationComplete': 'कैलिब्रेशन पूरा हुआ।',
      'calibrationFailed': 'कैलिब्रेशन विफल रहा।',
      'keepStill': 'कैलिब्रेशन के दौरान स्थिर रहें।',

      'movementAssessment': 'मूवमेंट मूल्यांकन',
      'movementTests': 'मूवमेंट टेस्ट',
      'chairStand': '30 सेकंड चेयर स्टैंड',
      'fastWalk': 'तेज चाल',
      'fastWalk20m': '20 मीटर तेज चाल',
      'chairStandInstruction':
          'कुर्सी पर बैठें और 30 सेकंड तक बार-बार खड़े होकर फिर बैठें।',
      'fastWalkInstruction':
          '20 मीटर तक सुरक्षित तरीके से तेज चलें। अंत तक पहुंचने पर रुकें।',
      'sitStandRepeatedly':
          '30 सेकंड तक बार-बार खड़े हों और बैठें।',
      'walkQuickly':
          '20 मीटर तक सुरक्षित तरीके से तेज चलें।',
      'keepSensorsSecure':
          'शुरू करने से पहले सुनिश्चित करें कि दोनों सेंसर अच्छी तरह लगे हैं।',
      'followInstructions':
          'स्क्रीन पर दिए गए निर्देशों का पालन करें।',
      'safetyFirst':
          'तेज दर्द, चक्कर या असुरक्षित महसूस होने पर टेस्ट रोक दें।',
      'getReady': 'तैयार हो जाएं',
      'testRunning': 'टेस्ट चल रहा है',
      'testCompleted': 'टेस्ट पूरा हुआ',
      'testFailed': 'टेस्ट विफल',
      'ready': 'तैयार',
      'samplesCollected': 'एकत्रित सैंपल',
      'duration': 'अवधि',
      'samplingRate': 'सैंपलिंग दर',
      'startTest': 'टेस्ट शुरू करें',
      'stopTest': 'टेस्ट रोकें',

      'results': 'परिणाम',
      'screeningResults': 'स्क्रीनिंग परिणाम',
      'movementAssessmentComplete': 'मूवमेंट मूल्यांकन पूरा हुआ',
      'bothTestsRecorded':
          'दोनों मूवमेंट टेस्ट रिकॉर्ड और विश्लेषित किए गए हैं।',
      'viewScreeningResults': 'स्क्रीनिंग परिणाम देखें',
      'yourMovementAssessment': 'आपका मूवमेंट मूल्यांकन',
      'recordedMovementProcessed':
          'रिकॉर्ड किए गए मूवमेंट डेटा को संसाधित करके आपके मूल्यांकन की जानकारी के साथ जोड़ा गया है।',

      'dataQuality': 'डेटा गुणवत्ता',
      'testQuality': 'टेस्ट गुणवत्ता',
      'dataQualityScore': 'डेटा गुणवत्ता स्कोर',
      'recordedSamples': 'रिकॉर्ड किए गए सैंपल',
      'recordingDuration': 'रिकॉर्डिंग अवधि',
      'sampleCoverage': 'सैंपल कवरेज',
      'timestampRegularity': 'टाइमस्टैम्प नियमितता',
      'sensorSignalQuality': 'सेंसर सिग्नल गुणवत्ता',
      'movementPresence': 'मूवमेंट की उपस्थिति',
      'good': 'अच्छा',
      'acceptable': 'स्वीकार्य',
      'repeatRecommended': 'दोबारा टेस्ट की सलाह',
      'technicalQualityExplanation':
          'यह स्कोर रिकॉर्ड किए गए सेंसर डेटा की तकनीकी गुणवत्ता बताता है। यह AI confidence score नहीं है और क्लिनिकल निदान नहीं दर्शाता।',

      'kneeMovement': 'घुटने की गति',
      'rangeOfMotion': 'गति की सीमा',
      'minimumAngle': 'न्यूनतम कोण',
      'maximumAngle': 'अधिकतम कोण',
      'movementVariability': 'मूवमेंट परिवर्तनशीलता',
      'repetitions': 'दोहराव',
      'averageCycle': 'औसत चक्र',
      'walkDuration': 'चलने की अवधि',
      'shinDynamicAcceleration': 'पिंडली का डायनेमिक एक्सेलेरेशन',

      'aiAssistedScreening': 'AI-सहायित प्रारंभिक स्क्रीनिंग',
      'aiScreening': 'AI स्क्रीनिंग',
      'aiScreeningUnavailable': 'AI स्क्रीनिंग उपलब्ध नहीं',
      'riskAssessment': 'जोखिम मूल्यांकन',
      'higherOARisk':
          'OA-संबंधित जोखिम अधिक होने का संकेत',
      'lowerOARisk':
          'OA-संबंधित जोखिम कम होने का संकेत',
      'modelEstimatedRisk':
          'मॉडल द्वारा अनुमानित OA-संबंधित जोखिम संभावना',
      'screeningThreshold': 'स्क्रीनिंग सीमा',
      'keyContributingFactors': 'मुख्य योगदान देने वाले कारक',
      'noRiskScoreGenerated':
          'कोई कृत्रिम जोखिम स्कोर उत्पन्न नहीं किया गया।',
      'modelNotConnected':
          'इस एप्लिकेशन से संगत प्रशिक्षित AI मॉडल अभी कनेक्ट नहीं है।',

      'clinicalInterpretation': 'क्लिनिकल व्याख्या',
      'clinicalEvaluationRecommended':
          'व्याख्या और आगे की देखभाल के लिए क्लिनिकल मूल्यांकन की सलाह दी जाती है।',
      'clinicalValidation': 'क्लिनिकल वैलिडेशन',
      'clinicalValidationText':
          'तकनीकी प्रोटोटाइप वैलिडेशन और क्लिनिकल वैलिडेशन अलग-अलग आवश्यकताएं हैं। क्लिनिकल वैलिडेशन के लिए क्लिनिकल रूप से लेबल किए गए प्रतिभागी, पूर्व-निर्धारित मूल्यांकन प्रक्रिया, स्वतंत्र मूल्यांकन और उपयुक्त प्रदर्शन माप की आवश्यकता होती है।',
      'notClinicallyValidated':
          'वर्तमान प्रोटोटाइप क्लिनिकल वैलिडेशन या डायग्नोस्टिक सटीकता का दावा नहीं करता।',
      'notDiagnosis':
          'AI-सहायित प्रारंभिक स्क्रीनिंग • निदान नहीं',

      'downloadReport': 'रिपोर्ट डाउनलोड करें',
      'generatingReport': 'स्क्रीनिंग रिपोर्ट बनाई जा रही है...',
      'reportGenerated': 'रिपोर्ट सफलतापूर्वक तैयार हुई।',
      'reportError': 'रिपोर्ट तैयार नहीं हो सकी।',

      'invalidTestData': 'टेस्ट डेटा अमान्य है',
      'pleaseFinishCurrentTest':
          'कृपया पहले वर्तमान टेस्ट पूरा करें या रद्द करें।',
      'somethingWentWrong': 'कुछ गलत हो गया।',
      'tryAgain': 'कृपया फिर से प्रयास करें।',

      'liveSensorData': 'लाइव सेंसर डेटा',
      'thigh': 'जांघ',
      'shin': 'पिंडली',
      'acceleration': 'एक्सेलेरेशन',
      'gyroscope': 'जायरोस्कोप',
    },

    // Regional languages will fall back to English for keys that have
    // not yet received clinically reviewed translations.
    'as': {},
    'bn': {},
    'mni': {},
    'kha': {},
    'lus': {},
    'ne': {},
    'nag': {},
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLanguages.supported.any(
      (language) => language.code == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale.languageCode);
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<AppLocalizations> old,
  ) {
    return false;
  }
}