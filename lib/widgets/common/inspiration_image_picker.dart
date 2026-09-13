import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/room_item.dart';

class InspirationImagePicker extends StatefulWidget {
  final RoomItem item;
  final Function(RoomItem updatedItem) onItemUpdated;

  const InspirationImagePicker({
    super.key,
    required this.item,
    required this.onItemUpdated,
  });

  @override
  State<InspirationImagePicker> createState() => _InspirationImagePickerState();
}

class _InspirationImagePickerState extends State<InspirationImagePicker> {
  final ImagePicker _picker = ImagePicker();
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.item.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
      if (photo != null) {
        final updated = widget.item.copyWith(
          imagePath: photo.path,
          notes: _notesController.text,
        );
        widget.onItemUpdated(updated);
        setState(() {});
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.item.imagePath != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.item.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.style, color: widget.item.primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${widget.item.width.toStringAsFixed(1)}m × ${widget.item.depth.toStringAsFixed(1)}m × ${widget.item.height.toStringAsFixed(1)}m',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Photo Preview / Picker Area
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasImage ? const Color(0xFF38BDF8) : const Color(0xFF475569),
                  style: BorderStyle.solid,
                ),
              ),
              child: hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: kIsWeb
                              ? Image.network(widget.item.imagePath!, fit: BoxFit.cover)
                              : Image.file(File(widget.item.imagePath!), fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text('Change Photo', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF38BDF8), size: 30),
                        SizedBox(height: 6),
                        Text(
                          'Upload Reference / Inspiration Picture',
                          style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '(e.g. Wardrobe shutter style, Bed headboard, Tile finish)',
                          style: TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Custom Design Notes
          TextField(
            controller: _notesController,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Design specs / Finish notes (e.g. Fluted charcoal panels, matte black handles)...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              final updated = widget.item.copyWith(notes: val);
              widget.onItemUpdated(updated);
            },
          ),
        ],
      ),
    );
  }
}
