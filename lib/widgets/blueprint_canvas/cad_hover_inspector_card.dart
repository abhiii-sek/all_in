import 'package:flutter/material.dart';
import '../../models/cad_hover_detail.dart';

class CadHoverInspectorCard extends StatelessWidget {
  final CadHoverDetail detail;
  final Size canvasSize;

  const CadHoverInspectorCard({
    super.key,
    required this.detail,
    required this.canvasSize,
  });

  @override
  Widget build(BuildContext context) {
    const cardWidth = 330.0;
    
    // Position card intelligently near the cursor without going offscreen
    final cursor = detail.pointerPosition;
    double left = cursor.dx + 18.0;
    double top = cursor.dy + 18.0;

    if (left + cardWidth > canvasSize.width - 20) {
      left = cursor.dx - cardWidth - 18.0;
    }
    if (left < 20) left = 20;

    if (top + 280 > canvasSize.height - 20) {
      top = cursor.dy - 280;
    }
    if (top < 20) top = 20;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          width: cardWidth,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: detail.accentColor.withValues(alpha: 0.65), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: detail.accentColor.withValues(alpha: 0.20),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Category Badge + Title + Icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: detail.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: detail.accentColor.withValues(alpha: 0.4)),
                    ),
                    child: Icon(detail.icon, color: detail.accentColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: detail.accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            detail.category,
                            style: TextStyle(
                              color: detail.accentColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          detail.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (detail.subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  detail.subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],

              const SizedBox(height: 10),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              const SizedBox(height: 10),

              // Key Metrics Grid
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: detail.keyMetrics.entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          entry.value,
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              // 4-Wall Clearances (if present)
              if (detail.wallClearances != null && detail.wallClearances!.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  '4-WALL CLEARANCE GAPS (RECALIBRATED):',
                  style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Row(
                  children: detail.wallClearances!.entries.map((entry) {
                    final isFlush = entry.value == 'FLUSH';
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
                        decoration: BoxDecoration(
                          color: isFlush
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                              : const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: isFlush
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                                : const Color(0xFF10B981).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              entry.key.split(' ').first,
                              style: TextStyle(
                                color: isFlush ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              entry.value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Position & Orientation
              if (detail.position != null || detail.orientation != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (detail.position != null)
                      Expanded(
                        child: Text(
                          '📍 Position: ${detail.position}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (detail.orientation != null)
                      Expanded(
                        child: Text(
                          '🧭 ${detail.orientation}',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right,
                        ),
                      ),
                  ],
                ),
              ],

              // Engineering Rationale
              if (detail.engineeringReason != null && detail.engineeringReason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D33),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 13),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          detail.engineeringReason!,
                          style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.25),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Interaction Tip
              if (detail.interactionTip != null && detail.interactionTip!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  detail.interactionTip!,
                  style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 9.5, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
