import 'package:flutter/material.dart';

class CadHoverDetail {
  final String title;
  final String subtitle;
  final String category; // 'FURNITURE ITEM', 'ROOM ZONE', 'OPENING & EGRESS', 'SANITARY FIXTURE', 'KITCHEN APPLIANCE', 'CONTROL HANDLE', 'CAD ANNOTATION'
  final IconData icon;
  final Color accentColor;
  final Map<String, String> keyMetrics; // e.g. {'Width': "5.50'", 'Length': "6.50'", 'Height': "3.20'", 'Area': "35.8 sq.ft"}
  final Map<String, String>? wallClearances; // {'West (Left)': '2.00 ft', 'East (Right)': '5.50 ft', 'South (Top)': '3.00 ft', 'North (Bottom)': 'FLUSH'}
  final String? position; // "X: 2.00', Y: 3.00'"
  final String? orientation; // "Facing South (↓) • 0° Rotation"
  final String? engineeringReason; // Architectural notes & clearance requirements
  final String? formula; // Formula calculation
  final String? interactionTip; // "💡 Drag to move • Drag handles to stretch • Click ⟳ to rotate"
  final Rect? targetRect; // The bounding box of the hovered element for highlight glow
  final Offset pointerPosition; // Where the mouse is in canvas space

  CadHoverDetail({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.accentColor,
    required this.keyMetrics,
    this.wallClearances,
    this.position,
    this.orientation,
    this.engineeringReason,
    this.formula,
    this.interactionTip,
    this.targetRect,
    required this.pointerPosition,
  });
}
