import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/ble_sensor_service.dart';
import 'ble_connection_screen.dart';

enum SensorMode {
  demo,
  wearable,
}

class SensorSetupScreen extends StatefulWidget {
  final BleSensorService bleService;
  final SensorMode initialMode;

  const SensorSetupScreen({
    super.key,
    required this.bleService,
    this.initialMode = SensorMode.demo,
  });

  @override
  State<SensorSetupScreen> createState() =>
      _SensorSetupScreenState();
}

class _SensorSetupScreenState
    extends State<SensorSetupScreen> {
  late SensorMode _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
  }

  Future<void> _openWearableConnection() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BleConnectionScreen(
          bleService: widget.bleService,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (widget.bleService.isConnected) {
      setState(() {
        _selectedMode = SensorMode.wearable;
      });
    }
  }

  void _continue() {
    final l10n = AppLocalizations.of(context);
    if (_selectedMode == SensorMode.wearable &&
        !widget.bleService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.get('connectSensors'),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(_selectedMode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final wearableConnected =
        widget.bleService.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.get('sensorSetup'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            28,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildProgressHeader(
                theme,
                colors,
              ),

              const SizedBox(height: 22),

              _buildHeroCard(
                theme,
                colors,
              ),

              const SizedBox(height: 24),

              Text(
                'Choose sensor source',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                'Use the wearable for live IMU data or '
                'continue in demo mode while hardware '
                'is unavailable.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 16),

              _buildModeCard(
                context: context,
                mode: SensorMode.demo,
                icon: Icons.science_outlined,
                title: 'Demo Sensor Mode',
                subtitle:
                    'Use simulated thigh and shin IMU data',
                description:
                    'Recommended for development and '
                    'demonstration when the physical '
                    'KneeBand is not connected.',
                badge: 'AVAILABLE',
                selected:
                    _selectedMode == SensorMode.demo,
              ),

              const SizedBox(height: 12),

              _buildModeCard(
                context: context,
                mode: SensorMode.wearable,
                icon: Icons.bluetooth_connected_rounded,
                title: 'KneeBand Wearable',
                subtitle:
                    'Use live thigh + shin IMU data',
                description:
                    'Connect the KneeBand over Bluetooth '
                    'Low Energy and receive live sensor '
                    'packets from the wearable.',
                badge: wearableConnected
                    ? 'CONNECTED'
                    : 'NOT CONNECTED',
                selected:
                    _selectedMode ==
                        SensorMode.wearable,
                connected:
                    wearableConnected,
              ),

              const SizedBox(height: 14),

              if (_selectedMode ==
                      SensorMode.wearable &&
                  !wearableConnected)
                _buildConnectButton(
                  context,
                  colors,
                ),

              const SizedBox(height: 24),

              _buildSensorPlacementCard(
                theme,
                colors,
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _continue,
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                  ),
                  label: const Text(
                    'CONTINUE TO MOVEMENT TESTS',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.25,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(17),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Center(
                child: Text(
                  'Two IMUs are used for thigh–shin '
                  'movement analysis',
                  textAlign: TextAlign.center,
                  style:
                      theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius:
                BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            '02',
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Step 2 of 4',
                style:
                    theme.textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Prepare your movement sensors',
                style:
                    theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(
              alpha: 0.13,
            ),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.16,
              ),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.sensors_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Wearable movement sensing',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The system captures movement from '
                  'two body segments — the thigh and '
                  'shin — to estimate knee motion.',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: Colors.white.withValues(
                      alpha: 0.88,
                    ),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required SensorMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required String badge,
    required bool selected,
    bool connected = false,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      borderRadius:
          BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _selectedMode = mode;
        });
      },
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer
                  .withValues(alpha: 0.42)
              : Colors.white,
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? colors.primary
                : colors.outlineVariant
                    .withValues(alpha: 0.55),
            width: selected ? 1.5 : 1,
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
                color: selected
                    ? colors.primary
                    : colors.primaryContainer,
                borderRadius:
                    BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: selected
                    ? Colors.white
                    : colors.primary,
                size: 25,
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(width: 8),
                      _buildBadge(
                        badge,
                        connected,
                        colors,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitle,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    description,
                    style: theme
                        .textTheme
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

            const SizedBox(width: 8),

            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? colors.primary
                  : colors.outline,
              size: 23,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(
    String text,
    bool connected,
    ColorScheme colors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: connected
            ? colors.primary.withValues(
                alpha: 0.12,
              )
            : colors.surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: connected
              ? colors.primary
              : colors.onSurfaceVariant,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildConnectButton(
    BuildContext context,
    ColorScheme colors,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _openWearableConnection,
        icon: const Icon(
          Icons.bluetooth_searching_rounded,
        ),
        label: const Text(
          'SCAN & CONNECT KNEEBAND',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.25,
          ),
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _buildSensorPlacementCard(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius:
            BorderRadius.circular(19),
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
                Icons.info_outline_rounded,
                color: colors.primary,
                size: 22,
              ),
              const SizedBox(width: 9),
              Text(
                'Sensor placement',
                style: theme.textTheme.titleSmall
                    ?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _buildPlacementRow(
            colors,
            Icons.looks_one_rounded,
            'Thigh sensor',
            'Secure on the thigh segment.',
          ),

          const SizedBox(height: 8),

          _buildPlacementRow(
            colors,
            Icons.looks_two_rounded,
            'Shin sensor',
            'Secure on the shin segment.',
          ),

          const SizedBox(height: 10),

          Text(
            'Consistent sensor orientation and '
            'placement are important for reliable '
            'movement measurements.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacementRow(
    ColorScheme colors,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: colors.primary,
          size: 20,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 13,
              ),
              children: [
                TextSpan(
                  text: '$title — ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: description,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}