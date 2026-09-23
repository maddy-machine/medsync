import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter/cupertino.dart';
import 'localization/app_localizations.dart';
import 'models/patient_assessment.dart';
import 'models/screening_model.dart';
import 'screens/camera_vision_test_screen.dart';
import 'screens/movement_test_screen.dart';
import 'screens/patient_assessment_screen.dart';
import 'screens/sensor_setup_screen.dart';
import 'screens/screening_results_screen.dart';
import 'services/ble_sensor_service.dart';
import 'services/mock_sensor_service.dart';
import 'services/movement_test_controller.dart';
import 'services/screening_model_loader.dart';
import 'services/screening_inference_service.dart';
import 'services/sensor_service.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ScreeningModel? screeningModel;

  try {
    screeningModel =
        await const ScreeningModelLoader().load();
  } catch (error) {
    debugPrint(
      'Screening model could not be loaded: $error',
    );
  }

  runApp(
    MedSyncApp(
      screeningModel: screeningModel,
    ),
  );
}

/// Material localization wrapper.
///
/// Our application supports additional North-Eastern
/// languages that Flutter's built-in Material localization
/// package may not directly provide.
///
/// For those languages, Flutter's internal Material labels
/// safely fall back to English while MedSync's own patient-facing
/// translations continue using the selected language.
class MedSyncMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const MedSyncMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return true;
  }

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final supported =
        GlobalMaterialLocalizations.delegate.isSupported(
      locale,
    );

    return GlobalMaterialLocalizations.delegate.load(
      supported ? locale : const Locale('en'),
    );
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<MaterialLocalizations> old,
  ) {
    return false;
  }
}

/// Widgets localization wrapper.
///
/// Unsupported regional locales fall back to English for
/// Flutter's internal accessibility/widget messages.
class MedSyncWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const MedSyncWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return true;
  }

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    final supported =
        GlobalWidgetsLocalizations.delegate.isSupported(
      locale,
    );

    return GlobalWidgetsLocalizations.delegate.load(
      supported ? locale : const Locale('en'),
    );
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<WidgetsLocalizations> old,
  ) {
    return false;
  }
}

/// Cupertino localization wrapper.
///
/// This keeps Flutter's internal Cupertino widgets safe even
/// when the selected MedSync language is not natively supported
/// by Flutter.
class MedSyncCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const MedSyncCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return true;
  }

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    final supported =
        GlobalCupertinoLocalizations.delegate.isSupported(
      locale,
    );

    return GlobalCupertinoLocalizations.delegate.load(
      supported ? locale : const Locale('en'),
    );
  }

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<CupertinoLocalizations> old,
  ) {
    return false;
  }
}

class MedSyncApp extends StatefulWidget {
  final ScreeningModel? screeningModel;

  const MedSyncApp({
    super.key,
    required this.screeningModel,
  });

  @override
  State<MedSyncApp> createState() => _MedSyncAppState();
}

class _MedSyncAppState extends State<MedSyncApp> {
  Locale _locale = const Locale('en');

  void _changeLanguage(String languageCode) {
    setState(() {
      _locale = Locale(languageCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: AppLocalizations(_locale.languageCode)
          .get('appTitle'),

      locale: _locale,

      supportedLocales: AppLanguages.supported
          .map(
            (language) => Locale(language.code),
          )
          .toList(),

      localizationsDelegates: const [
        AppLocalizations.delegate,
        MedSyncMaterialLocalizationsDelegate(),
        MedSyncWidgetsLocalizationsDelegate(),
        MedSyncCupertinoLocalizationsDelegate(),
      ],

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          primary: const Color(0xFF0F766E),
          primaryContainer: const Color(0xFFCCFBF1),
          secondary: const Color(0xFF0284C7),
          secondaryContainer: const Color(0xFFE0F2FE),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),

      home: ScreeningHomePage(
        screeningModel: widget.screeningModel,
        onLanguageChanged: _changeLanguage,
      ),
    );
  }
}

class ScreeningHomePage extends StatefulWidget {
  final ScreeningModel? screeningModel;
  final ValueChanged<String> onLanguageChanged;

  const ScreeningHomePage({
    super.key,
    required this.screeningModel,
    required this.onLanguageChanged,
  });

  @override
  State<ScreeningHomePage> createState() =>
      _ScreeningHomePageState();
}

class _ScreeningHomePageState
    extends State<ScreeningHomePage> {
  PatientAssessment _assessment =
      PatientAssessment.empty();

  SensorMode _sensorMode = SensorMode.demo;

  BleSensorService? _bleSensorService;
  MockSensorService? _mockSensorService;
  MovementTestController? _movementController;

  bool _creatingWorkflow = false;

  BleSensorService _getBleService() {
    return _bleSensorService ??=
        BleSensorService();
  }

  MockSensorService _getMockService() {
    return _mockSensorService ??=
        MockSensorService();
  }

  Future<void> _openDirectCameraVision() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraVisionTestScreen(
          patientAssessment: _assessment,
        ),
      ),
    );
  }

  Future<void> _openAssessment() async {

    final result =
        await Navigator.of(context).push<
            PatientAssessment>(
      MaterialPageRoute(
        builder: (_) =>
            PatientAssessmentScreen(
          initialAssessment: _assessment,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _assessment = result;
    });

    await _openSensorSetup();
  }

  Future<void> _openSensorSetup() async {
    final bleService = _getBleService();

    final result =
        await Navigator.of(context).push<
            SensorMode>(
      MaterialPageRoute(
        builder: (_) =>
            SensorSetupScreen(
          bleService: bleService,
          initialMode: _sensorMode,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _sensorMode = result;
    });

    await _openMovementTests();
  }

  Future<void> _openMovementTests() async {
    if (_creatingWorkflow) {
      return;
    }

    setState(() {
      _creatingWorkflow = true;
    });

    await _disposeMovementController();

    final SensorService sensorService;

    if (_sensorMode == SensorMode.wearable) {
      sensorService = _getBleService();
    } else {
      sensorService = _getMockService();
    }

    final controller =
        MovementTestController(
      sensorService: sensorService,
      screeningInferenceService:
          ScreeningInferenceService(
        model: widget.screeningModel,
      ),
    );

    controller.updatePatientAssessment(
      _assessment,
    );

    await controller.startNewScreening();

    _movementController = controller;

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _creatingWorkflow = false;
    });

    final completed =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            MovementTestScreen(
          controller: controller,
          assessment: _assessment,
        ),
      ),
    );

    if (!mounted) {
      await _disposeMovementController();
      return;
    }

    if (completed == true) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ScreeningResultsScreen(
            controller: controller,
          ),
        ),
      );
    }

    if (!mounted) {
      return;
    }

    await _disposeMovementController();
  }

  Future<void> _disposeMovementController() async {
    final controller = _movementController;

    _movementController = null;

    if (controller != null) {
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _movementController?.dispose();
    _bleSensorService?.dispose();
    _mockSensorService?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            28,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildHeader(
                theme,
                l10n,
              ),

              const SizedBox(height: 20),

              _buildLanguageSelector(
                context,
                l10n,
              ),

              const SizedBox(height: 20),

              _buildHeroCard(
                context,
                colors,
                l10n,
              ),

              const SizedBox(height: 14),

              _buildCameraVisionQuickCard(
                context,
                colors,
              ),

              const SizedBox(height: 24),


              Text(
                l10n.get('howItWorks'),
                style: theme.textTheme.titleLarge
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),

              _buildStepCard(
                context,
                number: '01',
                icon:
                    Icons.person_outline_rounded,
                title: l10n.get(
                  'tellUsHowYouFeel',
                ),
                description: l10n.get(
                  'tellUsHowYouFeelDescription',
                ),
              ),

              const SizedBox(height: 10),

              _buildStepCard(
                context,
                number: '02',
                icon: Icons.sensors_rounded,
                title: l10n.get(
                  'setUpMovementSensors',
                ),
                description: l10n.get(
                  'setUpMovementSensorsDescription',
                ),
              ),

              const SizedBox(height: 10),

              _buildStepCard(
                context,
                number: '03',
                icon:
                    Icons.directions_walk_rounded,
                title: l10n.get(
                  'completeMovementTests',
                ),
                description: l10n.get(
                  'completeMovementTestsDescription',
                ),
              ),

              const SizedBox(height: 10),

              _buildStepCard(
                context,
                number: '04',
                icon:
                    Icons.auto_awesome_rounded,
                title: l10n.get(
                  'getAiAssessment',
                ),
                description: l10n.get(
                  'getAiAssessmentDescription',
                ),
              ),

              const SizedBox(height: 24),

              _buildInfoCard(
                context,
                colors,
                l10n,
              ),

              const SizedBox(height: 18),

              Center(
                child: Text(
                  l10n.get(
                    'preliminaryDisclaimer',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(
                    color:
                        colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius:
                BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.accessibility_new_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'MedSync',
                style: theme.textTheme.titleLarge
                    ?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),

              Text(
                l10n.get('movementHealth'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.language_rounded,
            color: colors.primary,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              l10n.get('language'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: l10n.languageCode,
              borderRadius:
                  BorderRadius.circular(14),
              items: AppLanguages.supported
                  .map(
                    (language) =>
                        DropdownMenuItem<String>(
                      value: language.code,
                      child: Text(
                        language.nativeName,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (languageCode) {
                if (languageCode == null) {
                  return;
                }

                widget.onLanguageChanged(
                  languageCode,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.primaryContainer,
          ],
        ),
        borderRadius:
            BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(
              alpha: 0.14,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.16,
              ),
              borderRadius:
                  BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 16,
                ),

                const SizedBox(width: 6),

                Text(
                  l10n.get(
                    'aiAssistedScreening',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          Text(
            l10n.get(
              'understandKneeMovement',
            ),
            style: theme.textTheme
                .headlineMedium
                ?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.08,
              letterSpacing: -0.7,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            l10n.get('heroDescription'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(
              color:
                  Colors.white.withValues(
                alpha: 0.88,
              ),
              height: 1.45,
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _openAssessment,
              icon: const Icon(
                Icons.arrow_forward_rounded,
              ),
              label: Text(
                l10n.get('startScreening'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.white,
                foregroundColor:
                    const Color(0xFF176B87),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraVisionQuickCard(
    BuildContext context,
    ColorScheme colors,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.secondary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.secondary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.videocam_rounded,
              color: colors.secondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'AI Camera Vision',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'NEW',
                        style: TextStyle(
                          color: colors.secondary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '10-sec posture & movement analysis',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _openDirectCameraVision,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.secondary,
              side: BorderSide(color: colors.secondary),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Test Now',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(

    BuildContext context, {
    required String number,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primaryContainer
                  .withValues(alpha: 0.65),
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: colors.primary,
              size: 24,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      number,
                      style: theme
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                        color: colors.primary,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        title,
                        style: theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                Text(
                  description,
                  style: theme.textTheme
                      .bodySmall
                      ?.copyWith(
                    color:
                        colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    ColorScheme colors,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.secondaryContainer
            .withValues(alpha: 0.42),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            color: colors.primary,
            size: 23,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.get(
                    'designedToSupport',
                  ),
                  style: theme.textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  l10n.get(
                    'supportDescription',
                  ),
                  style: theme.textTheme
                      .bodySmall
                      ?.copyWith(
                    color:
                        colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}