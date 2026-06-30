import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:geoar/models/ar_location.dart';
import 'package:geoar/providers/ar_locations_provider.dart';
import 'package:geoar/services/media_service.dart';
import 'package:geoar/themes/app_theme.dart';
import 'package:geoar/utils/constants.dart';

class CreateArScreen extends StatefulWidget {
  // FIX: map_screen and search_screen both pass `location: loc` for edit mode.
  // Add an optional location parameter so the screen works for both create & edit.
  final ArLocation? location;

  const CreateArScreen({super.key, this.location});

  @override
  State<CreateArScreen> createState() => _CreateArScreenState();
}

class _CreateArScreenState extends State<CreateArScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Text controllers
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();
  final _textMsgCtrl = TextEditingController();

  // Form state
  late String _selectedCategory;
  late String _selectedModelType;
  String? _imagePath;
  String? _videoPath;
  String? _modelPath;
  bool _isSaving = false;

  bool get _isEditing => widget.location != null;

  @override
  void initState() {
    super.initState();
    // Pre-populate fields when editing an existing location.
    final loc = widget.location;
    _selectedCategory = loc?.category ?? AppConstants.categories.first;
    _selectedModelType = loc?.modelType ?? AppConstants.modelTypes.first['type']!;
    if (loc != null) {
      _titleCtrl.text = loc.title;
      _subtitleCtrl.text = loc.subtitle;
      _descriptionCtrl.text = loc.description;
      _latCtrl.text = loc.latitude.toString();
      _lonCtrl.text = loc.longitude.toString();
      _textMsgCtrl.text = loc.textMessage ?? '';
      _imagePath = loc.imagePath;
      _videoPath = loc.videoPath;
      _modelPath = loc.modelPath;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _descriptionCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _textMsgCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Media actions ─────────────────────────────────────────────────────────

  Future<void> _pickImageFromGallery() async {
    final path = await MediaService.instance.pickImageFromGallery();
    if (path != null && mounted) setState(() => _imagePath = path);
  }

  Future<void> _pickImageFromCamera() async {
    final path = await MediaService.instance.pickImageFromCamera();
    if (path != null && mounted) setState(() => _imagePath = path);
  }

  Future<void> _pickVideo() async {
    final path = await MediaService.instance.pickVideo();
    if (path != null && mounted) setState(() => _videoPath = path);
  }

  Future<void> _pick3DModel() async {
    final path = await MediaService.instance.pick3DModel();
    if (path != null && mounted) setState(() => _modelPath = path);
  }

  void _clearImage() => setState(() => _imagePath = null);
  void _clearVideo() => setState(() => _videoPath = null);
  void _clearModel() => setState(() => _modelPath = null);

  // ─── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final hasContent = _textMsgCtrl.text.trim().isNotEmpty ||
        _imagePath != null ||
        _videoPath != null;

    if (!hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add at least one piece of content: a text message, image, or video.',
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final provider = context.read<ArLocationsProvider>();

      if (_isEditing) {
        // Edit mode — update the existing location via copyWith.
        final updated = widget.location!.copyWith(
          title: _titleCtrl.text.trim(),
          subtitle: _subtitleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          latitude: double.parse(_latCtrl.text.trim()),
          longitude: double.parse(_lonCtrl.text.trim()),
          textMessage: _textMsgCtrl.text.trim().isEmpty
              ? null
              : _textMsgCtrl.text.trim(),
          imagePath: _imagePath,
          videoPath: _videoPath,
          modelPath: _modelPath,
          category: _selectedCategory,
          modelType: _selectedModelType,
          updatedDate: DateTime.now(),
        );
        await provider.updateLocation(updated);
      } else {
        // Create mode — build a brand-new location.
        final location = provider.createNew(
          title: _titleCtrl.text.trim(),
          subtitle: _subtitleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          latitude: double.parse(_latCtrl.text.trim()),
          longitude: double.parse(_lonCtrl.text.trim()),
          textMessage: _textMsgCtrl.text.trim().isEmpty
              ? null
              : _textMsgCtrl.text.trim(),
          imagePath: _imagePath,
          videoPath: _videoPath,
          modelPath: _modelPath,
          category: _selectedCategory,
          modelType: _selectedModelType,
        );
        await provider.addLocation(location);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text(_isEditing
                    ? 'AR pin updated successfully!'
                    : 'AR pin created successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(colorScheme, isDark),
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    _buildBasicInfoSection(colorScheme)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 100.ms)
                        .slideY(begin: 0.15, end: 0, duration: 400.ms, delay: 100.ms),
                    const SizedBox(height: 20),
                    _buildLocationSection(colorScheme)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 200.ms)
                        .slideY(begin: 0.15, end: 0, duration: 400.ms, delay: 200.ms),
                    const SizedBox(height: 20),
                    _buildCategorySection(colorScheme)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 300.ms)
                        .slideY(begin: 0.15, end: 0, duration: 400.ms, delay: 300.ms),
                    const SizedBox(height: 20),
                    _buildTextMessageSection(colorScheme)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 400.ms)
                        .slideY(begin: 0.15, end: 0, duration: 400.ms, delay: 400.ms),
                    const SizedBox(height: 20),
                    _buildImageSection(colorScheme)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 500.ms)
                        .slideY(begin: 0.15, end: 0, duration: 400.ms, delay: 500.ms),
                    const SizedBox(height: 20),
                    _buildVideoSection(colorScheme)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 600.ms)
                        .slideY(begin: 0.15, end: 0, duration: 400.ms, delay: 600.ms),
                    const SizedBox(height: 20),
                    _buildModelTypeSection(colorScheme)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 700.ms)
                        .slideY(begin: 0.15, end: 0, duration: 400.ms, delay: 700.ms),
                    const SizedBox(height: 32),
                    _buildSaveButton(colorScheme)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 800.ms)
                        .slideY(begin: 0.2, end: 0, duration: 400.ms, delay: 800.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SliverAppBar ──────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(ColorScheme colorScheme, bool isDark) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.primary,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.secondary,
                colorScheme.tertiary,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -20,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _isEditing
                              ? Icons.edit_location_alt_rounded
                              : Icons.add_location_alt_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isEditing ? 'Edit AR Pin' : 'Create AR Pin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isEditing
                            ? 'Update augmented reality content on the map'
                            : 'Place augmented reality content on the map',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section: Basic Info ───────────────────────────────────────────────────

  Widget _buildBasicInfoSection(ColorScheme colorScheme) {
    return _SectionCard(
      colorScheme: colorScheme,
      icon: Icons.edit_note_rounded,
      title: 'Basic Information',
      child: Column(
        children: [
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title *',
              prefixIcon: Icon(Icons.title_rounded),
              hintText: 'Name your AR pin',
            ),
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Title is required';
              if (v.trim().length < 2) return 'Title must be at least 2 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _subtitleCtrl,
            decoration: const InputDecoration(
              labelText: 'Subtitle *',
              prefixIcon: Icon(Icons.short_text_rounded),
              hintText: 'A short tagline',
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Subtitle is required';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _descriptionCtrl,
            decoration: const InputDecoration(
              labelText: 'Description *',
              prefixIcon: Icon(Icons.description_rounded),
              hintText: 'Describe what visitors will experience',
              alignLabelWithHint: true,
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 4,
            minLines: 3,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Description is required';
              if (v.trim().length < 10) return 'Description must be at least 10 characters';
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ─── Section: Location ─────────────────────────────────────────────────────

  Widget _buildLocationSection(ColorScheme colorScheme) {
    return _SectionCard(
      colorScheme: colorScheme,
      icon: Icons.location_on_rounded,
      title: 'GPS Coordinates',
      subtitle: 'Required — defines where the AR pin appears',
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _latCtrl,
              decoration: const InputDecoration(
                labelText: 'Latitude *',
                prefixIcon: Icon(Icons.swap_vert_rounded),
                hintText: '-90 to 90',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = double.tryParse(v.trim());
                if (n == null) return 'Invalid number';
                if (n < -90 || n > 90) return 'Must be -90 to 90';
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _lonCtrl,
              decoration: const InputDecoration(
                labelText: 'Longitude *',
                prefixIcon: Icon(Icons.swap_horiz_rounded),
                hintText: '-180 to 180',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = double.tryParse(v.trim());
                if (n == null) return 'Invalid number';
                if (n < -180 || n > 180) return 'Must be -180 to 180';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section: Category ─────────────────────────────────────────────────────

  Widget _buildCategorySection(ColorScheme colorScheme) {
    return _SectionCard(
      colorScheme: colorScheme,
      icon: Icons.category_rounded,
      title: 'Category',
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        decoration: const InputDecoration(
          labelText: 'Category',
          prefixIcon: Icon(Icons.label_rounded),
        ),
        items: AppConstants.categories
            .map(
              (c) => DropdownMenuItem(
                value: c,
                child: Text(c),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _selectedCategory = v);
        },
        validator: (v) => v == null ? 'Please select a category' : null,
      ),
    );
  }

  // ─── Section: Text Message ─────────────────────────────────────────────────

  Widget _buildTextMessageSection(ColorScheme colorScheme) {
    return _SectionCard(
      colorScheme: colorScheme,
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Text Message',
      subtitle: 'Optional — shown as AR overlay text',
      child: TextFormField(
        controller: _textMsgCtrl,
        decoration: const InputDecoration(
          labelText: 'Message',
          prefixIcon: Icon(Icons.message_rounded),
          hintText: 'Write a message to display in AR...',
          alignLabelWithHint: true,
        ),
        textCapitalization: TextCapitalization.sentences,
        maxLines: 4,
        minLines: 2,
        maxLength: 500,
      ),
    );
  }

  // ─── Section: Image ────────────────────────────────────────────────────────

  Widget _buildImageSection(ColorScheme colorScheme) {
    return _SectionCard(
      colorScheme: colorScheme,
      icon: Icons.image_rounded,
      title: 'Image',
      subtitle: 'Optional — displayed as AR image overlay',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_imagePath != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(_imagePath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _clearImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.greenAccent, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Image selected',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 300.ms)
                .scale(begin: const Offset(0.95, 0.95), duration: 300.ms),
            const SizedBox(height: 12),
          ] else
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined,
                      size: 36, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 6),
                  Text(
                    'No image selected',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImageFromGallery,
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImageFromCamera,
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Section: Video ────────────────────────────────────────────────────────

  Widget _buildVideoSection(ColorScheme colorScheme) {
    final hasVideo = _videoPath != null;
    final fileName = hasVideo ? _videoPath!.split('/').last : null;

    return _SectionCard(
      colorScheme: colorScheme,
      icon: Icons.videocam_rounded,
      title: 'Video',
      subtitle: 'Optional — plays back as AR video overlay',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hasVideo
                  ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasVideo
                    ? colorScheme.primary.withValues(alpha: 0.4)
                    : colorScheme.outlineVariant,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasVideo
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : colorScheme.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasVideo
                        ? Icons.play_circle_filled_rounded
                        : Icons.videocam_off_rounded,
                    color: hasVideo
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasVideo ? 'Video selected' : 'No video selected',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: hasVideo
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (fileName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          fileName,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasVideo)
                  IconButton(
                    onPressed: _clearVideo,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: colorScheme.error,
                    tooltip: 'Remove video',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickVideo,
            icon: const Icon(Icons.video_library_rounded, size: 18),
            label: const Text('Pick Video File'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section: 3D Model Type ────────────────────────────────────────────────

  Widget _buildModelTypeSection(ColorScheme colorScheme) {
    return _SectionCard(
      colorScheme: colorScheme,
      icon: Icons.view_in_ar_rounded,
      title: '3D AR Marker Style',
      subtitle: 'Choose the visual anchor displayed at this location',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: AppConstants.modelTypes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final model = AppConstants.modelTypes[index];
              final type = model['type']!;
              final label = model['label']!;
              final emoji = model['emoji']!;
              final isSelected = _selectedModelType == type;

              return GestureDetector(
                onTap: () => setState(() => _selectedModelType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        emoji,
                        style: TextStyle(
                          fontSize: isSelected ? 26 : 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 3),
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pick3DModel,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(
              _modelPath != null
                  ? 'Custom model: ${_modelPath!.split('/').last}'
                  : 'Upload Custom .glb / .gltf Model',
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_modelPath != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _clearModel,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Remove custom model'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Save Button ───────────────────────────────────────────────────────────

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return Consumer<ArLocationsProvider>(
      builder: (context, provider, _) {
        return SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              disabledBackgroundColor: colorScheme.primary.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 4,
              shadowColor: colorScheme.primary.withValues(alpha: 0.4),
            ),
            child: _isSaving
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Saving...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_isEditing ? Icons.save_rounded : Icons.add_location_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _isEditing ? 'Save Changes' : 'Create AR Pin',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onPrimary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

// ─── Reusable Section Card ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.colorScheme,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      borderRadius: 20,
      opacity: isDark ? 0.12 : 0.08,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.2),
                      colorScheme.secondary.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
