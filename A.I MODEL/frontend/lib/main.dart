import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

// ============================================================================
// Design tokens
//
// The app is a code-aware AI workspace, so the visual language borrows from
// developer tools rather than generic SaaS chrome: flat surfaces, hairline
// borders instead of soft drop shadows, a precise type scale, and a single
// warm accent (amber) reserved for the assistant's presence, with a cool
// teal kept for secondary/informational states. Structure is drawn with
// lines and spacing, not gradients or glass blur.
// ============================================================================

class AppColors {
  static const ink = Color(0xFF0A0B0F); // page background
  static const inkRaised = Color(0xFF10121A); // header / rail background
  static const surface = Color(0xFF171A24); // cards, panels
  static const surfaceAlt = Color(0xFF1D2029); // editor / input fields
  static const surfaceHover = Color(0xFF232733);

  static const line = Color(0x1FFFFFFF); // hairline borders
  static const lineStrong = Color(0x38FFFFFF);

  static const text = Color(0xFFEDEEF3);
  static const textMuted = Color(0xFF9096A6);
  static const textFaint = Color(0xFF5D6273);

  static const amber = Color(0xFFE7A33E); // primary accent — assistant
  static const amberSoft = Color(0x24E7A33E);
  static const amberBorder = Color(0x59E7A33E);

  static const teal = Color(0xFF54B7AD); // secondary accent — workspace
  static const tealSoft = Color(0x1F54B7AD);
  static const tealBorder = Color(0x4554B7AD);

  static const success = Color(0xFF6FCF97);
  static const successSoft = Color(0x1F6FCF97);
  static const danger = Color(0xFFE2635C);
  static const dangerSoft = Color(0x1FE2635C);

  // Background wireframe field
  static const wireLine = Color(0x1EE7ECF5);
  static const wireLineBright = Color(0x4CE7ECF5);
  static const wireCore = Color(0xFFF3F5FA);

  // Chrome — translucent so the wireframe field reads through the frame
  static const chrome = Color(0xE60B0C11);
  static const chromeStrong = Color(0xF20E1017);
}

// ----------------------------------------------------------------------
// Typography
//
// Font update: swapped the body/UI face from Inter to Plus Jakarta Sans,
// which has warmer, slightly rounder letterforms that read better at the
// small sizes this chat-heavy UI leans on, while Inter Tight stays for
// display/headings (it's still the more geometric, editorial of the two).
// Base sizes were nudged up half a point and line-heights opened up so
// paragraphs of assistant text breathe instead of feeling clipped.
// ----------------------------------------------------------------------
class AppType {
  static TextStyle display(
    double size, {
    Color color = AppColors.text,
    FontWeight weight = FontWeight.w600,
    double height = 1.18,
  }) =>
      GoogleFonts.interTight(
          fontSize: size,
          color: color,
          fontWeight: weight,
          height: height,
          letterSpacing: -0.3);

  static TextStyle body(
    double size, {
    Color color = AppColors.text,
    FontWeight weight = FontWeight.w400,
    double height = 1.55,
  }) =>
      GoogleFonts.plusJakartaSans(
          fontSize: size,
          color: color,
          fontWeight: weight,
          height: height,
          letterSpacing: 0.05);

  static TextStyle mono(
    double size, {
    Color color = AppColors.text,
    FontWeight weight = FontWeight.w400,
    double height = 1.6,
  }) =>
      GoogleFonts.jetBrainsMono(
          fontSize: size, color: color, fontWeight: weight, height: height);
}

// ============================================================================
// Background wireframe field
//
// The single bold visual moment in the app: a slow, quiet perspective grid
// converging on a faceted core, with one twisting bright band descending
// from it — the "signal" running through the workspace. Used once, as a
// backdrop behind translucent chrome, not repeated as decoration elsewhere.
// ============================================================================

class WireframeField extends StatefulWidget {
  const WireframeField({super.key});

  @override
  State<WireframeField> createState() => _WireframeFieldState();
}

class _WireframeFieldState extends State<WireframeField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 34),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: WireframeFieldPainter(_controller.value),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class WireframeFieldPainter extends CustomPainter {
  final double t;

  WireframeFieldPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.ink);

    final sway = math.sin(t * math.pi * 2) * size.width * 0.015;
    final core = Offset(size.width * 0.5 + sway, size.height * 0.3);

    final linePaint = Paint()
      ..color = AppColors.wireLine
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    final brightPaint = Paint()
      ..color = AppColors.wireLineBright
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Fan of lines rising from the full width of the bottom edge, and from
    // the top edge, all converging toward the core. Slight per-line bow
    // gives the field its perspective/tunnel feel rather than flat rays.
    const rays = 46;
    for (var i = 0; i <= rays; i++) {
      final f = i / rays;
      final bottomX = size.width * f;
      final start = Offset(bottomX, size.height * 1.02);
      final bow = (f - 0.5) * size.width * 0.34;
      final control = Offset(
        core.dx + bow * 0.7,
        size.height * 0.72,
      );
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, core.dx, core.dy);
      canvas.drawPath(path, i % 7 == 0 ? brightPaint : linePaint);

      final topX = size.width * f;
      final topStart = Offset(topX, -size.height * 0.05);
      final topControl = Offset(core.dx - bow * 0.5, size.height * 0.14);
      final topPath = Path()
        ..moveTo(topStart.dx, topStart.dy)
        ..quadraticBezierTo(topControl.dx, topControl.dy, core.dx, core.dy);
      canvas.drawPath(topPath, i % 9 == 0 ? brightPaint : linePaint);
    }

    // Twisting bright spine running from the core down to the bottom —
    // the "ribbon" that anchors the field and reads as depth, not noise.
    final spinePaint = Paint()
      ..color = AppColors.wireLineBright
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    for (var i = -3; i <= 3; i++) {
      final offset = i * size.width * 0.016;
      final path = Path()..moveTo(core.dx + offset * 0.2, core.dy);
      final twist = math.sin(t * math.pi * 2 + i) * size.width * 0.05;
      path.cubicTo(
        core.dx + offset + twist,
        size.height * 0.55,
        core.dx - offset - twist * 0.6,
        size.height * 0.8,
        core.dx + offset * 1.4,
        size.height * 1.02,
      );
      canvas.drawPath(path, spinePaint);
    }

    // A soft glow behind the core, then the faceted "gem" itself.
    final glow = Paint()
      ..color = const Color(0x33E7ECF5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(core, 26, glow);

    _drawGem(canvas, core, 13 + math.sin(t * math.pi * 2) * 1.2);
  }

  void _drawGem(Canvas canvas, Offset center, double radius) {
    const facetCount = 6;
    final outer = <Offset>[];
    for (var i = 0; i < facetCount; i++) {
      final angle = (i / facetCount) * math.pi * 2 - math.pi / 2;
      outer.add(Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius * 0.72,
      ));
    }

    final fill = Path()..moveTo(outer.first.dx, outer.first.dy);
    for (final point in outer.skip(1)) {
      fill.lineTo(point.dx, point.dy);
    }
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.wireCore,
          AppColors.wireLineBright,
        ]).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final facetPaint = Paint()
      ..color = const Color(0x99080910)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    for (final point in outer) {
      canvas.drawLine(center, point, facetPaint);
    }
    canvas.drawPath(
      fill,
      Paint()
        ..color = const Color(0x8CFFFFFF)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant WireframeFieldPainter oldDelegate) =>
      oldDelegate.t != t;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // The local API fallback keeps desktop builds usable without .env.
  }
  runApp(const AiModelApp());
}

class AiModelApp extends StatelessWidget {
  const AiModelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Juveh A.I',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const HomePage(),
    );
  }

  ThemeData _buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.amber,
      brightness: Brightness.dark,
      surface: AppColors.surface,
      surfaceContainerHighest: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.chrome,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.display(15, weight: FontWeight.w600),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        hintStyle: AppType.body(13.5, color: AppColors.textFaint),
        prefixIconColor: AppColors.textMuted,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.amber, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.ink,
          textStyle: AppType.body(13.5, weight: FontWeight.w600),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return AppColors.ink.withValues(alpha: 0.10);
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.ink.withValues(alpha: 0.16);
            }
            return null;
          }),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          hoverColor: AppColors.amberSoft,
          highlightColor: AppColors.amberSoft,
          foregroundColor: AppColors.textMuted,
        ).copyWith(
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.teal,
          overlayColor: AppColors.amberSoft,
          textStyle: AppType.body(13.5, weight: FontWeight.w600),
        ).copyWith(
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),
      dividerColor: AppColors.line,
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.chrome,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.lineStrong),
        ),
        textStyle: AppType.body(11.5, color: AppColors.text),
      ),
    );
  }
}

class _NavItem {
  final int id;
  final IconData icon;
  final String label;
  const _NavItem(this.id, this.icon, this.label);
}

const List<_NavItem> _navItems = [
  _NavItem(1, Icons.auto_awesome_outlined, 'Assistant'),
  _NavItem(5, Icons.folder_outlined, 'Workspace'),
  _NavItem(6, Icons.chat_bubble_outline, 'Chat'),
  _NavItem(3, Icons.tune_outlined, 'Settings'),
  _NavItem(4, Icons.help_outline, 'Help'),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static final apiBaseUrl =
      dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:4000';
  static const _maxChatImages = 3;
  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<ChatMessage> _workspaceMessages = [];
  final List<ChatMessage> _chatMessages = [];
  final List<ChatAttachment> _attachments = [];
  final List<WorkspaceActivity> _workspaceActivity = [];
  final List<WorkspaceAction> _pendingWorkspaceActions = [];
  String? _workspacePath;
  String? _selectedFilePath;
  String? _originalCode;
  String? _proposedCode;
  List<ChatMessage>? _pendingRequestMessages;
  List<FileSystemEntity> _workspaceFiles = [];
  final Set<String> _expandedDirectories = <String>{};
  final List<String> _openFiles = <String>[];
  bool _explorerCollapsed = false;
  bool _activityCollapsed = false;
  double _explorerWidth = 240;
  double _activityWidth = 200;
  double _ideSplit = 0.6;
  int _selectedView = 1;
  bool _isSending = false;
  bool _chatScrollScheduled = false;

  // The full-document TextField lags badly past a couple thousand lines
  // because Flutter relays out the entire block on every keystroke. Instead,
  // large files default to this virtualized, line-by-line view: a
  // ListView.builder that only ever renders the lines on screen, with a
  // single line swapped for a small TextField when the user taps it to
  // edit. "Raw edit mode" (the old full TextField) stays available as a
  // fallback for bulk pastes/multi-line edits.
  List<String> _codeLines = [];
  bool _rawEditMode = false;
  int? _editingLineIndex;
  TextEditingController? _lineEditController;
  FocusNode? _lineEditFocusNode;
  bool _lineEditCommitScheduled = false;

  @override
  void dispose() {
    _chatController.dispose();
    _codeController.dispose();
    _chatScrollController.dispose();
    _lineEditController?.dispose();
    _lineEditFocusNode?.dispose();
    super.dispose();
  }

  Future<void> _pickChatAttachments() async {
    final remainingSlots = _maxChatImages - _attachments.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can attach up to 3 screenshots.')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.image,
    );
    if (result == null) return;

    final picked = <ChatAttachment>[];
    for (final file in result.files.take(remainingSlots)) {
      final path = file.path;
      if (path == null) continue;
      try {
        final bytes = await File(path).readAsBytes();
        if (!_isImageFile(path) || bytes.length > 8 * 1024 * 1024) continue;
        picked.add(ChatAttachment(
          name: file.name,
          kind: 'image',
          content:
              'data:${_imageMimeType(path)};base64,${base64Encode(bytes)}',
        ));
      } catch (_) {
        // Ignore files the desktop picker cannot read.
      }
    }

    if (!mounted || picked.isEmpty) return;
    setState(() => _attachments.addAll(picked));
    if (result.files.length > remainingSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only 3 screenshots can be attached.')),
      );
    }
  }

  bool _isImageFile(String path) {
    final name = path.toLowerCase();
    return name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif');
  }

  String _imageMimeType(String path) {
    final name = path.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  // --------------------------------------------------------------------
  // Layout shell
  // --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Container(
      color: AppColors.ink,
      child: Stack(
        children: [
          const Positioned.fill(child: WireframeField()),
          Positioned.fill(
            child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(child: _getViewContent()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          _buildRail(),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.line),
          Expanded(child: _getViewContent()),
        ],
      ),
    );
  }

  Widget _buildRail() {
    return Container(
      width: 72,
      color: AppColors.chrome,
      child: Column(
        children: [
          Container(
            height: 64,
            alignment: Alignment.center,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.amberBorder),
              ),
              alignment: Alignment.center,
              child: Text('J',
                  style: AppType.display(16,
                      color: AppColors.amber, weight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          for (final item in _navItems) _buildRailItem(item),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isSending ? AppColors.amber : AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRailItem(_NavItem item) {
    final isSelected =
        _selectedView == item.id || (item.id == 3 && _selectedView == 2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Tooltip(
        message: item.label,
        waitDuration: const Duration(milliseconds: 400),
        child: _HoverAction(
          enabled: true,
          onTap: () => setState(() => _selectedView = item.id),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.amberSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.amberBorder : Colors.transparent,
              ),
            ),
            child: Icon(
              item.icon,
              size: 20,
              color: isSelected ? AppColors.amber : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final ids = _navItems.map((e) => e.id).toList();
    var currentIndex = ids.indexOf(_selectedView);
    if (currentIndex == -1) currentIndex = 0;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.chrome,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (final item in _navItems)
                Expanded(
                  child: _HoverAction(
                    enabled: true,
                    onTap: () => setState(() => _selectedView = item.id),
                    borderRadius: BorderRadius.zero,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon,
                            size: 20,
                            color: _selectedView == item.id
                                ? AppColors.amber
                                : AppColors.textMuted),
                        const SizedBox(height: 4),
                        Text(item.label,
                            style: AppType.body(10.5,
                                color: _selectedView == item.id
                                    ? AppColors.amber
                                    : AppColors.textMuted,
                                weight: FontWeight.w600)),
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

  Widget _getViewContent() {
    switch (_selectedView) {
      case 1:
        return _buildIdeView();
      case 2:
      case 3:
        return _buildSettingsView();
      case 4:
        return _buildHelpView();
      case 5:
        return _buildWorkspaceView();
      case 6:
        return _buildChatView(workspaceEnabled: false, title: 'Juveh Chat');
      default:
        return _buildIdeView();
    }
  }

  // --------------------------------------------------------------------
  // Chat
  // --------------------------------------------------------------------

  Widget _buildChatView({
    bool workspaceEnabled = true,
    String title = 'Assistant',
  }) {
    // Juveh Chat (workspaceEnabled: false) mirrors a ChatGPT-style single
    // conversation: a wider centered column, a pill input, and plain,
    // avatar-led assistant replies instead of bubbles. The workspace
    // assistant (workspaceEnabled: true, paired with the file panel) keeps
    // the calmer Claude-style split-view treatment it already had.
    final gptStyle = !workspaceEnabled;
    final messages = workspaceEnabled ? _workspaceMessages : _chatMessages;

    if (gptStyle) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Text(title, style: AppType.display(16, weight: FontWeight.w600)),
          ),
          Expanded(
            child: messages.isEmpty
                ? _buildChatWelcome(workspaceEnabled)
                : _buildMessageList(
                    messages: messages,
                    showWorkspaceContext: false,
                    gptStyle: true,
                  ),
          ),
          _buildChatInput(workspaceEnabled: false, gptStyle: true),
        ],
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          decoration: const BoxDecoration(
            color: AppColors.chrome,
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppType.display(16)),
                        const SizedBox(height: 3),
                        Text(
                          'Reads and edits files in your open workspace',
                          style: AppType.body(12.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedFilePath != null)
                    _buildFileContextChip(_selectedFilePath!),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ghostButton(
                    icon: Icons.edit_note,
                    label: 'Edit selected file',
                    onPressed: _selectedFilePath == null || _isSending
                        ? null
                        : _editSelectedFileFromChat,
                  ),
                  const SizedBox(width: 8),
                  _ghostButton(
                    icon: Icons.folder_outlined,
                    label: 'Open workspace',
                    onPressed: () => setState(() => _selectedView = 5),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: messages.isEmpty
              ? _buildChatWelcome(workspaceEnabled)
              : _buildMessageList(
                  messages: messages, showWorkspaceContext: workspaceEnabled),
        ),
        if (_pendingWorkspaceActions.isNotEmpty) _buildWorkspaceApprovalBar(),
        _buildChatInput(workspaceEnabled: true),
      ],
    );
  }

  Widget _ghostButton(
      {required IconData icon,
      required String label,
      required VoidCallback? onPressed}) {
    return _HoverAction(
      enabled: onPressed != null,
      borderRadius: BorderRadius.circular(7),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.line),
          color: onPressed == null ? Colors.transparent : AppColors.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: onPressed == null
                    ? AppColors.textFaint
                    : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(label,
                style: AppType.body(11.5,
                    color: onPressed == null
                        ? AppColors.textFaint
                        : AppColors.text,
                    weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatWelcome(bool workspaceEnabled) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.amberBorder),
              ),
              child: const Icon(Icons.auto_awesome_outlined,
                  color: AppColors.amber, size: 20),
            ),
            const SizedBox(height: 16),
            Text('Ask Juveh anything',
                style: AppType.display(18, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              workspaceEnabled
                  ? 'It can see the file you have open and propose edits you review before they apply.'
                  : 'This thread stays separate from your workspace files.',
              textAlign: TextAlign.center,
              style: AppType.body(13.5, color: AppColors.textMuted, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList({
    required List<ChatMessage> messages,
    bool showWorkspaceContext = true,
    bool gptStyle = false,
  }) {
    _scheduleChatScroll();

    if (gptStyle) {
      return Center(
        child: ConstrainedBox(
          // Widened from 720 -> 820 so long-form replies get a little more
          // breathing room on wide desktop windows without feeling like a
          // full-bleed page.
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            itemCount: messages.length + (_isSending ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == messages.length) return _buildThinkingRow();
              return _buildGptMessageRow(messages, index);
            },
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _chatScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return Align(
          alignment:
              message.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: message.isUser ? AppColors.amberSoft : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: message.isUser ? AppColors.amberBorder : AppColors.line,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showWorkspaceContext &&
                    !message.isUser &&
                    _selectedFilePath != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      _fileTypeLabel(_selectedFilePath!),
                      style: AppType.body(10.5,
                          color: AppColors.teal, weight: FontWeight.w700),
                    ),
                  ),
                _buildMessageContent(message.text),
              ],
            ),
          ),
        );
      },
    );
  }

  // ChatGPT-style row: user turns are a right-aligned pill bubble; assistant
  // turns are plain (no bubble/border) with a small avatar, and reveal a
  // copy/regenerate action row on hover — mirroring the reference layout.
  Widget _buildGptMessageRow(List<ChatMessage> messages, int index) {
    final message = messages[index];

    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 22),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
          ),
          child: _buildMessageContent(message.text),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 2, right: 14),
            decoration: BoxDecoration(
              color: AppColors.amberSoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.amberBorder),
            ),
            alignment: Alignment.center,
            child: Text('J',
                style: AppType.display(11,
                    color: AppColors.amber, weight: FontWeight.w700)),
          ),
          Expanded(
            child: _HoverReveal(
              builder: (revealed) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.lineStrong),
                    ),
                    child: _buildMessageContent(message.text),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: revealed ? 1 : 0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _gptActionIcon(
                            Icons.copy_outlined,
                            'Copy',
                            () async {
                              await Clipboard.setData(
                                  ClipboardData(text: message.text));
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Copied to clipboard.')),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          _gptActionIcon(
                            Icons.refresh,
                            'Regenerate',
                            _isSending
                                ? null
                                : () => _regenerateJuvehReply(index),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 22),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: AppColors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Text('Juveh is thinking…',
                  style: AppType.body(13.5, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gptActionIcon(IconData icon, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: _HoverAction(
        enabled: onTap != null,
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 14, color: AppColors.textMuted),
        ),
      ),
    );
  }

  Future<void> _regenerateJuvehReply(int index) async {
    if (_isSending || index <= 0 || index >= _chatMessages.length) return;
    final history = List<ChatMessage>.from(_chatMessages.sublist(0, index));
    setState(() => _isSending = true);
    final reply = await _requestAssistantReply(
      conversationMessages: history,
      includeWorkspace: false,
    );
    if (!mounted) return;
    setState(() {
      _chatMessages[index] = ChatMessage(
        text: reply ?? _fallbackReply(history.last.text),
        isUser: false,
      );
      _isSending = false;
    });
  }

  void _scheduleChatScroll() {
    if (_chatScrollScheduled) return;
    _chatScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatScrollScheduled = false;
      if (!mounted || !_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildMessageContent(String text) {
    if (text.trim().isEmpty) {
      return Text(
        'Juveh did not return a response. Please try again.',
        style: AppType.body(15, color: AppColors.text, height: 1.7),
      );
    }
    final match = RegExp(r'```([^\n]*)\n([\s\S]*?)```').firstMatch(text);
    if (match == null) {
      return SelectableText(
        text,
        style: AppType.body(15, color: AppColors.text, height: 1.7),
      );
    }

    final language = match.group(1)?.trim();
    final code = match.group(2) ?? '';
    final before = text.substring(0, match.start).trim();
    final after = text.substring(match.end).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (before.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SelectableText(
              before,
              style: AppType.body(15, color: AppColors.text, height: 1.7),
            ),
          ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: const BoxDecoration(
                  color: AppColors.chrome,
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    Text(
                      (language == null || language.isEmpty)
                          ? 'code'
                          : language,
                      style: AppType.mono(10.5, color: AppColors.textMuted),
                    ),
                    const Spacer(),
                    _HoverAction(
                      enabled: true,
                      borderRadius: BorderRadius.circular(5),
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Code copied to clipboard.')),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.copy_outlined,
                            size: 15, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Text(code, style: AppType.mono(12.5)),
                ),
              ),
            ],
          ),
        ),
        if (after.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SelectableText(
              after,
              style: AppType.body(15, color: AppColors.text, height: 1.7),
            ),
          ),
      ],
    );
  }

  Widget _buildAttachmentStrip() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 30,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _attachments.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final attachment = _attachments[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.tealBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image_outlined,
                      size: 13, color: AppColors.teal),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(attachment.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(11)),
                  ),
                  const SizedBox(width: 4),
                  _HoverAction(
                    enabled: true,
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(() => _attachments.removeAt(index)),
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(Icons.close,
                          size: 13, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChatInput({bool workspaceEnabled = true, bool gptStyle = false}) {
    if (gptStyle) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        child: Center(
          child: ConstrainedBox(
            // Widened from 900 -> 980 to match the wider message column
            // above, and to give Windows desktop windows a roomier feel.
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              children: [
                if (_attachments.isNotEmpty) _buildAttachmentStrip(),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _HoverAction(
                        enabled: !_isSending,
                        borderRadius: BorderRadius.circular(999),
                        onTap: _isSending ? null : _pickChatAttachments,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.image_outlined,
                              size: 18, color: AppColors.teal),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          style: AppType.body(14.5),
                          minLines: 1,
                          maxLines: 6,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submitJuvehChat(),
                          decoration: const InputDecoration(
                            hintText: 'Message Juveh…',
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _HoverAction(
                        enabled: !_isSending,
                        borderRadius: BorderRadius.circular(999),
                        onTap: _isSending ? null : _submitJuvehChat,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: AppColors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_upward,
                              size: 17, color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
                ],
              ),
            ),
          ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: const BoxDecoration(
        color: AppColors.chrome,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        children: [
          if (_attachments.isNotEmpty) _buildAttachmentStrip(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (workspaceEnabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, right: 6),
                  child: _HoverAction(
                    enabled: !_isSending,
                    borderRadius: BorderRadius.circular(8),
                    onTap: _isSending ? null : _pickChatAttachments,
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      child: const Icon(Icons.attach_file,
                          size: 19, color: AppColors.teal),
                    ),
                  ),
                ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: TextField(
                    controller: _chatController,
                    style: AppType.body(14.5),
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => workspaceEnabled
                        ? _submitMessage()
                        : _submitJuvehChat(),
                    decoration: const InputDecoration(
                      hintText: 'Message Juveh…',
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: workspaceEnabled ? _submitMessage : _submitJuvehChat,
                child: const Text('Send'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> _requestAssistantReply({
    List<ChatMessage>? conversationMessages,
    List<ChatMessage>? requestMessages,
    bool allowWorkspaceChanges = false,
    bool includeWorkspace = true,
    List<ChatAttachment>? attachments,
    Map<String, String>? openFile,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages':
              (requestMessages ?? conversationMessages ?? _workspaceMessages)
                  .map((message) => {
                        'role': message.isUser ? 'user' : 'assistant',
                        'content': message.text,
                      })
                  .toList(),
          'workspacePath': includeWorkspace ? _workspacePath : null,
          // Sent on every workspace-chat turn so the assistant always knows
          // which file is open — no "Edit selected file" click required.
          'openFile': includeWorkspace ? openFile : null,
          'allowWorkspaceChanges': includeWorkspace && allowWorkspaceChanges,
            'attachments': (attachments ?? const <ChatAttachment>[])
              .map((attachment) => attachment.toJson())
              .toList(),
        }),
      );

      if (response.statusCode != 200) {
        return 'Juveh AI is temporarily offline. Please start the backend and try again.';
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (includeWorkspace) {
        _pendingWorkspaceActions
          ..clear()
          ..addAll((data['pendingActions'] as List<dynamic>? ?? []).map(
              (item) =>
                  WorkspaceAction.fromJson(item as Map<String, dynamic>)));
      }
      if (includeWorkspace &&
          data['pendingActions'] is List &&
          (data['pendingActions'] as List).isNotEmpty) {
        _workspaceActivity.insert(
          0,
          WorkspaceActivity(
            label: 'Approval requested',
            detail:
                '${(data['pendingActions'] as List).length} workspace operation(s) waiting',
            icon: Icons.shield_outlined,
          ),
        );
      }
      final content = data['content'] as String?;
      return content == null || content.trim().isEmpty ? null : content;
    } catch (_) {
      return 'Juveh AI is temporarily offline. Please start the backend and try again.';
    }
  }

  Widget _buildWorkspaceApprovalBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.tealSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.tealBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 17, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Juveh wants to change files in your workspace. Review before it runs.',
              style: AppType.body(13),
            ),
          ),
          TextButton(
            onPressed: _isSending ? null : _approveWorkspaceActions,
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveWorkspaceActions() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.line),
        ),
        title: Text('Approve workspace changes?', style: AppType.display(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _pendingWorkspaceActions
              .map((action) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${action.name}: ${action.path}',
                        style: AppType.body(13.5)),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve')),
        ],
      ),
    );
    if (approved != true || _pendingRequestMessages == null || _isSending) {
      return;
    }

    setState(() => _isSending = true);
    final reply = await _requestAssistantReply(
      requestMessages: _pendingRequestMessages,
      allowWorkspaceChanges: true,
      openFile: _currentOpenFileContext(),
    );
    if (!mounted) return;
    setState(() {
      _workspaceMessages.add(ChatMessage(
          text: reply ?? 'Workspace changes completed.', isUser: false));
      _isSending = false;
      _pendingRequestMessages = null;
      _workspaceActivity.insert(
        0,
        const WorkspaceActivity(
          label: 'AI workspace update',
          detail: 'Approved changes completed',
          icon: Icons.auto_awesome_outlined,
        ),
      );
    });
  }

  Future<void> _editSelectedFileFromChat() async {
    if (_selectedFilePath == null || _isSending) return;

    final fileName = _selectedFilePath!.split(Platform.pathSeparator).last;
    final prompt = '''Edit the file "$fileName" according to the user's request.
Return only the complete updated file inside one markdown code block. Do not omit unchanged code or add explanations outside the code block.

User request:
${_chatController.text.trim().isEmpty ? 'Improve this file while preserving its existing behavior.' : _chatController.text.trim()}

Current file:
${_codeController.text}''';

    setState(() {
      _workspaceMessages.add(ChatMessage(text: prompt, isUser: true));
      _isSending = true;
    });
    _pendingRequestMessages = List<ChatMessage>.from(_workspaceMessages);
    _chatController.clear();

    final reply = await _requestAssistantReply(openFile: _currentOpenFileContext());
    if (!mounted) return;

    final code = _extractCodeBlock(reply);
    if (code == null) {
      setState(() {
        _workspaceMessages.add(ChatMessage(
            text: reply ?? 'Juveh did not return editable code.',
            isUser: false));
        _isSending = false;
      });
      return;
    }

    setState(() {
      _proposedCode = code;
      _selectedView = 1;
      _workspaceMessages.add(ChatMessage(
          text:
              'Juveh prepared a diff for $fileName. Review it in the editor, then accept or reject it.',
          isUser: false));
      _isSending = false;
    });
  }

  void _acceptProposedCode() {
    if (_proposedCode == null) return;
    setState(() {
      _codeController.text = _proposedCode!;
      _codeLines = _proposedCode!.split('\n');
      _originalCode = _proposedCode;
      _proposedCode = null;
      _workspaceActivity.insert(
        0,
        WorkspaceActivity(
          label: 'AI diff accepted',
          detail:
              _selectedFilePath?.split(Platform.pathSeparator).last ?? 'file',
          icon: Icons.check_circle_outline,
        ),
      );
    });
  }

  void _rejectProposedCode() {
    if (_proposedCode == null) return;
    setState(() {
      _proposedCode = null;
      _workspaceActivity.insert(
        0,
        WorkspaceActivity(
          label: 'AI diff rejected',
          detail:
              _selectedFilePath?.split(Platform.pathSeparator).last ?? 'file',
          icon: Icons.undo_outlined,
        ),
      );
    });
  }

  String? _extractCodeBlock(String? reply) {
    if (reply == null) return null;
    final match = RegExp(r'```[^\n]*\n([\s\S]*?)```').firstMatch(reply);
    return match?.group(1);
  }

  String _fallbackReply(String prompt) {
    final normalized = prompt.toLowerCase();
    if (normalized.contains('alarm') || normalized.contains('wake')) {
      return 'Alarm set for 6:30 AM.';
    }
    if (normalized.contains('subject') || normalized.contains('course')) {
      return "Today's subjects are Mathematics, English, and Science.";
    }
    if (normalized.contains('route') || normalized.contains('gps')) {
      return 'Route: take Main Street, then turn left at Oak Avenue — about 15 minutes.';
    }
    if (normalized.contains('room')) {
      return 'Your next class is in Room 204.';
    }
    return 'Juveh AI is temporarily offline. Please start the backend and try again.';
  }

  Future<void> _submitMessage({bool workspaceEnabled = true}) async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isSending) return;
    final messages = workspaceEnabled ? _workspaceMessages : _chatMessages;

    setState(() {
      messages.add(ChatMessage(text: text, isUser: true));
      _chatController.clear();
      _isSending = true;
      if (workspaceEnabled) {
        _pendingRequestMessages = List<ChatMessage>.from(messages);
      }
    });

    final requestAttachments = List<ChatAttachment>.from(_attachments);
    final reply = await _requestAssistantReply(
      conversationMessages:
          workspaceEnabled ? _workspaceMessages : _chatMessages,
      includeWorkspace: workspaceEnabled,
      attachments: requestAttachments,
      openFile: workspaceEnabled ? _currentOpenFileContext() : null,
    );
    if (!mounted) return;
    setState(() {
      messages.add(ChatMessage(
        text: reply ?? _fallbackReply(text),
        isUser: false,
      ));
      _isSending = false;
      _attachments.clear();
    });
  }

  Future<void> _submitJuvehChat() => _submitMessage(workspaceEnabled: false);

  // Whatever file is open in the editor is sent along automatically so the
  // assistant is always aware of it — the person shouldn't have to press
  // "Edit selected file" just to make Juveh aware of what's on screen.
  Map<String, String>? _currentOpenFileContext() {
    if (_selectedFilePath == null) return null;
    return {
      'path': _selectedFilePath!,
      'name': _selectedFilePath!.split(Platform.pathSeparator).last,
      'content': _codeController.text,
    };
  }

  // --------------------------------------------------------------------
  // Settings / help
  // --------------------------------------------------------------------

  Widget _buildSettingsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: AppType.display(20)),
            const SizedBox(height: 4),
            Text('Your account and how Juveh connects to its backend.',
                style: AppType.body(13, color: AppColors.textMuted)),
            const SizedBox(height: 20),
            _sectionLabel('Account'),
            _buildInfoCard('Username', 'your_username',
                icon: Icons.person_outline),
            const SizedBox(height: 10),
            _buildInfoCard('Email', 'user@example.com',
                icon: Icons.mail_outline),
            const SizedBox(height: 24),
            _sectionLabel('General'),
            _buildInfoCard('API endpoint', apiBaseUrl,
                icon: Icons.dns_outlined),
            const SizedBox(height: 10),
            _buildInfoCard('Version', '0.1.0', icon: Icons.info_outline),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label,
          style: AppType.body(11.5,
              color: AppColors.textFaint, weight: FontWeight.w600)),
    );
  }

  Widget _buildHelpView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Help', style: AppType.display(20)),
            const SizedBox(height: 4),
            Text('Getting the most out of Juveh.',
                style: AppType.body(13, color: AppColors.textMuted)),
            const SizedBox(height: 20),
            _buildInfoCard(
                'Learn more', 'Use the AI assistant and check the API docs.',
                icon: Icons.menu_book_outlined),
            const SizedBox(height: 10),
            _buildInfoCard('Support', 'Email support@example.com',
                icon: Icons.support_agent_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String subtitle, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: AppColors.textMuted),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.body(13, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppType.body(12.5, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // IDE (workspace + chat split view)
  // --------------------------------------------------------------------

  Widget _buildIdeView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return _buildChatView();
        }
        return Column(
          children: [
            _buildIdeHeader(),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                      flex: ((1 - _ideSplit) * 100).round(),
                      child: RepaintBoundary(child: _buildChatView())),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _ideSplit = (_ideSplit -
                                details.delta.dx / constraints.maxWidth)
                            .clamp(0.42, 0.78);
                      });
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: Container(width: 1, color: AppColors.line),
                    ),
                  ),
                  Expanded(
                      flex: (_ideSplit * 100).round(),
                      child: RepaintBoundary(child: _buildWorkspaceView())),
                ],
              ),
            ),
            _buildGlobalStatusBar(),
          ],
        );
      },
    );
  }

  Widget _buildIdeHeader() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: AppColors.chrome,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Text('Assistant',
              style: AppType.display(14, weight: FontWeight.w600)),
          const SizedBox(width: 20),
          const Icon(Icons.folder_open_outlined,
              size: 15, color: AppColors.teal),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              _workspacePath ?? 'No workspace selected',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.body(12, color: AppColors.textMuted),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => setState(() => _selectedView = 3),
            icon: const Icon(Icons.settings_outlined, size: 17),
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalStatusBar() {
    final filePath = _selectedFilePath;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: AppColors.chrome,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Text('main', style: AppType.mono(10.5, color: AppColors.textMuted)),
          const SizedBox(width: 14),
          Text('UTF-8', style: AppType.mono(10.5, color: AppColors.textMuted)),
          const SizedBox(width: 14),
          Text(filePath == null ? 'Plain Text' : _fileTypeLabel(filePath),
              style: AppType.mono(10.5, color: AppColors.textMuted)),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSending ? AppColors.amber : AppColors.success,
                ),
              ),
              Text(_isSending ? 'Juveh is thinking…' : 'Ready',
                  style: AppType.mono(10.5,
                      color: AppColors.textMuted, weight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickWorkspace() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a project folder',
    );
    if (path == null) return;

    final directory = Directory(path);
    final files = directory
        .listSync(followLinks: false)
        .where((entity) =>
            !entity.path.split(Platform.pathSeparator).last.startsWith('.'))
        .toList()
      ..sort((a, b) {
        final aDirectory = a is Directory ? 0 : 1;
        final bDirectory = b is Directory ? 0 : 1;
        return aDirectory == bDirectory
            ? a.path.toLowerCase().compareTo(b.path.toLowerCase())
            : aDirectory - bDirectory;
      });

    setState(() {
      _workspacePath = path;
      _workspaceFiles = files;
      _expandedDirectories.clear();
      _selectedFilePath = null;
      _codeController.clear();
    });
  }

  Future<void> _openWorkspaceFile(FileSystemEntity entity) async {
    if (entity is Directory) {
      setState(() {
        if (!_expandedDirectories.add(entity.path)) {
          _expandedDirectories.remove(entity.path);
        }
      });
      return;
    }
    if (entity is! File) return;
    try {
      final content = await entity.readAsString();
      setState(() {
        _selectedFilePath = entity.path;
        _codeController.text = content;
        _codeLines = content.split('\n');
        _rawEditMode = false;
        _editingLineIndex = null;
        _originalCode = content;
        _proposedCode = null;
        if (!_openFiles.contains(entity.path)) _openFiles.add(entity.path);
        _workspaceActivity.insert(
          0,
          WorkspaceActivity(
            label: 'File opened',
            detail: entity.path.split(Platform.pathSeparator).last,
            icon: Icons.visibility_outlined,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This file cannot be opened as text.')),
      );
    }
  }

  Future<void> _saveWorkspaceFile() async {
    if (_selectedFilePath == null) return;
    await File(_selectedFilePath!).writeAsString(_codeController.text);
    if (!mounted) return;
    setState(() {
      _workspaceActivity.insert(
        0,
        WorkspaceActivity(
          label: 'File saved',
          detail: _selectedFilePath!.split(Platform.pathSeparator).last,
          icon: Icons.save_outlined,
        ),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File saved.')),
    );
  }

  Future<void> _askJuvehAboutFile() async {
    if (_selectedFilePath == null || _isSending) return;
    final fileName = _selectedFilePath!.split(Platform.pathSeparator).last;
    final prompt =
        'Review this file and suggest concrete improvements. File: $fileName\n\n${_codeController.text}';

    setState(() {
      _selectedView = 1;
      _workspaceMessages.add(ChatMessage(text: prompt, isUser: true));
      _isSending = true;
    });

    final reply = await _requestAssistantReply(openFile: _currentOpenFileContext());
    if (!mounted) return;
    setState(() {
      _workspaceMessages.add(ChatMessage(
          text: reply ?? 'Juveh could not review this file.', isUser: false));
      _isSending = false;
    });
    _workspaceActivity.insert(
      0,
      WorkspaceActivity(
        label: 'AI review completed',
        detail: fileName,
        icon: Icons.auto_awesome_outlined,
      ),
    );
  }

  Widget _buildWorkspaceView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: const BoxDecoration(
            color: AppColors.chrome,
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workspace', style: AppType.display(16)),
                    const SizedBox(height: 3),
                    Text(
                      _workspacePath ??
                          'Open a project folder to inspect and edit code.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body(12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              _workspaceButton(
                  Icons.folder_open_outlined, 'Open', _pickWorkspace,
                  primary: true),
              const SizedBox(width: 8),
              _workspaceButton(Icons.save_outlined, 'Save',
                  _selectedFilePath == null ? null : _saveWorkspaceFile),
              const SizedBox(width: 8),
              _workspaceButton(
                  Icons.auto_awesome_outlined,
                  'Ask Juveh',
                  _selectedFilePath == null
                      ? () => setState(() => _selectedView = 1)
                      : _askJuvehAboutFile),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              if (!_explorerCollapsed)
                SizedBox(
                  width: _explorerWidth,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: AppColors.line)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                          child: Text('Files',
                              style: AppType.body(11.5,
                                  color: AppColors.textFaint,
                                  weight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: _visibleWorkspaceFiles.isEmpty
                              ? Center(
                                  child: Text('No folder open',
                                      style: AppType.body(12.5,
                                          color: AppColors.textFaint)))
                              : ListView.builder(
                                  itemCount: _visibleWorkspaceFiles.length,
                                  itemBuilder: (context, index) {
                                    final entity =
                                        _visibleWorkspaceFiles[index];
                                    final isSelected =
                                        entity.path == _selectedFilePath;
                                    return _HoverAction(
                                      enabled: true,
                                      onTap: () => _openWorkspaceFile(entity),
                                      borderRadius: BorderRadius.zero,
                                      child: Container(
                                        color: isSelected
                                            ? AppColors.amberSoft
                                            : Colors.transparent,
                                        padding: EdgeInsets.only(
                                            left: 14 + _entityIndent(entity),
                                            right: 10,
                                            top: 7,
                                            bottom: 7),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _fileIcon(entity),
                                              color: isSelected
                                                  ? AppColors.amber
                                                  : AppColors.textMuted,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                entity.path
                                                    .split(
                                                        Platform.pathSeparator)
                                                    .last,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppType.body(
                                                  12.5,
                                                  color: isSelected
                                                      ? AppColors.text
                                                      : AppColors.textMuted,
                                                ),
                                              ),
                                            ),
                                            if (entity is Directory)
                                              Icon(
                                                _expandedDirectories
                                                        .contains(entity.path)
                                                    ? Icons.expand_more
                                                    : Icons.chevron_right,
                                                size: 15,
                                                color: AppColors.textFaint,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) => setState(() {
                  _explorerWidth =
                      (_explorerWidth + details.delta.dx).clamp(180, 360);
                }),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: Container(
                    width: 14,
                    alignment: Alignment.center,
                    child: _HoverAction(
                      enabled: true,
                      borderRadius: BorderRadius.circular(5),
                      onTap: () => setState(() {
                        _explorerCollapsed = !_explorerCollapsed;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 4),
                        child: Icon(
                            _explorerCollapsed
                                ? Icons.chevron_right
                                : Icons.chevron_left,
                            size: 14,
                            color: AppColors.textFaint),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFileTabs(),
                    Expanded(child: _buildEditorSurface()),
                  ],
                ),
              ),
              if (!_activityCollapsed) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) => setState(() {
                    _activityWidth =
                        (_activityWidth - details.delta.dx).clamp(160, 300);
                  }),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: Container(width: 1, color: AppColors.line),
                  ),
                ),
                SizedBox(width: _activityWidth, child: _buildActivityRail()),
              ] else
                _HoverAction(
                  enabled: true,
                  onTap: () => setState(() => _activityCollapsed = false),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.history, size: 16, color: AppColors.teal),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityRail() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Activity',
                    style: AppType.body(11.5,
                        color: AppColors.textFaint, weight: FontWeight.w600)),
              ),
              _HoverAction(
                enabled: true,
                onTap: () => setState(() => _activityCollapsed = true),
                borderRadius: BorderRadius.circular(5),
                child: const Icon(Icons.chevron_right,
                    size: 15, color: AppColors.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _workspaceActivity.isEmpty
                ? Text('No activity yet.\nAI actions will appear here.',
                    style: AppType.body(12,
                        color: AppColors.textFaint, height: 1.5))
                : ListView.builder(
                    itemCount: _workspaceActivity.length,
                    itemBuilder: (context, index) {
                      final activity = _workspaceActivity[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(activity.icon,
                                size: 14, color: AppColors.teal),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(activity.label,
                                      style: AppType.body(12,
                                          weight: FontWeight.w600)),
                                  const SizedBox(height: 3),
                                  Text(activity.detail,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.body(11,
                                          color: AppColors.textMuted,
                                          height: 1.4)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTabs() {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: _openFiles.isEmpty
          ? Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('No open files',
                    style: AppType.body(11.5, color: AppColors.textFaint)),
              ),
            )
          : ListView(
              scrollDirection: Axis.horizontal,
              children: _openFiles.map((filePath) {
                final active = filePath == _selectedFilePath;
                final name = filePath.split(Platform.pathSeparator).last;
                return _HoverAction(
                  enabled: true,
                  onTap: () async => _openWorkspaceFile(File(filePath)),
                  borderRadius: BorderRadius.zero,
                  child: Container(
                    padding: const EdgeInsets.only(left: 12, right: 6),
                    decoration: BoxDecoration(
                      color: active ? AppColors.surfaceAlt : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                            color:
                                active ? AppColors.amber : Colors.transparent,
                            width: 2),
                        right: const BorderSide(color: AppColors.line),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_fileIcon(File(filePath)),
                            size: 13,
                            color:
                                active ? AppColors.amber : AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(name,
                            style: AppType.body(11.5,
                                color: active
                                    ? AppColors.text
                                    : AppColors.textMuted)),
                        const SizedBox(width: 6),
                        _HoverAction(
                          enabled: true,
                          onTap: () => setState(() {
                            _openFiles.remove(filePath);
                            if (active) {
                              _selectedFilePath = null;
                              _codeController.clear();
                            }
                          }),
                          borderRadius: BorderRadius.circular(4),
                          child: const Icon(Icons.close,
                              size: 13, color: AppColors.textFaint),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  List<FileSystemEntity> get _visibleWorkspaceFiles {
    final visibleFiles = <FileSystemEntity>[];
    void addVisible(Iterable<FileSystemEntity> entities) {
      for (final entity in entities) {
        visibleFiles.add(entity);
        if (entity is Directory && _expandedDirectories.contains(entity.path)) {
          final children = entity
              .listSync(followLinks: false)
              .where((child) => !child.path
                  .split(Platform.pathSeparator)
                  .last
                  .startsWith('.'))
              .toList()
            ..sort(
                (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
          addVisible(children);
        }
      }
    }

    addVisible(_workspaceFiles);
    return visibleFiles;
  }

  double _entityIndent(FileSystemEntity entity) {
    final root = _workspacePath;
    if (root == null) return 0;
    return (entity.path.split(Platform.pathSeparator).length -
            root.split(Platform.pathSeparator).length) *
        12.0;
  }

  IconData _fileIcon(FileSystemEntity entity) {
    if (entity is Directory) return Icons.folder_outlined;
    final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
    if (name.endsWith('.sp')) return Icons.extension_outlined;
    if (name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      return Icons.image_outlined;
    }
    if (name.endsWith('.exe') || name.endsWith('.dll')) {
      return Icons.memory_outlined;
    }
    if (name.endsWith('.json') ||
        name.endsWith('.yaml') ||
        name.endsWith('.yml')) {
      return Icons.data_object_outlined;
    }
    return Icons.description_outlined;
  }

  Widget _buildEditorSurface() {
    if (_proposedCode == null) {
      if (_selectedFilePath == null) {
        return Center(
          child: Text('Open a file to start coding with Juveh.',
              style: AppType.body(13, color: AppColors.textFaint)),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEditorModeBar(),
          Expanded(
            child: _rawEditMode ? _buildRawEditor() : _buildLineViewer(),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.tealSoft,
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              const Icon(Icons.compare_arrows, size: 15, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Juveh proposed changes',
                      style: AppType.body(12, weight: FontWeight.w600))),
              TextButton(
                  onPressed: _rejectProposedCode, child: const Text('Reject')),
              const SizedBox(width: 4),
              FilledButton(
                  onPressed: _acceptProposedCode, child: const Text('Accept')),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                  child: _buildDiffPane(
                      'Original',
                      _originalCode ?? _codeController.text,
                      AppColors.dangerSoft)),
              Container(width: 1, color: AppColors.line),
              Expanded(
                  child: _buildDiffPane(
                      'Proposed', _proposedCode!, AppColors.successSoft)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditorModeBar() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.chrome,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _rawEditMode
                  ? 'Raw edit mode — full file loaded (slower on huge files)'
                  : '${_codeLines.length} lines · tap a line to edit it',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.body(11, color: AppColors.textFaint),
            ),
          ),
          const Spacer(),
          _HoverAction(
            enabled: true,
            borderRadius: BorderRadius.circular(5),
            onTap: _toggleRawEditMode,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      _rawEditMode
                          ? Icons.view_agenda_outlined
                          : Icons.edit_document,
                      size: 13,
                      color: AppColors.teal),
                  const SizedBox(width: 5),
                  Text(_rawEditMode ? 'Back to line view' : 'Edit full file',
                      style: AppType.body(11,
                          color: AppColors.teal, weight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Full-document TextField, kept as an explicit opt-in fallback for bulk
  // pastes or multi-line edits that the line-by-line view isn't meant for.
  Widget _buildRawEditor() {
    return RepaintBoundary(
      child: TextField(
        controller: _codeController,
        expands: true,
        maxLines: null,
        minLines: null,
        style: AppType.mono(13),
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.all(18),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }

  // Virtualized viewer: ListView.builder with a fixed itemExtent only ever
  // builds/lays out the handful of lines actually on screen, so it stays
  // smooth regardless of file size. Tapping a line swaps just that row for
  // a tiny TextField instead of loading the whole file into one editable
  // widget.
  Widget _buildLineViewer() {
    return RepaintBoundary(
      child: ListView.builder(
        itemExtent: 22,
        itemCount: _codeLines.length,
        itemBuilder: (context, index) {
          final isEditing = _editingLineIndex == index;
          return Container(
            color: isEditing ? AppColors.surfaceAlt : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 34,
                  child: Text('${index + 1}',
                      style: AppType.mono(10.5, color: AppColors.textFaint)),
                ),
                Expanded(
                  child: isEditing
                      ? Focus(
                          onFocusChange: (hasFocus) {
                            if (!hasFocus) _scheduleLineEditCommit();
                          },
                          child: TextField(
                            controller: _lineEditController,
                            focusNode: _lineEditFocusNode,
                            autofocus: true,
                            style: AppType.mono(13),
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _scheduleLineEditCommit(),
                          ),
                        )
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _beginEditLine(index),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.text,
                            child: Text(
                              _codeLines[index].isEmpty
                                  ? ' '
                                  : _codeLines[index],
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              softWrap: false,
                              style: AppType.mono(13),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _toggleRawEditMode() {
    _commitLineEdit();
    setState(() {
      if (_rawEditMode) {
        // Leaving raw mode: re-split whatever was typed back into lines.
        _codeLines = _codeController.text.split('\n');
      }
      _rawEditMode = !_rawEditMode;
    });
  }

  void _beginEditLine(int index) {
    if (_editingLineIndex == index) return;
    _commitLineEdit();
    setState(() {
      _editingLineIndex = index;
      _lineEditController = TextEditingController(text: _codeLines[index]);
      _lineEditFocusNode = FocusNode();
    });
  }

  void _commitLineEdit() {
    final index = _editingLineIndex;
    final controller = _lineEditController;
    if (index == null || controller == null) return;
    _codeLines[index] = controller.text;
    _codeController.text = _codeLines.join('\n');
    _lineEditFocusNode?.dispose();
    controller.dispose();
    setState(() {
      _editingLineIndex = null;
      _lineEditController = null;
      _lineEditFocusNode = null;
    });
  }

  void _scheduleLineEditCommit() {
    if (_lineEditCommitScheduled) return;
    _lineEditCommitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lineEditCommitScheduled = false;
      if (mounted) _commitLineEdit();
    });
  }

  Widget _buildDiffPane(String label, String content, Color tint) {
    final lines = content.split('\n');
    return Container(
      color: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Text(label,
                style: AppType.body(11,
                    color: AppColors.textMuted, weight: FontWeight.w600)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
              itemCount: lines.length,
              itemBuilder: (context, index) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      width: 30,
                      child: Text('${index + 1}',
                          style: AppType.mono(10, color: AppColors.textFaint))),
                  Expanded(
                      child: Text(lines[index], style: AppType.mono(12))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceButton(IconData icon, String label, VoidCallback? onPressed,
      {bool primary = false}) {
    final enabled = onPressed != null;
    return _HoverAction(
      enabled: enabled,
      borderRadius: BorderRadius.circular(8),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: !enabled
              ? AppColors.surface
              : primary
                  ? AppColors.amber
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  !enabled || !primary ? AppColors.line : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: !enabled
                    ? AppColors.textFaint
                    : primary
                        ? AppColors.ink
                        : AppColors.text),
            const SizedBox(width: 7),
            Text(label,
                style: AppType.body(12.5,
                    weight: FontWeight.w600,
                    color: !enabled
                        ? AppColors.textFaint
                        : primary
                            ? AppColors.ink
                            : AppColors.text)),
          ],
        ),
      ),
    );
  }

  Widget _buildFileContextChip(String filePath) {
    final fileName = filePath.split(Platform.pathSeparator).last;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.tealSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.tealBorder),
      ),
      child: Text(
        '$fileName · ${_fileTypeLabel(filePath)}',
        overflow: TextOverflow.ellipsis,
        style:
            AppType.body(10.5, color: AppColors.teal, weight: FontWeight.w600),
      ),
    );
  }

  String _fileTypeLabel(String filePath) {
    final fileName = filePath.split(Platform.pathSeparator).last;
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'text';
    const labels = {
      'dart': 'Dart',
      'js': 'JavaScript',
      'jsx': 'React JSX',
      'ts': 'TypeScript',
      'tsx': 'React TSX',
      'json': 'JSON',
      'md': 'Markdown',
      'css': 'CSS',
      'html': 'HTML',
      'yaml': 'YAML',
      'yml': 'YAML',
      'py': 'Python',
      'java': 'Java',
      'kt': 'Kotlin',
      'swift': 'Swift',
      'sql': 'SQL',
      'env': 'Environment',
    };
    return labels[extension] ?? extension.toUpperCase();
  }
}

// ============================================================================
// Data models
// ============================================================================

class ChatMessage {
  final String text;
  final bool isUser;

  const ChatMessage({required this.text, required this.isUser});
}

class ChatAttachment {
  final String name;
  final String kind;
  final String content;

  const ChatAttachment({
    required this.name,
    required this.kind,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind,
        'content': content,
      };
}

class WorkspaceAction {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const WorkspaceAction({
    required this.id,
    required this.name,
    required this.arguments,
  });

  String get path => arguments['path'] as String? ?? 'workspace path';

  factory WorkspaceAction.fromJson(Map<String, dynamic> json) {
    return WorkspaceAction(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'workspace action',
      arguments: (json['arguments'] as Map<String, dynamic>?) ?? const {},
    );
  }
}

class WorkspaceActivity {
  final String label;
  final String detail;
  final IconData icon;

  const WorkspaceActivity({
    required this.label,
    required this.detail,
    required this.icon,
  });
}

// Tracks hover state and hands it to a builder — used to reveal the
// copy/regenerate row under an assistant message only while the pointer is
// over it, the way ChatGPT reveals its message actions.
class _HoverReveal extends StatefulWidget {
  final Widget Function(bool hovered) builder;

  const _HoverReveal({required this.builder});

  @override
  State<_HoverReveal> createState() => _HoverRevealState();
}

class _HoverRevealState extends State<_HoverReveal> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(_hovered),
    );
  }
}

class _HoverAction extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final BorderRadius borderRadius;

  const _HoverAction({
    required this.child,
    required this.onTap,
    required this.enabled,
    required this.borderRadius,
  });

  @override
  State<_HoverAction> createState() => _HoverActionState();
}

class _HoverActionState extends State<_HoverAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && _isHovered;
    return MouseRegion(
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      opaque: true,
      hitTestBehavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        transform:
            active ? Matrix4.translationValues(0, -1, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          color: active ? AppColors.amberSoft : Colors.transparent,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.amber.withValues(alpha: 0.18),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          borderRadius: widget.borderRadius,
          hoverColor: Colors.transparent,
          splashColor: AppColors.amberSoft,
          mouseCursor: SystemMouseCursors.basic,
          child: widget.child,
        ),
      ),
    );
  }
}

