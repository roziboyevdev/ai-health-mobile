import 'package:flutter/material.dart';

import '../localization/app_strings.dart';

enum HealthMetricType {
  sleep,
  heart,
  bloodPressure,
  spo2,
  stress,
  met,
  ecg,
  steps,
}

extension HealthMetricTypeSlug on HealthMetricType {
  String get slug {
    switch (this) {
      case HealthMetricType.sleep:
        return 'sleep';
      case HealthMetricType.heart:
        return 'heart';
      case HealthMetricType.bloodPressure:
        return 'blood-pressure';
      case HealthMetricType.spo2:
        return 'spo2';
      case HealthMetricType.stress:
        return 'stress';
      case HealthMetricType.met:
        return 'met';
      case HealthMetricType.ecg:
        return 'ecg';
      case HealthMetricType.steps:
        return 'steps';
    }
  }

  static HealthMetricType fromSlug(String? value) {
    if (value == 'activity') return HealthMetricType.steps;
    return HealthMetricType.values.firstWhere(
      (type) => type.slug == value,
      orElse: () => HealthMetricType.heart,
    );
  }
}

class MetricDisplayValue {
  const MetricDisplayValue({
    required this.value,
    this.unit = '',
    this.supporting,
    this.count = 0,
    this.status,
  });

  final String value;
  final String unit;
  final String? supporting;
  final int count;
  final String? status;

  static const empty = MetricDisplayValue(value: '--');
}

class HealthMetricDefinition {
  const HealthMetricDefinition({
    required this.type,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    this.unit = '',
    this.canMeasure = false,
  });

  final HealthMetricType type;
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String unit;
  final bool canMeasure;
}

List<HealthMetricDefinition> healthMetricDefinitions(AppStrings strings) {
  return [
    HealthMetricDefinition(
      type: HealthMetricType.sleep,
      icon: Icons.bedtime_outlined,
      color: Colors.indigo,
      title: strings.sleep,
      description: strings.sleepDescription,
      unit: 'h',
    ),
    HealthMetricDefinition(
      type: HealthMetricType.heart,
      icon: Icons.favorite,
      color: Colors.pink,
      title: strings.heartRate,
      description: strings.heartDescription,
      unit: strings.isRu ? 'уд/мин' : 'zarb/daqiqa',
      canMeasure: true,
    ),
    HealthMetricDefinition(
      type: HealthMetricType.bloodPressure,
      icon: Icons.monitor_heart_outlined,
      color: Colors.teal,
      title: strings.bloodPressure,
      description: strings.bloodPressureDescription,
      unit: strings.isRu ? 'мм рт. ст.' : 'mm sim. ust.',
      canMeasure: true,
    ),
    HealthMetricDefinition(
      type: HealthMetricType.spo2,
      icon: Icons.bloodtype_outlined,
      color: Colors.cyan,
      title: strings.oxygen,
      description: strings.oxygenDescription,
      unit: '%',
      canMeasure: true,
    ),
    HealthMetricDefinition(
      type: HealthMetricType.stress,
      icon: Icons.psychology_outlined,
      color: Colors.deepPurple,
      title: strings.stress,
      description: strings.stressDescription,
      canMeasure: true,
    ),
    HealthMetricDefinition(
      type: HealthMetricType.met,
      icon: Icons.local_fire_department_outlined,
      color: Colors.green,
      title: strings.met,
      description: strings.metDescription,
      unit: 'MET',
    ),
    HealthMetricDefinition(
      type: HealthMetricType.ecg,
      icon: Icons.monitor_heart_outlined,
      color: Colors.blueGrey,
      title: strings.ecg,
      description: strings.ecgDescription,
      canMeasure: true,
    ),
  ];
}
