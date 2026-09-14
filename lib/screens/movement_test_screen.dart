import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/imu_data.dart';
import '../models/movement_test.dart';
import '../models/patient_assessment.dart';
import '../models/sensor_sample.dart';
import '../models/test_state.dart';
import '../services/movement_test_controller.dart';

class MovementTestScreen extends StatefulWidget {
  final MovementTestController controller;
  final PatientAssessment assessment;

  const MovementTestScreen({
    super.key,
    required this.controller,
    required this.assessment,
  });

  @override
  State<MovementTestScreen> createState() =>
      _MovementTestScreenState();
}

class _MovementTestScreenState
    extends State<MovementTestScreen> {
 AppLocalizations get _l =>
    AppLocalizations.of(context);

AppLocalizations get _l10n =>
    AppLocalizations.of(context);

  StreamSubscription<void>? _changeSubscription;

  bool _starting = false;
  bool _finished = false;

  MovementTestType _currentType =
      MovementTestType.chairStand;

  @override
  void initState() {
    super.initState();

    widget.controller.updatePatientAssessment(
      widget.assessment,
    );

    _changeSubscription =
        widget.controller.changes.listen((_) {
      if (!mounted) {
        return;
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    _changeSubscription?.cancel();
    super.dispose();
  }

  MovementTest get _currentTest {
    return _currentType ==
            MovementTestType.chairStand
        ? chairStandTest
        : fastWalkTest;
  }

  bool get _chairStandComplete =>
      widget.controller.screeningSession.hasChairStand;

  bool get _fastWalkComplete =>
      widget.controller.screeningSession.hasFastWalk;

  Future<void> _startCurrentTest() async {
    if (_starting || widget.controller.isBusy) {
      return;
    }

    setState(() {
      _starting = true;
    });

    await widget.controller.startTest(
      _currentTest,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _starting = false;
    });
  }

  Future<void> _finishCurrentTest() async {
    if (!widget.controller.canFinishTest) {
      return;
    }

    await widget.controller.stopTest();

    if (!mounted) {
      return;
    }

    setState(() {});

    if (_currentType ==
            MovementTestType.chairStand &&
        _chairStandComplete) {
      return;
    }

    if (_currentType ==
            MovementTestType.fastWalk &&
        _fastWalkComplete) {
      setState(() {
        _finished = true;
      });
    }
  }

  Future<void> _cancelTest() async {
    if (widget.controller.isBusy) {
      await widget.controller.cancelTest();
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _finishWorkflow() async {
    if (widget.controller.isBusy) {
      return;
    }

    setState(() {
      _finished = true;
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 250),
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final controller = widget.controller;

    return PopScope(
      canPop: !controller.isBusy,
      onPopInvokedWithResult:
          (didPop, result) {
        if (didPop) {
          return;
        }

        _showBusyMessage();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _l.get('movementTests'),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            if (!controller.isBusy)
              IconButton(
                tooltip: _l.get('cancelScreening'),
                onPressed: _cancelTest,
                icon: const Icon(
                  Icons.close_rounded,
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              28,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildProgress(
                  theme,
                  colors,
                ),

                const SizedBox(height: 20),

                _buildSensorStatus(
                  theme,
                  colors,
                ),

                const SizedBox(height: 18),

                _buildTestCard(
                  theme,
                  colors,
                ),

                const SizedBox(height: 18),

                if (controller.isPreparing ||
                    controller.isCalibrating ||
                    controller.isRunning)
                  _buildLiveCard(
                    theme,
                    colors,
                  ),

                if (controller.state ==
                    TestState.failed)
                  _buildErrorCard(
                    theme,
                    colors,
                  ),

                if (!controller.isPreparing &&
                    !controller.isCalibrating &&
                    !_finished)
                  _buildActionArea(
                    theme,
                    colors,
                  ),

                if (_finished)
                  _buildCompletionCard(
                    theme,
                    colors,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(
    ThemeData theme,
    ColorScheme colors,
  ) {
    final firstComplete =
        _chairStandComplete;
    final secondComplete =
        _fastWalkComplete;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          _l.get('step3Of4'),
          style: theme.textTheme.labelMedium
              ?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          _l.get('movementAssessment'),
          style: theme.textTheme.headlineSmall
              ?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 15),

        Row(
          children: [
            Expanded(
              child: _buildProgressItem(
                colors,
                number: '01',
                title: _l.get('chairStand'),
                completed: firstComplete,
                active:
                    _currentType ==
                        MovementTestType.chairStand,
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _buildProgressItem(
                colors,
                number: '02',
                title: _l.get('fastWalk'),
                completed: secondComplete,
                active:
                    _currentType ==
                        MovementTestType.fastWalk,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressItem(
    ColorScheme colors, {
    required String number,
    required String title,
    required bool completed,
    required bool active,
  }) {
    final highlighted =
        completed || active;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.primaryContainer
                .withValues(alpha: 0.45)
            : colors.surfaceContainerHighest
                .withValues(alpha: 0.55),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: active
              ? colors.primary
              : colors.outlineVariant
                  .withValues(alpha: 0.5),
          width: active ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: completed
                  ? colors.primary
                  : highlighted
                      ? colors.primary
                          .withValues(
                          alpha: 0.12,
                        )
                      : colors.surface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: completed
                ? const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  )
                : Text(
                    number,
                    style: TextStyle(
                      color: highlighted
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      fontWeight:
                          FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    highlighted
                        ? FontWeight.w700
                        : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorStatus(
    ThemeData theme,
    ColorScheme colors,
  ) {
    final sampleCount =
        widget.controller.sampleCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.sensors_rounded,
              color: colors.primary,
              size: 21,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _l.get('sensorData'),
                  style: theme.textTheme
                      .labelMedium
                      ?.copyWith(
                    color:
                        colors.onSurfaceVariant,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  widget.controller.isRunning
                      ? _l.get(
                          'receivingMovementSamples',
                        )
                      : _l.get('sensorsReady'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme
                      .bodyMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          if (widget.controller.isRunning)
            const SizedBox(width: 8),

          if (widget.controller.isRunning)
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: colors.primary
                    .withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Text(
                '$sampleCount ${_l.get('samples')}',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTestCard(
    ThemeData theme,
    ColorScheme colors,
  ) {
    final isChairStand =
        _currentType ==
            MovementTestType.chairStand;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.035),
            blurRadius: 18,
            offset:
                const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color:
                      colors.primaryContainer,
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Icon(
                  isChairStand
                      ? Icons.chair_rounded
                      : Icons.directions_walk_rounded,
                  color: colors.primary,
                  size: 27,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      isChairStand
                          ? _l.get('chairStand')
                          : _l.get('fastWalk20m'),
                      style: theme.textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      isChairStand
                          ? _l.get(
                              'lowerLimbFunctionalAssessment',
                            )
                          : _l.get(
                              'fastPacedWalkingAssessment',
                            ),
                      style: theme.textTheme
                          .bodySmall
                          ?.copyWith(
                        color:
                            colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: colors
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: colors.primary,
                  size: 20,
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Text(
                    isChairStand
                        ? _l.get(
                            'chairStandInstruction',
                          )
                        : _l.get(
                            'fastWalkInstruction',
                          ),
                    style: theme.textTheme
                        .bodySmall
                        ?.copyWith(
                      color:
                          colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCard(
    ThemeData theme,
    ColorScheme colors,
  ) {
    final controller =
        widget.controller;

    String title;
    String subtitle;
    IconData icon;

    if (controller.isPreparing) {
      title = _l.get('getReady');
      subtitle =
          _l.get('positionAndPrepare');
      icon = Icons.timer_outlined;
    } else if (controller.isCalibrating) {
      title = _l.get('calibrating');
      subtitle =
          _l.get('keepLegStillCalibration');
      icon = Icons.tune_rounded;
    } else {
      title = _l.get('testRunning');
      subtitle =
          _l.get('continueMovement');
      icon = Icons.fiber_manual_record_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer
            .withValues(alpha: 0.38),
        borderRadius:
            BorderRadius.circular(23),
        border: Border.all(
          color: colors.primary
              .withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: colors.primary,
            size: 30,
          ),

          const SizedBox(height: 8),

          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            subtitle,
            textAlign:
                TextAlign.center,
            style: theme.textTheme
                .bodySmall
                ?.copyWith(
              color:
                  colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 18),

          if (controller.isPreparing)
            _buildCountdown(
              controller.preparationSeconds,
              colors,
            ),

          if (controller.isCalibrating)
            _buildCountdown(
              controller.calibrationSeconds,
              colors,
            ),

          if (controller.isRunning)
            _buildTimer(
              controller.elapsedDuration,
              colors,
            ),

          if (controller.isRunning)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 18,
              ),
              child:
                  _buildLiveMovementGraph(
                colors,
              ),
            ),

          if (controller.isRunning &&
              _currentType ==
                  MovementTestType.fastWalk)
            Padding(
              padding:
                  const EdgeInsets.only(
                top: 18,
              ),
              child: Text(
                _l.get(
                  'complete20mThenFinish',
                ),
                textAlign:
                    TextAlign.center,
                style: theme.textTheme
                    .bodySmall
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveMovementGraph(
    ColorScheme colors,
  ) {
    final samples =
        widget.controller.recentSamples;

    if (samples.length < 2) {
      return Container(
        width: double.infinity,
        height: 190,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white
              .withValues(alpha: 0.72),
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color: colors.outlineVariant
                .withValues(alpha: 0.45),
          ),
        ),
        child: Text(
          _l.get(
            'waitingForMovementSamples',
          ),
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final visibleSamples =
        samples.length > 160
            ? samples.sublist(
                samples.length - 160,
              )
            : samples;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: 0.78),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart_rounded,
                size: 17,
                color: colors.primary,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  _l.get(
                    'liveMovementSignal',
                  ),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Text(
                '${visibleSamples.length} ${_l.get('points')}',
                style: TextStyle(
                  color:
                      colors.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          SizedBox(
            height: 145,
            width: double.infinity,
            child: CustomPaint(
              painter: _MovementGraphPainter(
                samples: visibleSamples,
                thighColor: colors.primary,
                shinColor: colors.secondary,
                gridColor: colors.outlineVariant
                    .withValues(alpha: 0.32),
                labelColor:
                    colors.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 7),

          _buildGraphLegend(colors),
        ],
      ),
    );
  }

  Widget _buildGraphLegend(
    ColorScheme colors,
  ) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 6,
      children: [
        _buildLegendItem(
          colors.primary,
          _l.get('thigh'),
        ),

        _buildLegendItem(
          colors.secondary,
          _l.get('shin'),
        ),

        Text(
          _l.get('gyroscopeMagnitude'),
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(
    Color color,
    String label,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                BorderRadius.circular(4),
          ),
        ),

        const SizedBox(width: 5),

        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCountdown(
    int seconds,
    ColorScheme colors,
  ) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: colors.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$seconds',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }  Widget _buildTimer(
    Duration duration,
    ColorScheme colors,
  ) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final tenths =
        (duration.inMilliseconds % 1000) ~/ 100;

    final formatted =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '$tenths';

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius:
            BorderRadius.circular(17),
      ),
      child: Text(
        formatted,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildActionArea(
    ThemeData theme,
    ColorScheme colors,
  ) {
    final hasStarted =
        widget.controller.screeningStarted;

    if (!hasStarted) {
      return const SizedBox.shrink();
    }

    if (widget.controller.isRunning) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed:
                  widget.controller.canFinishTest
                      ? _finishCurrentTest
                      : null,
              icon: const Icon(
                Icons.stop_circle_outlined,
              ),
              label: Text(
                _l10n.get('stopTest'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              style: FilledButton.styleFrom(
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(17),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _currentType ==
                    MovementTestType.chairStand
                ? _l10n.get(
                    'chairStand30SecondNote',
                  )
                : _l10n.get(
                    'fastWalk20mFinishNote',
                  ),
            textAlign: TextAlign.center,
            style: theme.textTheme
                .bodySmall
                ?.copyWith(
              color:
                  colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      );
    }

    final completedCurrent =
        _currentType ==
                MovementTestType.chairStand
            ? _chairStandComplete
            : _fastWalkComplete;

    if (completedCurrent) {
      return _buildNextAction(
        theme,
        colors,
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed:
            _starting
                ? null
                : _startCurrentTest,
        icon: Icon(
          _starting
              ? Icons.hourglass_top_rounded
              : Icons.play_arrow_rounded,
        ),
        label: Text(
          _starting
              ? _l10n.get('getReady').toUpperCase()
              : _l10n.get('startTest'),
          style: const TextStyle(
            fontWeight:
                FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }

  Widget _buildNextAction(
    ThemeData theme,
    ColorScheme colors,
  ) {
    final chairDone =
        _currentType ==
            MovementTestType.chairStand;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.primaryContainer
                .withValues(alpha: 0.42),
            borderRadius:
                BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Text(
                  chairDone
                      ? '${_l10n.get('chairStand')} ${_l10n.get('testCompleted')}'
                      : '${_l10n.get('fastWalk')} ${_l10n.get('testCompleted')}',
                  style: theme.textTheme
                      .bodyMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        _buildQualityCard(
          theme,
          colors,
          quality: chairDone
              ? widget.controller.chairStandQuality
              : widget.controller.fastWalkQuality,
        ),

        const SizedBox(height: 14),

        if (chairDone)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: () {
                setState(() {
                  _currentType =
                      MovementTestType.fastWalk;
                });
              },
              icon: const Icon(
                Icons.arrow_forward_rounded,
              ),
              label: Text(
                '${_l10n.get('next')} ${_l10n.get('fastWalk20m')}',
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              style:
                  FilledButton.styleFrom(
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                ),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed:
                  _finishWorkflow,
              icon: const Icon(
                Icons.auto_awesome_rounded,
              ),
              label: Text(
                _l10n.get(
                  'viewScreeningResults',
                ),
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              style:
                  FilledButton.styleFrom(
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQualityCard(
    ThemeData theme,
    ColorScheme colors, {
    required TestQualityResult? quality,
  }) {
    if (quality == null) {
      return const SizedBox.shrink();
    }

    final score = quality.score.round();

    final Color statusColor;
    final IconData statusIcon;

    if (quality.isGood) {
      statusColor = colors.primary;
      statusIcon = Icons.verified_rounded;
    } else if (quality.isAcceptable) {
      statusColor = Colors.orange.shade700;
      statusIcon =
          Icons.check_circle_outline_rounded;
    } else {
      statusColor = colors.error;
      statusIcon =
          Icons.warning_amber_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(
            alpha: 0.55,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 22,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _l10n.get('dataQuality'),
                      style: theme.textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      quality.label,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '$score/100',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (quality.score / 100)
                  .clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor:
                  colors.surfaceContainerHighest,
              valueColor:
                  AlwaysStoppedAnimation<Color>(
                statusColor,
              ),
            ),
          ),

          const SizedBox(height: 11),

          Text(
            quality.summary,
            style: theme.textTheme.bodySmall
                ?.copyWith(
              color:
                  colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildQualityMetric(
                  colors,
                  _l10n.get('sampleCoverage'),
                  '${quality.sampleCoverage.round()}%',
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _buildQualityMetric(
                  colors,
                  _l10n.get(
                    'timestampRegularity',
                  ),
                  '${quality.timestampRegularity.round()}%',
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildQualityMetric(
                  colors,
                  _l10n.get(
                    'sensorSignalQuality',
                  ),
                  '${quality.signalQuality.round()}%',
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _buildQualityMetric(
                  colors,
                  _l10n.get(
                    'movementPresence',
                  ),
                  '${quality.movementPresence.round()}%',
                ),
              ),
            ],
          ),

          if (quality.needsRepeat) ...[
            const SizedBox(height: 13),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: colors.errorContainer
                    .withValues(
                  alpha: 0.45,
                ),
                borderRadius:
                    BorderRadius.circular(13),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    color: colors.error,
                    size: 18,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      _l10n.get(
                        'repeatRecommended',
                      ),
                      style: TextStyle(
                        color:
                            colors.onErrorContainer,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQualityMetric(
    ColorScheme colors,
    String label,
    String value,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(
          alpha: 0.48,
        ),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    colors.onSurfaceVariant,
                fontSize: 10,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 5),

          Text(
            value,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 11,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }  Widget _buildErrorCard(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        top: 16,
      ),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.errorContainer
            .withValues(alpha: 0.48),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: colors.error
              .withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: colors.error,
                size: 27,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  _l10n.get('invalidTestData'),
                  style: theme.textTheme
                      .titleSmall
                      ?.copyWith(
                    color:
                        colors.onErrorContainer,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            
                _l10n.get('sensorValidationFailed'),
            style: theme.textTheme.bodySmall
                ?.copyWith(
              color:
                  colors.onErrorContainer,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 13),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: Text(
                _l10n.get('tryAgain'),
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colors.primaryContainer
                .withValues(alpha: 0.38),
            borderRadius:
                BorderRadius.circular(24),
            border: Border.all(
              color: colors.primary
                  .withValues(alpha: 0.16),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 35,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                _l10n.get(
                  'movementAssessmentComplete',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                _l10n.get(
                  'bothTestsRecorded',
                ),
                textAlign: TextAlign.center,
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

        const SizedBox(height: 16),

        _buildSessionSummary(
          theme,
          colors,
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 55,
          child: FilledButton.icon(
            onPressed:
                _finishWorkflow,
            icon: const Icon(
              Icons.auto_awesome_rounded,
            ),
            label: Text(
              _l10n.get(
                'viewScreeningResults',
              ),
              style: const TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            style: FilledButton.styleFrom(
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(17),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionSummary(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(21),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: colors.primary,
                  size: 21,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _l10n.get(
                        'screeningDataCollected',
                      ),
                      style: theme.textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      _l10n.get(
                        'movementAssessment',
                      ),
                      style: theme.textTheme
                          .bodySmall
                          ?.copyWith(
                        color:
                            colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          _buildSessionTestRow(
            theme,
            colors,
            title:
                _l10n.get('chairStand'),
            quality:
                widget.controller
                    .chairStandQuality,
          ),

          const SizedBox(height: 9),

          _buildSessionTestRow(
            theme,
            colors,
            title:
                _l10n.get('fastWalk20m'),
            quality:
                widget.controller
                    .fastWalkQuality,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTestRow(
    ThemeData theme,
    ColorScheme colors, {
    required String title,
    required TestQualityResult? quality,
  }) {
    if (quality == null) {
      return Container(
        padding:
            const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors
              .surfaceContainerHighest
              .withValues(alpha: 0.4),
          borderRadius:
              BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Icon(
              Icons.remove_circle_outline,
              size: 18,
              color:
                  colors.onSurfaceVariant,
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),

            Text(
              _l10n.get('notRecorded'),
              style: TextStyle(
                color:
                    colors.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    final score =
        quality.score.round();

    final statusColor =
        quality.isGood
            ? colors.primary
            : quality.isAcceptable
                ? Colors.orange.shade700
                : colors.error;

    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius:
            BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: statusColor,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  '${quality.sampleCount} ${_l10n.get('samples')} • '
                  '${quality.durationSeconds.toStringAsFixed(1)} ${_l10n.get('seconds')}',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        colors.onSurfaceVariant,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Text(
            '$score/100',
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  void _showBusyMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _l10n.get(
              'pleaseFinishCurrentTest',
            ),
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }
}

class _MovementGraphPainter
    extends CustomPainter {
  final List<SensorSample> samples;
  final Color thighColor;
  final Color shinColor;
  final Color gridColor;
  final Color labelColor;

  _MovementGraphPainter({
    required this.samples,
    required this.thighColor,
    required this.shinColor,
    required this.gridColor,
    required this.labelColor,
  });

  double _accelerationMagnitude(
    ImuData imu,
  ) {
    return sqrt(
      imu.ax * imu.ax +
          imu.ay * imu.ay +
          imu.az * imu.az,
    );
  }

  double _gyroMagnitude(
    ImuData imu,
  ) {
    return sqrt(
      imu.gx * imu.gx +
          imu.gy * imu.gy +
          imu.gz * imu.gz,
    );
  }

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (samples.isEmpty ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    final chartRect = Rect.fromLTWH(
      34,
      8,
      max(1, size.width - 42),
      max(1, size.height - 28),
    );

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    const horizontalLines = 4;

    for (var i = 0;
        i <= horizontalLines;
        i++) {
      final y = chartRect.top +
          chartRect.height *
              (i / horizontalLines);

      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final thighValues =
        samples.map(
      (sample) =>
          _accelerationMagnitude(
        sample.thigh,
      ),
    ).toList();

    final shinValues =
        samples.map(
      (sample) =>
          _accelerationMagnitude(
        sample.shin,
      ),
    ).toList();

    final gyroValues =
        samples.map(
      (sample) =>
          (_gyroMagnitude(
                sample.thigh,
              ) +
              _gyroMagnitude(
                sample.shin,
              )) /
          2,
    ).toList();

    final allValues = [
      ...thighValues,
      ...shinValues,
      ...gyroValues,
    ];

    var minValue =
        allValues.reduce(min);
    var maxValue =
        allValues.reduce(max);

    if ((maxValue - minValue).abs() <
        0.0001) {
      minValue -= 1;
      maxValue += 1;
    }

    final padding =
        (maxValue - minValue) * 0.08;

    minValue -= padding;
    maxValue += padding;

    _drawLine(
      canvas,
      chartRect,
      thighValues,
      minValue,
      maxValue,
      thighColor,
    );

    _drawLine(
      canvas,
      chartRect,
      shinValues,
      minValue,
      maxValue,
      shinColor,
    );

    _drawLine(
      canvas,
      chartRect,
      gyroValues,
      minValue,
      maxValue,
      labelColor.withValues(
        alpha: 0.45,
      ),
      dashed: true,
    );

    final textStyle = TextStyle(
      color: labelColor,
      fontSize: 8,
      fontWeight: FontWeight.w500,
    );

    final topLabel =
        maxValue.toStringAsFixed(1);
    final bottomLabel =
        minValue.toStringAsFixed(1);

    _drawText(
      canvas,
      topLabel,
      Offset(
        2,
        chartRect.top - 4,
      ),
      textStyle,
    );

    _drawText(
      canvas,
      bottomLabel,
      Offset(
        2,
        chartRect.bottom - 7,
      ),
      textStyle,
    );
  }

  void _drawLine(
    Canvas canvas,
    Rect rect,
    List<double> values,
    double minValue,
    double maxValue,
    Color color, {
    bool dashed = false,
  }) {
    if (values.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (!dashed) {
      final path = Path();

      for (var i = 0;
          i < values.length;
          i++) {
        final x = values.length == 1
            ? rect.center.dx
            : rect.left +
                rect.width *
                    (i /
                        (values.length - 1));

        final normalized =
            ((values[i] - minValue) /
                    (maxValue - minValue))
                .clamp(0.0, 1.0);

        final y = rect.bottom -
            normalized * rect.height;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(
        path,
        paint,
      );

      return;
    }

    const dashLength = 5.0;
    const gapLength = 4.0;

    for (var i = 1;
        i < values.length;
        i++) {
      final x1 = rect.left +
          rect.width *
              ((i - 1) /
                  max(1, values.length - 1));

      final x2 = rect.left +
          rect.width *
              (i /
                  max(1, values.length - 1));

      final n1 =
          ((values[i - 1] - minValue) /
                  (maxValue - minValue))
              .clamp(0.0, 1.0);

      final n2 =
          ((values[i] - minValue) /
                  (maxValue - minValue))
              .clamp(0.0, 1.0);

      final y1 =
          rect.bottom -
              n1 * rect.height;

      final y2 =
          rect.bottom -
              n2 * rect.height;

      final start =
          Offset(x1, y1);
      final end =
          Offset(x2, y2);

      final distance =
          (end - start).distance;

      if (distance <= 0) {
        continue;
      }

      final direction =
          (end - start) / distance;

      var travelled = 0.0;

      while (travelled < distance) {
        final dashStart =
            travelled;

        final dashEnd =
            min(
              travelled + dashLength,
              distance,
            );

        canvas.drawLine(
          start +
              direction * dashStart,
          start +
              direction * dashEnd,
          paint,
        );

        travelled +=
            dashLength + gapLength;
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style,
      ),
      textDirection:
          TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      offset,
    );
  }

  @override
  bool shouldRepaint(
    covariant _MovementGraphPainter oldDelegate,
  ) {
    return oldDelegate.samples != samples ||
        oldDelegate.thighColor !=
            thighColor ||
        oldDelegate.shinColor !=
            shinColor ||
        oldDelegate.gridColor !=
            gridColor ||
        oldDelegate.labelColor !=
            labelColor;
  }
}