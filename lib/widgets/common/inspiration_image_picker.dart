import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/room_item.dart';
import '../../services/url_launcher_helper.dart';

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
  late TextEditingController _amazonUrlController;
  late TextEditingController _imageUrlController;
  late TextEditingController _priceController;

  bool _isEditingDetails = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.item.notes ?? '');
    _amazonUrlController = TextEditingController(text: widget.item.amazonUrl ?? '');
    _imageUrlController = TextEditingController(text: widget.item.imageUrl ?? '');
    _priceController = TextEditingController(text: widget.item.productPrice ?? '');
  }

  @override
  void didUpdateWidget(covariant InspirationImagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.amazonUrl != widget.item.amazonUrl) {
      _amazonUrlController.text = widget.item.amazonUrl ?? '';
    }
    if (oldWidget.item.imageUrl != widget.item.imageUrl) {
      _imageUrlController.text = widget.item.imageUrl ?? '';
    }
    if (oldWidget.item.notes != widget.item.notes) {
      _notesController.text = widget.item.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _amazonUrlController.dispose();
    _imageUrlController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
      if (photo != null) {
        final updated = widget.item.copyWith(
          imagePath: photo.path,
          notes: _notesController.text,
          amazonUrl: _amazonUrlController.text,
          imageUrl: _imageUrlController.text,
          productPrice: _priceController.text,
        );
        widget.onItemUpdated(updated);
        setState(() {});
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
    }
  }

  void _notifyUpdate() {
    final updated = widget.item.copyWith(
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      amazonUrl: _amazonUrlController.text.trim().isEmpty ? null : _amazonUrlController.text.trim(),
      imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
      productPrice: _priceController.text.trim().isEmpty ? null : _priceController.text.trim(),
    );
    widget.onItemUpdated(updated);
  }

  @override
  Widget build(BuildContext context) {
    final hasLocalImage = widget.item.imagePath != null && widget.item.imagePath!.isNotEmpty;
    final hasOnlineImage = widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty;
    final hasImage = hasLocalImage || hasOnlineImage;
    final hasAmazonUrl = widget.item.amazonUrl != null && widget.item.amazonUrl!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasAmazonUrl ? const Color(0xFFFF9900).withValues(alpha: 0.6) : const Color(0xFF334155),
          width: hasAmazonUrl ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
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
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasAmazonUrl)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9900).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFF9900), width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shopping_bag_outlined, color: Color(0xFFFF9900), size: 10),
                                SizedBox(width: 3),
                                Text(
                                  'Amazon',
                                  style: TextStyle(
                                    color: Color(0xFFFF9900),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${widget.item.width.toStringAsFixed(1)}m × ${widget.item.depth.toStringAsFixed(1)}m × ${widget.item.height.toStringAsFixed(1)}m',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isEditingDetails ? Icons.expand_less : Icons.tune,
                  color: const Color(0xFF38BDF8),
                  size: 18,
                ),
                tooltip: 'Advanced Product Details',
                onPressed: () => setState(() => _isEditingDetails = !_isEditingDetails),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Photo Preview / Picker Area
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasImage ? const Color(0xFF38BDF8) : const Color(0xFF475569),
                ),
              ),
              child: hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: hasOnlineImage
                              ? Image.network(
                                  widget.item.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, _, __) => hasLocalImage
                                      ? (kIsWeb
                                          ? Image.network(widget.item.imagePath!, fit: BoxFit.cover)
                                          : Image.file(File(widget.item.imagePath!), fit: BoxFit.cover))
                                      : const Center(
                                          child: Icon(Icons.broken_image, color: Colors.white38),
                                        ),
                                )
                              : (kIsWeb
                                  ? Image.network(widget.item.imagePath!, fit: BoxFit.cover)
                                  : Image.file(File(widget.item.imagePath!), fit: BoxFit.cover)),
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
                        if (widget.item.productPrice != null && widget.item.productPrice!.isNotEmpty)
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                widget.item.productPrice!,
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
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
                          '(e.g. Amazon product photo, headboard, wardrobe shutter)',
                          style: TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Amazon Product Link Input Field
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: hasAmazonUrl ? const Color(0xFFFF9900).withValues(alpha: 0.4) : Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, color: Color(0xFFFF9900), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amazonUrlController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Paste Amazon product link (optional)...',
                      hintStyle: TextStyle(color: Colors.white30, fontSize: 11.5),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) {
                      _notifyUpdate();
                      setState(() {});
                    },
                  ),
                ),
                if (hasAmazonUrl) ...[
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9900),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => UrlLauncherHelper.openUrl(widget.item.amazonUrl!),
                    icon: const Icon(Icons.open_in_new, size: 13),
                    label: const Text('Open in Amazon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Collapsible Advanced Product Spec Inputs
          if (_isEditingDetails) ...[
            // Direct Product Image URL input
            TextField(
              controller: _imageUrlController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                labelText: 'Direct Image URL (e.g. https://m.media-amazon.com/...)',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              onChanged: (_) {
                _notifyUpdate();
                setState(() {});
              },
            ),
            const SizedBox(height: 8),

            // Product Price / Brand
            TextField(
              controller: _priceController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                labelText: 'Product Price / Model (e.g. \$499 or ₹24,999 • Wakefit King Bed)',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              onChanged: (_) {
                _notifyUpdate();
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
          ],

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
              _notifyUpdate();
            },
          ),
        ],
      ),
    );
  }
}
