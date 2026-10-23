import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/vision/vision_kit.dart';
import 'core/api/collider_api.dart';
import 'features/music/music_widget.dart';
import 'core/audio/music_player.dart';
import 'models/model_def.dart';
import 'models/theme_def.dart';
import 'models/ticker_item.dart';
import 'features/ticker/widgets/model_pill.dart';
import 'features/ticker/widgets/consensus_row.dart';
import 'features/ticker/widgets/conversation_view.dart';
import 'features/ticker/widgets/message_zoom_overlay.dart';
import 'features/ticker/widgets/research_document.dart';
import 'features/ticker/widgets/local_history_pane.dart';
import 'features/prompt/floating_prompt.dart';
import 'features/nav/permanent_nav_bar.dart';
import 'features/nav/side_nav_rail.dart';
import 'features/nav/contextual_side_nav.dart';
import 'features/apps/apps_popup_pane.dart';
import 'features/wallpaper/widgets/windowless_theme_scroller.dart';
import 'features/drawers/settings_drawer.dart';
import 'features/consensus/consensus_webview.dart';
import 'features/smartgen/screens/smartgen_screen.dart';
import 'features/smartgen/smartgen_store.dart';
import 'features/market/screens/market_screen.dart';
import 'features/upgrade/screens/upgrade_screen.dart';
import 'features/skills/screens/skills_screen.dart';
import 'features/files/screens/files_screen.dart';
import 'features/documents/documents_screen.dart';
import 'core/voice/voice.dart';
import 'features/browser/models/browser_tab.dart';
import 'features/browser/screens/in_app_browser_sheet.dart';
import 'features/theme/premium_theme_market_view.dart';
import 'features/theme/theme_living_media.dart';
import 'features/theme/theme_pack_store.dart';
import 'features/media/generations_pane.dart';
import 'core/media/theme_blur_cache.dart';
import 'core/media/theme_cloud.dart';
import 'features/drawers/history_pane.dart';
import 'core/media/theme_media_bundle.dart';
import 'core/drafts.dart';
import 'core/platform/open_url.dart';
import 'package:device_preview/device_preview.dart';

Future<void> main() async {
  // Device Preview 3.0: devices, sizes, orientation and screenshots from the device_preview tab in DevTools,
  // debug and profile runs only (Claude, 2026-10-23).
  DevicePreview.enable();
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  ThemeCloud.instance.init(); // the live wallpapers from the Cloudflare bucket, read while the app starts
  ThemeBlurCache.instance.prewarmThemes(WallpaperCatalog.freeThemes);
  ConsensusWebView.preload();
  SmartGenStore.instance.load();
  await Drafts.load(); // unsent messages, as they were left (Claude, 2026-10-21)
  runApp(const ColliderApp());
}

class ColliderApp extends StatelessWidget {
  const ColliderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Collider',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF07080B),
        // the same face, applied by name: google_fonts' text-theme helper still builds the SDK's own TextTheme
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: GoogleFonts.instrumentSans().fontFamily),
      ),
      // Theme pictures from the bucket load through Image.asset like the built-in ones.
      // The bridge lets packages that still use the SDK's built-in Material work with material_ui (Flutter 3.47 notes;
      // Claude, 2026-10-21).
      builder: (context, child) =>
          MaterialUiCompatibilityBridge(child: DefaultAssetBundle(bundle: ThemeMediaAssetBundle.instance, child: child!)),
      home: const ColliderHomeScreen(),
    );
  }
}

class ColliderHomeScreen extends StatefulWidget {
  const ColliderHomeScreen({super.key});

  @override
  State<ColliderHomeScreen> createState() => _ColliderHomeScreenState();
}

class _ColliderHomeScreenState extends State<ColliderHomeScreen> {
  // Wallpaper state: Uninterrupted, star of the product
  WallpaperTheme _currentTheme = WallpaperCatalog.defaultTheme;
  WallpaperTheme _savedThemeBeforePreview = WallpaperCatalog.defaultTheme;

  // Selected Models (Max 9 active model rows)
  final List<String> _selectedModelIds = [
    'free/gpt-5-nano',
    'free/gemini-3-6-flash-lite',
    'free/mistral-small',
    'pro/claude-3-7-sonnet',
    'image/flux-1-1-pro',
    'free/qwen-3-6-27b',
    'free/minimax-m3',
    'free/laguna-s-2-1',
    'pro/mistral-large',
  ];

  // Active Model Category
  ModelCategory _activeCategory = ModelCategory.general;
  // The Image category (Claude, 2026-10-21): the shape and number of pictures, and the generations pane.
  String _aspect = '9:16';
  int _count = 4;
  bool _mediaExpanded = false;
  int _mediaRefresh = 0;

  // Active temporary pane / drawer: 'themes', 'settings', 'consensus', 'apps', 'history', 'market', 'smartgen', 'upgrade', 'skills', 'files', 'model_ladder'
  String? _activeDrawer;

  // Local Model History modal state
  ModelDef? _localHistoryModel;

  // Zoomed message overlay state
  TickerMessage? _zoomedMessage;
  ModelDef? _zoomedModelDef;

  // Expanded accordion model IDs
  final Set<String> _expandedModelIds = {};

  // Swipe/tap-summoned global broadcast composer
  bool _isComposerSummoned = false;

  // Mobile slide-out contextual side nav state
  bool _isMobileSideNavOpen = false;

  // Current floating user prompt (floats un-framed on wallpaper)
  String _currentPrompt = '';

  // Consensus state: ratio of agreeing models (e.g. "7/7")
  String _consensusRatio = 'Consensus';
  String _consensusSummary = '';
  bool _isConsensusGenerating = false;

  // Live session state (Collider server)
  AskMode _mode = AskMode.chat;
  bool _incognito = false;
  bool _autosave = true;
  bool _busy = false;
  DateTime? _promptTime;
  final Map<String, JobState> _jobsById = {};
  String? _currentJobId;
  Offset? _musicPos; // where the user last put the music widget

  // Ticker items
  late List<TickerItem> _tickerItems;

  // Global History Sessions
  late List<ConversationHistorySession> _globalHistorySessions;

  // Local Model History Sessions map
  late Map<String, List<ConversationHistorySession>> _localHistorySessions;

  // Browser Tabs (only 1 active at a time)
  late List<BrowserTab> _browserTabs;

  // Contextual work surface state
  String _smartGenView = 'boards';
  int _smartGenNewCardTrigger = 0;
  String _smartGenBoardType = 'kanban';
  String _marketCategory = 'discover';
  String _themeSection = 'gallery';
  String _filesCategory = 'all';
  String _filesPlace = 'home'; // where Files opens: Home, or Music when the Music Player is asked for
  String? _docUrl; // the file Documents opens (Claude, 2026-10-20); null for a new document
  bool _voiceChat = false; // Voice Chat (Claude, 2026-10-20): speak, the models answer, the answer is read aloud
  String _voicePhase = ''; // listening, thinking, speaking, or '' waiting for a tap
  bool _musicHeldForVoice = false; // the music bar was playing when Voice Chat came on
  String? _docName;
  String _chatSection = 'history';

  /// The rail ornament shows on the resting canvas and durable work surfaces only.
  bool get _railVisible {
    if (_localHistoryModel != null || _zoomedMessage != null || _browserOpen) return false;
    const surfaces = {null, 'smartgen', 'market', 'themes'}; // Files draws its own side menu
    return surfaces.contains(_activeDrawer);
  }

  ActiveWorkSurface get _currentActiveSurface {
    if (_activeDrawer == 'smartgen') return ActiveWorkSurface.smartgen;
    if (_activeDrawer == 'market') return ActiveWorkSurface.market;
    if (_activeDrawer == 'themes' || _activeDrawer == 'premium') return ActiveWorkSurface.themes;
    if (_activeDrawer == 'files') return ActiveWorkSurface.files;
    return ActiveWorkSurface.chat;
  }

  @override
  void initState() {
    super.initState();
    ThemeBlurCache.instance.setActiveTheme(_currentTheme);
    if (Uri.base.queryParameters['drawer'] == 'premium' ||
        (Uri.base.queryParameters['drawer'] == 'market' && Uri.base.queryParameters['sub'] == 'themes')) {
      _activeDrawer = 'premium'; // the market shows its middle theme as soon as the list is in
    } else if (Uri.base.queryParameters['drawer'] == 'music') {
      // The Music Player is the music bar and the music in Files.
      _activeDrawer = 'files';
      _filesPlace = 'music';
    } else if (Uri.base.queryParameters['drawer'] != null) {
      _activeDrawer = Uri.base.queryParameters['drawer'];
    }
    if (Uri.base.queryParameters['composer'] == '1') _isComposerSummoned = true;
    if (Uri.base.queryParameters['rail'] == '1') _isMobileSideNavOpen = true;
    if (Uri.base.queryParameters['view'] != null) _smartGenView = Uri.base.queryParameters['view']!;
    _initializeTickerItems();
    _initializeHistorySessions();
    _initializeBrowserTabs();
    _boot();
    final qp = Uri.base.queryParameters;
    if (qp['zoom'] == '1' && _tickerItems.isNotEmpty) {
      _zoomedMessage = _tickerItems.first.conversation.last;
      _zoomedModelDef = _tickerItems.first.modelDef;
    }
    if (qp['local'] == '1' && _tickerItems.isNotEmpty) {
      _localHistoryModel = _tickerItems.first.modelDef;
    }
    if (qp['expand'] == '1') {
      if (_tickerItems.isNotEmpty) _expandedModelIds.add(_tickerItems.first.modelDef.id);
    }
    if (qp['browser'] == '1') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openBrowserForTab('user_default'));
    }
  }

  void _initializeTickerItems() {
    _tickerItems = [];
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'Yesterday';
    return '${d.inDays}d ago';
  }

  Future<void> _boot() async {
    final ok = await ColliderApi.instance.loadRoster();
    if (!mounted || !ok) return;
    ColliderApi.instance.files();
    SmartGenStore.instance.syncAutonomousCards();
    // Default selection: one model per provider, so every card carries a distinct colour.
    final seen = <String>{};
    final live = <String>[
      for (final m in ModelRoster.allModels.where((m) => !m.isMedia))
        if (seen.add(m.desc)) m.id,
    ];
    setState(() {
      _selectedModelIds
        ..clear()
        ..addAll(live.take(6))
        ..addAll(ModelRoster.forCategory(ModelCategory.image).take(1).map((m) => m.id));
    });
    await _reloadHistory(restoreLatest: true);
    // Deep links used by the launcher and the screenshot tour: ?ask=...&mode=research
    final qp = Uri.base.queryParameters;
    if (qp['mode'] != null) {
      _mode = AskMode.values.firstWhere((m) => m.wire == qp['mode'], orElse: () => AskMode.chat);
    }
    if (qp['ask'] != null && qp['ask']!.trim().isNotEmpty) _onSendPrompt(qp['ask']!);
    if (qp['music'] == '1') {
      setState(() {
        MusicPlayer.instance
          ..queue = MusicPlayer.forTheme(_currentTheme)
          ..queueId = _currentTheme.id
          ..index = 0;
      });
    }
    if (_tickerItems.isNotEmpty) {
      setState(() {
        if (qp['expand'] == '1') _expandedModelIds.add(_tickerItems.first.modelDef.id);
        if (qp['local'] == '1') _localHistoryModel = _tickerItems.first.modelDef;
        if (qp['zoom'] == '1') {
          _zoomedMessage = _tickerItems.first.conversation.last;
          _zoomedModelDef = _tickerItems.first.modelDef;
        }
      });
    }
  }

  List<TickerMessage> _messagesFromResult(JobState j, String mid, ModelResult r) {
    if (r.messages.isNotEmpty) {
      return [
        for (var i = 0; i < r.messages.length; i++)
          TickerMessage(
            id: '${j.id}_${mid}_$i',
            sender: (r.messages[i]['role'] ?? 'user') == 'user' ? 'user' : 'model',
            text: r.messages[i]['content'] ?? '',
            timestamp: j.created.add(Duration(seconds: i)),
          ),
      ];
    }
    return [
      TickerMessage(id: '${j.id}_u', sender: 'user', text: j.prompt, timestamp: j.created),
      if (r.text.isNotEmpty) TickerMessage(id: '${j.id}_$mid', sender: 'model', text: r.text, timestamp: j.created),
    ];
  }

  Future<void> _reloadHistory({bool restoreLatest = false, bool forceRefresh = false}) async {
    final hist = await ColliderApi.instance.history(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() {
      for (final j in hist) {
        _jobsById[j.id] = j;
      }
      _globalHistorySessions = [for (final j in hist) _sessionFromJob(j)];
      final local = <String, List<ConversationHistorySession>>{};
      for (final j in hist) {
        j.results.forEach((mid, r) {
          if (r.status != 'done') return;
          (local[mid] ??= []).add(ConversationHistorySession(
            id: '${j.id}_$mid',
            title: j.prompt,
            targetModelId: mid,
            relativeTime: _ago(j.created),
            timestamp: j.created,
            summary: r.line.isNotEmpty ? r.line : r.essence,
            messages: _messagesFromResult(j, mid, r),
          ));
        });
      }
      _localHistorySessions = local;
      if (restoreLatest && hist.isNotEmpty && _tickerItems.isEmpty) _applyJob(hist.first, restored: true);
    });
  }

  ConversationHistorySession _sessionFromJob(JobState j) {
    final firstEssence = j.results.values.map((r) => r.essence).firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final firstWithMsgs = j.results.entries.where((e) => e.value.messages.isNotEmpty).firstOrNull;
    return ConversationHistorySession(
      id: j.id,
      title: j.prompt,
      relativeTime: _ago(j.created),
      timestamp: j.created,
      summary: j.consensus.line.isNotEmpty ? j.consensus.line : (j.consensus.summary.isNotEmpty ? j.consensus.summary : firstEssence),
      modelIds: j.results.keys.toList(),
      messages: firstWithMsgs != null
          ? _messagesFromResult(j, firstWithMsgs.key, firstWithMsgs.value)
          : [
              TickerMessage(id: '${j.id}_u', sender: 'user', text: j.prompt, timestamp: j.created),
              if (j.consensus.summary.isNotEmpty) TickerMessage(id: '${j.id}_c', sender: 'model', text: j.consensus.summary, timestamp: j.created),
            ],
    );
  }

  /// Maps a server job onto the ticker: one colour-coded card per model, consensus pinned on top.
  void _applyJob(JobState j, {bool restored = false}) {
    _jobsById[j.id] = j;
    _currentJobId = j.id;
    _currentPrompt = j.prompt;
    _promptTime = j.created;
    final items = <TickerItem>[];
    j.results.forEach((mid, r) {
      final def = ModelRoster.byId(mid);
      if (def == null) return;
      final prev = _tickerItems.where((t) => t.modelDef.id == mid).toList();
      // A card shows its one line. A saved answer whose line is still being written keeps waiting
      // rather than showing a cut sentence.
      final noLine = r.status == 'done' && r.line.isEmpty && !_lineFailed.contains(j.id);
      final waiting = r.status == 'pending' || noLine;
      final serverConv = _messagesFromResult(j, mid, r);
      final usePrevConv = !restored && prev.isNotEmpty && prev.first.conversation.length > serverConv.length;
      final conv = usePrevConv
          ? [
              ...prev.first.conversation.where((m) => !m.id.startsWith('${j.id}_draft_')),
              if (r.text.isNotEmpty && (prev.first.conversation.isEmpty || prev.first.conversation.last.sender == 'user'))
                TickerMessage(id: '${j.id}_draft_$mid', sender: 'model', text: r.text, timestamp: j.created),
            ]
          : serverConv;
      items.add(TickerItem(
        modelDef: def,
        relativeTime: restored ? _ago(j.created) : 'just now',
        summary: r.status == 'error' ? 'No answer' : (r.line.isNotEmpty ? r.line : _plain(r.essence)),
        isStreaming: waiting,
        isIsolated: prev.isNotEmpty && prev.first.isIsolated && !restored,
        conversation: conv,
      ));
    });
    _tickerItems = items;
    if (j.sources.isNotEmpty) {
      _browserTabs = [
        _browserTabs.first,
        for (var i = 0; i < j.sources.length; i++)
          BrowserTab(
            id: 'src_$i',
            title: '${j.sources[i]['title'] ?? ''}',
            url: '${j.sources[i]['url'] ?? ''}',
            isModelAssigned: true,
            modelName: 'Source ${i + 1}',
          ),
      ];
    }
    if (restored) {
      _selectedModelIds
        ..clear()
        ..addAll(j.results.keys.where((k) => ModelRoster.byId(k) != null));
    }
    final c = j.consensus;
    _isConsensusGenerating = !j.done;
    _consensusRatio = c.status == 'done' && c.score.isNotEmpty ? c.score : 'Consensus';
    _consensusSummary = c.line.isNotEmpty || !_lineFailed.contains(j.id) ? c.line : c.summary;
    if (j.done && _needsLines(j)) _ensureLines(j);
  }

  /// Characters one ticker row holds: the resting ticker is as wide as the dock, and the summary line
  /// has the row's full width inside the pane's and the row's padding.
  int get _lineChars => VOneLine.charsFor((MediaQuery.of(context).size.width < 768 ? 260.0 : 480.0) - 42) * 2;

  final Set<String> _lineAsked = {};
  final Set<String> _lineFailed = {};

  bool _needsLines(JobState j) {
    final n = _lineChars;
    return j.results.values.any((r) => r.status == 'done' && r.text.isNotEmpty && (r.line.isEmpty || r.line.length > n + 2)) ||
        (j.consensus.status == 'done' && (j.consensus.line.isEmpty || j.consensus.line.length > n + 2));
  }

  /// Conversations saved before rows were one line get their lines written once, then keep them.
  Future<void> _ensureLines(JobState j) async {
    if (!_lineAsked.add(j.id)) return;
    final fresh = await ColliderApi.instance.lines(j.id, _lineChars);
    if (!mounted) return;
    setState(() {
      if (fresh == null) {
        _lineFailed.add(j.id);
      } else {
        _jobsById[j.id] = fresh;
      }
      if (_currentJobId == j.id) _applyJob(fresh ?? j, restored: true);
    });
  }

  void _initializeHistorySessions() {
    _globalHistorySessions = [];
    _localHistorySessions = {};
  }

  void _initializeBrowserTabs() {
    // One user tab; research sources are added as tabs when a question uses the web.
    _browserTabs = [
      BrowserTab(id: 'user_default', title: 'Search', url: 'https://www.google.com/', isUserControlling: true),
    ];
  }

  /// A summary line without markdown marks.
  static String _plain(String s) => s.replaceAll(RegExp(r'\*\*|__|`'), '').replaceFirst(RegExp(r'^\s*(#+|[-*>])\s+'), '').trim();

  void _closeAllPanes() {
    _activeDrawer = null;
    _localHistoryModel = null;
    _zoomedMessage = null;
    _zoomedModelDef = null;
    _isMobileSideNavOpen = false;
  }

  void _requestSwitchSurface(String? targetDrawer) {
    // No "Unsaved Changes" prompt (removed 2026-09-27): switching surfaces just proceeds.
    // Drafts and inputs are kept in memory as before.
    _proceedSwitchSurface(targetDrawer);
  }

  void _proceedSwitchSurface(String? targetDrawer) {
    setState(() {
      _closeAllPanes();
      _activeDrawer = targetDrawer;
      _isComposerSummoned = (targetDrawer == null);
      if (targetDrawer == 'themes') {
        _savedThemeBeforePreview = _currentTheme;
      }
    });
  }

  void _openDrawer(String drawer) {
    if (drawer == 'files') _filesPlace = 'home';
    _requestSwitchSurface(drawer);
  }

  /// Documents: a new document, or [url] (as the server serves it) opened for editing.
  void _openDocument([String? url, String? name]) {
    _docUrl = url;
    _docName = name;
    _requestSwitchSurface('documents');
  }

  /// Voice Chat on or off. On, it listens at once.
  void _setVoiceChat(bool on) {
    setState(() {
      _voiceChat = on;
      _voicePhase = '';
    });
    final music = MusicPlayer.instance;
    if (on) {
      _musicHeldForVoice = music.playing;
      if (music.playing) music.toggle();
      _voiceTurn();
    } else {
      Voice.instance.cancelListening();
      Voice.instance.stopSpeaking();
      if (_musicHeldForVoice && !music.playing) music.toggle();
      _musicHeldForVoice = false;
    }
  }

  /// One turn: listen until the speaker stops, ask every model, read the consensus aloud, then listen again.
  /// When nothing is said it waits for a tap on the microphone.
  Future<void> _voiceTurn() async {
    if (!_voiceChat || _voicePhase.isNotEmpty || _busy) return;
    setState(() => _voicePhase = 'listening');
    final said = await Voice.instance.listen();
    if (!mounted || !_voiceChat) return;
    if (said == null) {
      setState(() => _voicePhase = '');
      return;
    }
    setState(() => _voicePhase = 'thinking');
    await _onSendPrompt(said);
    if (!mounted || !_voiceChat) return;
    final j = _currentJobId == null ? null : _jobsById[_currentJobId];
    final answer = (j?.consensus.summary.isNotEmpty ?? false) ? j!.consensus.summary : _consensusSummary;
    if (answer.isNotEmpty && answer != 'No answer') {
      setState(() => _voicePhase = 'speaking');
      await Voice.instance.speak(answer);
    }
    if (!mounted || !_voiceChat) return;
    setState(() => _voicePhase = '');
    _voiceTurn();
  }

  void _onMic() {
    switch (_voicePhase) {
      case 'listening':
        Voice.instance.finishListening();
      case 'speaking':
        Voice.instance.stopSpeaking();
      case '':
        _voiceTurn();
    }
  }

  /// The Music Player: the music in Files, played by the music bar.
  void _openMusic() {
    _filesPlace = 'music';
    _requestSwitchSurface('files');
  }

  void _openHomeComposer() {
    setState(() {
      _closeAllPanes();
      _expandedModelIds.clear();
      _isComposerSummoned = true;
    });
  }

  void _toggleComposer() {
    setState(() {
      _closeAllPanes();
      _expandedModelIds.clear();
      _isComposerSummoned = !_isComposerSummoned;
    });
  }

  void _newConversation() {
    setState(() {
      _closeAllPanes();
      _expandedModelIds.clear();
      _currentJobId = null;
      _currentPrompt = '';
      _tickerItems = [];
      _consensusRatio = 'Consensus';
      _consensusSummary = '';
      _isConsensusGenerating = false;
      _isComposerSummoned = true;
    });
  }

  /// A summary opens its conversation under itself, one at a time; the window scrolls it into view (Claude, 2026-10-21).
  void _onTogglePill(String id) {
    final opening = !_expandedModelIds.contains(id);
    setState(() {
      _expandedModelIds.clear();
      if (opening) _expandedModelIds.add(id);
    });
    if (opening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _openKey.currentContext;
        if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 360), curve: Curves.easeOutCubic, alignment: 0.0);
      });
    }
  }

  final GlobalKey _openKey = GlobalKey();

  /// A conversation as text: who said each part, then what was said.
  String _conversationText(TickerItem it) => [
        for (final m in it.conversation) '${m.sender == 'user' ? 'You' : it.modelDef.label}:\n${m.text}',
      ].join('\n\n');

  /// The device's share sheet; where there is none, the text is copied.
  Future<void> _sendText(String text) async {
    if (!await shareText(text)) await Clipboard.setData(ClipboardData(text: text));
  }

  /// Opens text in Documents: it is kept in Files > Generated first, so the document is a file like any other
  /// (Claude, 2026-10-23).
  Future<void> _openTextAsDocument(String title, String text, String model) async {
    final words = text.replaceAll(RegExp(r'[#*_`>\[\]\n]'), ' ').trim().split(RegExp(r'\s+')).take(6).join(' ');
    final name = await ColliderApi.instance.saveGenerated('$title - $words.md', text, model: model);
    if (name == null || !mounted) return;
    final all = await ColliderApi.instance.files(forceRefresh: true);
    final f = (all['generated'] ?? const <ColliderFile>[]).where((f) => f.name == name).firstOrNull;
    if (f == null || !mounted) return;
    setState(() {
      _zoomedMessage = null;
      _expandedModelIds.clear();
    });
    _openDocument(f.url, f.name);
  }

  Future<void> _onSendInlineReply(String modelId, String text, [List<String> files = const []]) async {
    final idx = _tickerItems.indexWhere((it) => it.modelDef.id == modelId);
    if (idx == -1 || text.trim().isEmpty) return;
    final now = DateTime.now();
    final activeJobId = _currentJobId;
    setState(() {
      final cur = _tickerItems[idx];
      _tickerItems[idx] = cur.copyWith(
        isIsolated: true,
        isStreaming: true,
        conversation: [...cur.conversation, TickerMessage(id: 'u${now.microsecondsSinceEpoch}', sender: 'user', text: text, timestamp: now)],
      );
    });
    final conv = _tickerItems[idx].conversation;
    // The answer drafts into the conversation as the model writes it and persists to the session (Claude, 2026-10-19).
    final draftId = 'm${now.microsecondsSinceEpoch}';
    try {
      await for (final d in ColliderApi.instance.replyStream(
        model: modelId,
        mode: _mode,
        attachments: files,
        line: _lineChars,
        jobId: activeJobId,
        messages: [for (final m in conv) {'role': m.sender == 'user' ? 'user' : 'assistant', 'content': m.text}],
      )) {
        if (!mounted) return;
        setState(() {
          final i = _tickerItems.indexWhere((it) => it.modelDef.id == modelId);
          if (i == -1) return;
          final cur = _tickerItems[i];
          _tickerItems[i] = cur.copyWith(
            isStreaming: !d.done,
            relativeTime: d.done ? 'just now' : cur.relativeTime,
            summary: d.done && d.line.isNotEmpty ? d.line : cur.summary,
            conversation: [
              for (final m in cur.conversation)
                if (m.id != draftId) m,
              if (d.text.isNotEmpty) TickerMessage(id: draftId, sender: 'model', text: d.text, timestamp: DateTime.now()),
            ],
          );
          if (d.done && activeJobId != null && _jobsById.containsKey(activeJobId)) {
            final oldJob = _jobsById[activeJobId]!;
            final oldRes = oldJob.results[modelId];
            if (oldRes != null) {
              final updatedResults = Map<String, ModelResult>.from(oldJob.results);
              updatedResults[modelId] = ModelResult(
                'done',
                d.text,
                d.line.isNotEmpty ? d.line : oldRes.essence,
                null,
                d.line.isNotEmpty ? d.line : oldRes.line,
                d.messages.isNotEmpty
                    ? d.messages
                    : [for (final m in _tickerItems[i].conversation) {'role': m.sender == 'user' ? 'user' : 'assistant', 'content': m.text}],
              );
              _jobsById[activeJobId] = JobState(
                oldJob.id,
                oldJob.prompt,
                oldJob.mode,
                oldJob.stage,
                oldJob.done,
                updatedResults,
                oldJob.consensus,
                oldJob.sources,
                oldJob.created,
              );
            }
          }
        });
        if (d.done) {
          ColliderApi.instance.cachedHistory = null;
          await _reloadHistory(forceRefresh: true);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = _tickerItems.indexWhere((it) => it.modelDef.id == modelId);
        if (i != -1) _tickerItems[i] = _tickerItems[i].copyWith(isStreaming: false, summary: 'No answer from this model.');
      });
    }
  }

  /// The Image category: the words (and any reference pictures) go to the picture models chosen there.
  Future<void> _onSendImage(String prompt, [List<String> files = const []]) async {
    var models = _selectedModelIds.where((id) => ModelRoster.byId(id)?.categories.contains(ModelCategory.image) ?? false).toList();
    if (models.isEmpty) models = ModelRoster.forCategory(ModelCategory.image).take(1).map((m) => m.id).toList();
    if (models.isEmpty) return;
    final refs = [for (final f in files) f.contains('/') ? f : 'uploaded/$f'];
    setState(() => _isComposerSummoned = false);
    for (final m in models) {
      await ColliderApi.instance.make(prompt, 'image', model: m, references: refs, aspect: _aspect, count: _count);
    }
    if (mounted) setState(() => _mediaRefresh++);
  }

  /// From Discover: to the chat's Image category, with words to make from, or a picture to remix (Grok's remix).
  void _toImageChat({String? text, String? reference}) {
    _requestSwitchSurface(null);
    setState(() {
      _activeCategory = ModelCategory.image;
      _isComposerSummoned = reference != null;
    });
    if (reference != null) FloatingPrompt.attach.value = reference;
    if (text != null) _onSendImage(text);
  }

  Future<void> _onSendPrompt(String prompt, [List<String> files = const []]) async {
    if (_activeCategory == ModelCategory.image) return _onSendImage(prompt, files);
    final models = _selectedModelIds.where((id) {
      final d = ModelRoster.byId(id);
      return d != null && !d.isMedia;
    }).toList();
    if (models.isEmpty) return;
    final now = DateTime.now();
    // If a conversation is already active on screen, continue that multi-turn session across all models!
    final continuingSessionId = (_tickerItems.isNotEmpty && _currentJobId != null) ? _currentJobId : null;
    final prevConvByModel = <String, List<TickerMessage>>{
      for (final t in _tickerItems) t.modelDef.id: List<TickerMessage>.from(t.conversation),
    };
    setState(() {
      _busy = true;
      _isComposerSummoned = _voiceChat; // in Voice Chat the composer stays, its button is the microphone
      _closeAllPanes();
      _currentPrompt = prompt;
      _promptTime = now;
      _isConsensusGenerating = true;
      _consensusRatio = 'Consensus';
      _consensusSummary = '';
      _tickerItems = [
        for (final id in models)
          TickerItem(
            modelDef: ModelRoster.byId(id)!,
            relativeTime: '',
            summary: '',
            isStreaming: true,
            conversation: [
              if (continuingSessionId != null && prevConvByModel.containsKey(id)) ...prevConvByModel[id]!,
              TickerMessage(id: 'u_${now.microsecondsSinceEpoch}_$id', sender: 'user', text: prompt, timestamp: now),
            ],
          ),
      ];
    });
    try {
      final id = await ColliderApi.instance.ask(
        prompt: prompt,
        models: models,
        mode: _mode,
        autosave: _autosave,
        incognito: _incognito,
        attachments: files,
        line: _lineChars,
        sessionId: continuingSessionId,
      );
      await for (final j in ColliderApi.instance.watch(id)) {
        if (!mounted) return;
        setState(() => _applyJob(j));
      }
      ColliderApi.instance.cachedHistory = null;
      await _reloadHistory(forceRefresh: true);
      SmartGenStore.instance.syncAutonomousCards();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isConsensusGenerating = false;
        // The same words the model rows use when a model does not answer. No technical reason on screen.
        _consensusSummary = 'No answer';
        _tickerItems = [for (final t in _tickerItems) t.copyWith(isStreaming: false, summary: 'No answer')];
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Load conversation and immediately send user there in expanded view
  void _loadAndExpandSession(ConversationHistorySession session) {
    final jobId = session.id.split('_').first;
    if (_jobsById.containsKey(jobId)) {
      setState(() {
        _closeAllPanes();
        _tickerItems = [];
        _applyJob(_jobsById[jobId]!, restored: true);
        _expandedModelIds.clear();
        final targetId = session.targetModelId ?? (_tickerItems.isNotEmpty ? _tickerItems.first.modelDef.id : null);
        if (targetId != null) {
          final targetDef = ModelRoster.byId(targetId);
          if (targetDef != null && !targetDef.categories.contains(_activeCategory) && targetDef.categories.isNotEmpty) {
            _activeCategory = targetDef.categories.first;
          }
          _expandedModelIds.add(targetId);
        }
      });
      return;
    }
    setState(() {
      _activeDrawer = null;
      _localHistoryModel = null;
      _zoomedMessage = null;
      _isMobileSideNavOpen = false;

      final targetId = session.targetModelId ?? (session.modelIds.isNotEmpty ? session.modelIds.first : _selectedModelIds.first);
      
      // Ensure target model is in selected list so it appears in the active rows
      if (!_selectedModelIds.contains(targetId)) {
        _selectedModelIds.insert(0, targetId);
      }

      // Ensure active category matches target model's category
      final targetDef = ModelRoster.byId(targetId);
      if (targetDef != null && !targetDef.categories.contains(_activeCategory) && targetDef.categories.isNotEmpty) {
        _activeCategory = targetDef.categories.first;
      }

      final idx = _tickerItems.indexWhere((it) => it.modelDef.id == targetId);
      if (idx != -1) {
        _tickerItems[idx] = _tickerItems[idx].copyWith(
          conversation: session.messages,
          summary: session.summary,
          relativeTime: session.relativeTime,
        );
      }

      _expandedModelIds.clear();
      _expandedModelIds.add(targetId);
    });
  }

  bool _browserOpen = false;

  /// The web sources of the conversation on screen, numbered as its answers cite them.
  List<Map<String, dynamic>> get _currentSources => _jobsById[_currentJobId]?.sources ?? const [];

  void _openBrowserForTab(String tabId) {
    setState(() {
      _activeDrawer = null;
      _browserOpen = true;
    });
    showDialog(
      context: context,
      barrierDismissible: true, // Two-Escape Law: clickaway backdrop dismisses
      barrierColor: VOverlay.scrim,
      builder: (ctx) {
        return InAppBrowserSheet(
          initialTabId: tabId,
          tabs: _browserTabs,
          incognito: _incognito,
          onTabUpdated: (updated) {
            setState(() {
              final idx = _browserTabs.indexWhere((t) => t.id == updated.id);
              if (idx != -1) _browserTabs[idx] = updated;
            });
          },
          onNewUserTab: (newTab) {
            setState(() {
              _browserTabs.add(newTab);
            });
          },
        );
      },
    ).then((_) {
      if (mounted) setState(() => _browserOpen = false);
    });
  }

  bool _locked(WallpaperTheme t) => ThemePackStore.instance.priceFor(t) != null && !ThemePackStore.instance.isUnlocked(t.id);

  Widget _buildSideNav({required bool isMobile}) {
    // REQ-21 visual language: a slim detached rail of circular glass buttons sits at
    // the screen edge; the contextual panel content opens beside it when summoned.
    final surface = _currentActiveSurface;
    final String? railKey = switch (surface) {
      ActiveWorkSurface.chat => _activeDrawer == 'history' ? 'history' : (_isMobileSideNavOpen ? _chatSection : null),
      ActiveWorkSurface.smartgen => _smartGenView,
      ActiveWorkSurface.market => _marketCategory,
      ActiveWorkSurface.themes => _activeDrawer == 'premium' ? 'premium' : 'gallery',
      ActiveWorkSurface.browser => null,
      ActiveWorkSurface.files => _filesCategory,
    };

    void togglePanel(void Function() apply, bool same) {
      setState(() {
        apply();
        _isMobileSideNavOpen = same ? !_isMobileSideNavOpen : true;
      });
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SideNavRail(
          surface: surface,
          activeKey: railKey,
          compact: isMobile,
          onSelect: (key) {
            switch (surface) {
              case ActiveWorkSurface.chat:
                if (key == 'new') {
                  _newConversation();
                } else if (key == 'history') {
                  _openDrawer('history');
                } else {
                  togglePanel(() => _chatSection = key, key == _chatSection);
                }
              case ActiveWorkSurface.smartgen:
                setState(() {
                  _isMobileSideNavOpen = false;
                  if (key == 'new') {
                    _smartGenNewCardTrigger++;
                  } else {
                    _smartGenView = key;
                  }
                });
              case ActiveWorkSurface.market:
                setState(() {
                  _isMobileSideNavOpen = false;
                  _marketCategory = key;
                });
              case ActiveWorkSurface.themes:
                setState(() {
                  _isMobileSideNavOpen = false;
                  _themeSection = key;
                  _activeDrawer = key == 'gallery' ? 'themes' : key;
                });
              case ActiveWorkSurface.browser:
                break;
              case ActiveWorkSurface.files:
                setState(() {
                  _isMobileSideNavOpen = false;
                  _filesCategory = key;
                });
            }
          },
        ),
        if (_isMobileSideNavOpen && (surface == ActiveWorkSurface.chat || surface == ActiveWorkSurface.market)) ...[
          const SizedBox(width: 10),
          ContextualSideNav(
            activeSurface: _currentActiveSurface,
            activeCategory: _activeCategory,
            selectedModelIds: _selectedModelIds,
            localHistory: _localHistorySessions,
            globalHistory: _globalHistorySessions,
            consensusRatio: _consensusRatio,
            consensusSummary: _consensusSummary,
            expandedModelId: _expandedModelIds.isNotEmpty ? _expandedModelIds.first : null,
            chatSection: _chatSection,
            onClose: () => setState(() => _isMobileSideNavOpen = false),
      onSelectCategory: (cat) => setState(() => _activeCategory = cat),
      onToggleModel: (modelId) {
        setState(() {
          if (_selectedModelIds.contains(modelId)) {
            if (_selectedModelIds.length > 1) {
              _selectedModelIds.remove(modelId);
            }
          } else {
            if (_selectedModelIds.length < 9) {
              _selectedModelIds.add(modelId);
            }
          }
        });
      },
      onSelectSession: (sess) => _loadAndExpandSession(sess),
      onOpenConsensus: () => _requestSwitchSurface('consensus'),
      onNewConversation: _newConversation,
      activeSmartGenView: _smartGenView,
      activeSmartGenBoardType: _smartGenBoardType,
      onSelectSmartGenView: (v) => setState(() => _smartGenView = v),
      onSelectSmartGenBoardType: (b) => setState(() => _smartGenBoardType = b),
      activeMarketCategory: _marketCategory,
      onSelectMarketCategory: (c) => setState(() => _marketCategory = c),
      activeThemeSection: _themeSection,
      onSelectThemeSection: (s) {
        setState(() {
          _themeSection = s;
          if (s == 'gallery') _activeDrawer = 'themes';
          else if (s == 'premium') _activeDrawer = 'premium';
        });
      },
      browserTabs: _browserTabs,
      activeBrowserTabId: 'user_default',
      onCloseBrowserTab: (id) => setState(() => _browserTabs.removeWhere((t) => t.id == id)),
      
      activeFilesCategory: _filesCategory,
      onSelectFilesCategory: (c) => setState(() => _filesCategory = c),
      onRequestSwitchSurface: (surface) {
        final target = switch (surface) {
          ActiveWorkSurface.chat => null,
          ActiveWorkSurface.smartgen => 'smartgen',
          ActiveWorkSurface.market => 'market',
          ActiveWorkSurface.themes => 'themes',
          ActiveWorkSurface.browser => null,
          ActiveWorkSurface.files => 'files',
        };
        _requestSwitchSurface(target);
      },
      onPaneInteraction: () {},
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Max 9 active model rows filtered by active category with fallback
    var categoryPills = _tickerItems
        .where((it) => it.modelDef.categories.contains(_activeCategory) && _selectedModelIds.contains(it.modelDef.id))
        .take(9)
        .toList();

    if (categoryPills.isEmpty) {
      categoryPills = _tickerItems
          .where((it) => it.modelDef.categories.contains(_activeCategory))
          .take(9)
          .toList();
    }

    final activePills = categoryPills;
    final media = _activeCategory == ModelCategory.image;
    final isMobile = MediaQuery.of(context).size.width < 768;

    // The opened conversation, if any.
    final openId = _expandedModelIds.isEmpty ? null : _expandedModelIds.first;
    final TickerItem? openItem = activePills.where((p) => p.modelDef.id == openId).firstOrNull;
    // On a phone the opened conversation is wide; the side navigation steps aside for it.
    // side by side: the rows as the left column and the conversation as a closeable pane beside them
    final sideBySide = openItem != null && !media;
    // On a phone the window takes the side navigation's room while a conversation is open.
    final railVisible = _railVisible && !(isMobile && sideBySide);
    final screenW = MediaQuery.sizeOf(context).width;

    // Expanded: that model's conversation, closeable, opened under its own summary (see the rows below).
    final Widget conversation = openItem == null
        ? const SizedBox.shrink()
        : ConversationView(
            key: ValueKey('conv-${openItem.modelDef.id}'),
            item: openItem,
            fill: true, // the pane's full height, the entry box at its foot
            onClose: () => setState(() => _expandedModelIds.clear()),
            onSendReply: (reply, files) => _onSendInlineReply(openItem.modelDef.id, reply, files),
            onOpenBrowser: () => _openBrowserForTab(_browserTabs.length > 1 ? _browserTabs[1].id : 'user_default'),
            onTapMessage: (msg) => setState(() {
              _zoomedMessage = msg;
              _zoomedModelDef = openItem.modelDef;
            }),
            onOpenLocalHistory: () => setState(() => _localHistoryModel = openItem.modelDef),
            onSend: () => _sendText(_conversationText(openItem)),
            onOpen: () => _openTextAsDocument(openItem.modelDef.label, _conversationText(openItem), openItem.modelDef.label),
          );

    // Collapsed: the consensus row pinned on top, then one row per model.
    final Widget rows = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_tickerItems.isNotEmpty) ...[
          ConsensusRow(
            agreementRatio: _consensusRatio,
            summary: _consensusSummary,
            isGenerating: _isConsensusGenerating,
            onTap: () => setState(() => _activeDrawer = 'consensus'),
          ),
          if (activePills.isNotEmpty) const SizedBox(height: 13),
        ],
        if (activePills.isNotEmpty)
          Flexible(
            child: EdgeFade(
              fadeHeight: 40,
              focus: FadeFocus.top,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < activePills.length; i++) ...[
                      if (i > 0) const SizedBox(height: 13),
                      // the summary and the conversation it opens are one piece, scrolled into view together
                      Column(
                        key: activePills[i].modelDef.id == openId ? _openKey : null,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      ModelPill(
                        item: activePills[i],
                        elevation: activePills.length <= 1 ? 1.0 : 1.0 - i / (activePills.length - 1),
                        isExpanded: activePills[i].modelDef.id == openId,
                        compact: openItem != null,
                        onToggleExpand: () => _onTogglePill(activePills[i].modelDef.id),
                      ),
                      // The conversation opens in the detail view over the room; the ticker keeps its size and place
                      // (Claude, 2026-10-23; it used to grow out of the summary).
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    if (ThemeBlurCache.instance.activeAssetPath != _currentTheme.assetPath) {
      ThemeBlurCache.instance.setActiveTheme(_currentTheme);
    }
    final desktopSurfaceLeft = isMobile ? 0.0 : (_isMobileSideNavOpen ? 340.0 : 0.0);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ================= PLANE 0: BACKGROUND WALLPAPER =================
          Positioned.fill(
            child: ThemeLivingBackdrop(
              theme: _currentTheme,
              // Asset-swap: live loop + cached ambient frame when Premium Market
              preferVideo: true,
              // Locked: the source's near-black dim. Unlocked (or free): the wallpaper itself, full and lit (David, 21 Oct).
              builderAmbient: _activeDrawer == 'premium' && _locked(_currentTheme),
            ),
          ),

          // Theme Gallery (69:1926): the room behind the picture uses pre-rendered cached blur (0 shader regeneration).
          if (_activeDrawer == 'themes')
            Positioned.fill(
              child: CachedThemeSurface(
                assetPath: _currentTheme.assetPath,
                preset: ThemeBlurPreset.galleryRoom,
              ),
            ),
          // ================= PLANE 1: RESTING WORKSPACE =================
          // Hidden during Premium Theme Market (Body) so ticker chrome doesn't bleed through
          // The resting workspace stays where it is under any window: hidden and paused (no drawing, no animation), then
          // shown again exactly as it was. It used to be taken off the screen, and everything typed in it went too.
          // (Claude, 2026-10-23)
          Positioned.fill(
            bottom: 78,
            child: Builder(builder: (context) {
              final resting = !_browserOpen && !(isMobile && _isMobileSideNavOpen) &&
                  !const {'premium', 'themes', 'apps', 'settings', 'smartgen', 'market', 'files', 'consensus'}.contains(_activeDrawer);
              return Visibility(
                visible: resting,
                maintainState: true,
                child: TickerMode(
                  enabled: resting,
                  child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                // On a phone the ticker and the composer stand beside the side navigation, never under it
                // (Claude, 2026-10-23: the rail covered the ticker's lower left corner).
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ================= THE TICKER WINDOW =================
                    // Rows are the collapsed state. An opened conversation is its own view:
                    // beside the rows where there is room, in their place on a phone.
                    Padding(
                      // beside the side navigation on a phone, never under it
                      padding: EdgeInsets.only(left: isMobile && !media && !sideBySide ? 76 : 0),
                      child: Center(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: sideBySide
                              ? (isMobile ? screenW - 20 : (screenW - 220).clamp(480.0, 872.0))
                              : isMobile
                                  ? (media ? 360.0 : 300.0) // the pictures' toolbar fits whole (Claude, 2026-10-21)
                                  : (media ? 780.0 : 480.0),
                          // rows: never more than 40% of the screen; a conversation: "halfway up is sufficient"
                          maxHeight: MediaQuery.of(context).size.height * (sideBySide || (media && _mediaExpanded) ? 0.50 : 0.40),
                        ),
                        height: sideBySide ? MediaQuery.of(context).size.height * 0.50 : null,
                        margin: EdgeInsets.symmetric(horizontal: sideBySide ? 0 : (isMobile ? 12 : 24)),
                        child: VGlass(
                          radius: VRadius.card,
                          material: VMaterial.resting,
                          padding: const EdgeInsets.all(VSpace.xs),
                          child: media
                              ? GenerationsPane(
                                  aspect: _aspect,
                                  count: _count,
                                  onAspect: (a) => setState(() => _aspect = a),
                                  onCount: (n) => setState(() => _count = n),
                                  expanded: _mediaExpanded,
                                  onToggleExpanded: () => setState(() => _mediaExpanded = !_mediaExpanded),
                                  onRemix: (ref) => _toImageChat(reference: ref),
                                  refresh: _mediaRefresh,
                                )
                              : sideBySide
                                  ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                      SizedBox(width: isMobile ? 136 : 300, child: Align(alignment: Alignment.topCenter, child: rows)),
                                      const SizedBox(width: VSpace.xs),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                                          decoration: BoxDecoration(color: VColors.fillRow, borderRadius: BorderRadius.circular(VRadius.card - VSpace.xs)),
                                          child: conversation,
                                        ),
                                      ),
                                    ])
                                  : rows,
                        ),
                      ),
                    ),
                    ),
                    const SizedBox(height: 4),
                    // The composer is its own element, never a row of the ticker. Tucked, it is an arrow.
                    Padding(
                      // in the ticker's column, beside the side navigation; it stays put when a conversation opens
                      padding: EdgeInsets.only(left: isMobile && !media ? 76 : 0),
                      child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isMobile ? 300.0 : 480.0),
                      child: FloatingPrompt(
                        summoned: _isComposerSummoned,
                        busy: _busy,
                        mode: _mode,
                        incognito: _incognito,
                        onMode: (m) => setState(() => _mode = m),
                        onIncognito: (v) => setState(() => _incognito = v),
                        onSubmitPrompt: (text, files) => _onSendPrompt(text, files),
                        voice: _voiceChat ? _voicePhase : null,
                        onVoiceChat: _setVoiceChat,
                        onMic: _onMic,
                        continuingTitle: (_tickerItems.isNotEmpty && _currentJobId != null) ? _currentPrompt : null,
                        onNewConversation: _newConversation,
                        onSummon: () => setState(() {
                          _closeAllPanes();
                          _isComposerSummoned = true;
                        }),
                        onTuck: () => setState(() => _isComposerSummoned = false),
                      ),
                    ),
                    ),
                  ],
                ),
                ),
              ),
            ),
                ),
              );
            }),
          ),

          // ================= PLANE 2: APPS POPUP PANE =================
          // Middle neutral area, no visible canvas, blurred background, clickaway + close icon
          if (_activeDrawer == 'apps')
            Positioned.fill(
              child: AppsPopupPane(
                onClose: () => setState(() => _activeDrawer = null),
                themeArt: _currentTheme.assetPath,
                onOpenSmartGen: () => _requestSwitchSurface('smartgen'),
                onOpenDiscoverMarket: () => _requestSwitchSurface('market'),
                onOpenThemeGallery: () => _requestSwitchSurface('themes'),
                onOpenPremiumMarketplace: () => _requestSwitchSurface('premium'),
                onOpenFiles: () => _openDrawer('files'),
                onOpenDocuments: () => _openDocument(),
                onOpenMusicPlayer: _openMusic,
                onOpenBrowser: () => _openBrowserForTab('user_default'),
              ),
            ),

          // ================= PLANE 3: LOCAL MODEL HISTORY PANE =================
          // Centered popup pane, searches body & title, relative timestamps
          if (_localHistoryModel != null)
            Positioned.fill(
              child: LocalHistoryPane(
                modelDef: _localHistoryModel!,
                sessions: _localHistorySessions[_localHistoryModel!.id] ?? const [],
                onSelectSession: (sess) => _loadAndExpandSession(sess),
                onClose: () => setState(() => _localHistoryModel = null),
              ),
            ),

          // ================= PLANE 4: MESSAGE ZOOM OVERLAY =================
          // Dimmed/blurred backdrop, no visible window, faded edges, bottom actions
          // An answer that drew on the web opens as a document with its sources (Claude, 2026-10-20).
          if (_zoomedMessage != null && _zoomedModelDef != null && _zoomedMessage!.sender == 'model' && _currentSources.isNotEmpty)
            Positioned.fill(
              child: ResearchDocument(
                message: _zoomedMessage!,
                modelName: _zoomedModelDef!.label,
                sources: _currentSources,
                onOpenSource: (i) => _openBrowserForTab('src_$i'),
                onClose: () => setState(() => _zoomedMessage = null),
              ),
            )
          else if (_zoomedMessage != null && _zoomedModelDef != null)
            Positioned.fill(
              child: MessageZoomOverlay(
                message: _zoomedMessage!,
                modelName: _zoomedModelDef!.label,
                providerColor: _zoomedModelDef!.providerColor,
                onClose: () => setState(() => _zoomedMessage = null),
                onOpen: () => _openTextAsDocument(_zoomedModelDef!.label, _zoomedMessage!.text, _zoomedModelDef!.label),
              ),
            ),

          // ================= PLANE 5: DRAWERS & DURABLE WORK SURFACES =================
          if (_activeDrawer == 'history')
            Positioned.fill(
              child: HistoryPane(
                sessions: _globalHistorySessions,
                job: (id) => _jobsById[id],
                onLoad: (sess) => _loadAndExpandSession(sess),
                onClose: () => setState(() => _activeDrawer = null),
                onUpdated: () => _reloadHistory(forceRefresh: true),
              ),
            ),

          if (_activeDrawer == 'themes')
            Positioned(
              left: 0,
              right: 0,
              top: 0, // the whole screen takes the pull up toward the live wallpapers
              bottom: 84,
              child: WindowlessThemeScroller(
                currentTheme: _currentTheme,
                onLivePreview: (theme) => setState(() => _currentTheme = theme),
                onConfirmTheme: (theme) => setState(() {
                  _currentTheme = theme;
                  _savedThemeBeforePreview = theme;
                  _activeDrawer = null;
                }),
                onCancel: () => setState(() {
                  _currentTheme = _savedThemeBeforePreview;
                  _activeDrawer = null;
                }),
                onUpgradeTier: () => setState(() => _activeDrawer = 'premium'),
              ),
            ),

          if (_activeDrawer == 'premium')
            Positioned.fill(
              // Swipe down returns to the free Theme Gallery.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) > 300) setState(() => _activeDrawer = 'themes');
                },
                child: PremiumThemeMarketView(
                currentTheme: _currentTheme,
                onApplyTheme: (theme) => setState(() {
                  _currentTheme = theme;
                  _savedThemeBeforePreview = theme;
                  _activeDrawer = null;
                }),
                onPreviewTheme: (theme) => setState(() {
                  _currentTheme = theme;
                }),
                onClose: () => setState(() => _activeDrawer = null),
              ),
              ),
            ),

          if (_activeDrawer == 'settings')
            Positioned.fill(
              child: SettingsDrawer(
                onClose: () => setState(() => _activeDrawer = null),
                incognito: _incognito,
                autosave: _autosave,
                onIncognito: (v) => setState(() => _incognito = v),
                onAutosave: (v) => setState(() => _autosave = v),
                onOpenPurchased: () {
                  _filesPlace = 'purchased';
                  _requestSwitchSurface('files');
                },
                onOpenUpgrade: () => setState(() => _activeDrawer = 'upgrade'),
              ),
            ),

          // Durable work surfaces sit over one shared scrim (kit overlay + cached blur).
          if (_activeDrawer == 'smartgen' || _activeDrawer == 'market' || _activeDrawer == 'files' || _activeDrawer == 'documents')
            const Positioned.fill(child: VScrim()),

          if (_activeDrawer == 'smartgen')
            Positioned(
              left: desktopSurfaceLeft,
              right: 0,
              top: 0,
              bottom: 78,
              child: SmartGenScreen(
                onClose: () => _requestSwitchSurface(null),
                viewMode: _smartGenView,
                onViewModeChanged: (v) => setState(() => _smartGenView = v),
                newCardTrigger: _smartGenNewCardTrigger,
              ),
            ),

          if (_activeDrawer == 'market')
            Positioned(
              left: desktopSurfaceLeft,
              right: 0,
              top: 0,
              bottom: 78,
              child: MarketScreen(
                onClose: () => _requestSwitchSurface(null),
                view: _marketCategory,
                onImagine: (t) => _toImageChat(text: t),
                onRemix: (ref) => _toImageChat(reference: ref),
              ),
            ),

          if (_activeDrawer == 'upgrade')
            Positioned.fill(
              child: UpgradeScreen(
                onClose: () => setState(() => _activeDrawer = null),
              ),
            ),

          if (_activeDrawer == 'skills')
            Positioned.fill(
              child: SkillsScreen(
                onClose: () => setState(() => _activeDrawer = null),
              ),
            ),

          if (_activeDrawer == 'files')
            Positioned(
              left: desktopSurfaceLeft,
              right: 0,
              top: 0,
              bottom: 78,
              child: FilesScreen(
                key: ValueKey('files-$_filesPlace'),
                initialPlace: _filesPlace,
                onClose: () => _requestSwitchSurface(null),
                onOpenDocument: (url, name) => _openDocument(url, name),
              ),
            ),

          if (_activeDrawer == 'documents')
            Positioned(
              left: desktopSurfaceLeft,
              right: 0,
              top: 0,
              bottom: 78,
              child: DocumentsScreen(
                key: ValueKey('documents-$_docUrl'),
                fileUrl: _docUrl,
                fileName: _docName,
                onClose: () => _requestSwitchSurface(null),
              ),
            ),

          if (_activeDrawer == 'consensus')
            Positioned.fill(
              child: ConsensusWebView(
                job: _currentJobId == null ? null : _jobsById[_currentJobId],
                onClose: () => setState(() => _activeDrawer = null),
              ),
            ),

          // The browser opens over the room; the room goes out of focus behind it via cached blur.
          if (_browserOpen)
            Positioned.fill(
              child: IgnorePointer(
                child: CachedThemeSurface(
                  assetPath: _currentTheme.assetPath,
                  preset: ThemeBlurPreset.scrim,
                ),
              ),
            ),

          // ================= PLANE 3: CONTEXTUAL SIDE NAV =================
          if (isMobile) ...[
            // Mobile backdrop when side nav is open
            if (_isMobileSideNavOpen && railVisible)
              Positioned.fill(
                child: VScrim(soft: true, onTap: () => setState(() => _isMobileSideNavOpen = false)),
              ),

            // REQ-21: the rail ornament is present on the resting canvas and every
            // durable work surface; focused overlays own the stage while open.
            if (railVisible)
              Positioned(
                left: 2,
                bottom: 84,
                child: _buildSideNav(isMobile: true),
              ),
          ] else ...[
            if (railVisible)
            Positioned(
              left: 12,
              bottom: 84,
              child: _buildSideNav(isMobile: false),
            ),
          ],

          // ================= MUSIC WIDGET: draggable, stays where it is placed =================
          if (_activeDrawer != 'premium')
            Builder(builder: (context) {
              final size = MediaQuery.of(context).size;
              final pos = _musicPos ?? Offset((size.width - 308) / 2, 52);
              return Positioned(
                left: pos.dx,
                top: pos.dy,
                child: GestureDetector(
                  onPanUpdate: (d) => setState(() {
                    final n = (_musicPos ?? pos) + d.delta;
                    _musicPos = Offset(n.dx.clamp(0.0, size.width - 120), n.dy.clamp(0.0, size.height - 60));
                  }),
                  child: MusicWidget(onOpenLibrary: _openMusic),
                ),
              );
            }),

          // ================= PLANE 4: PERMANENT BOTTOM DOCK =================
          // Hidden during Premium Theme Market so transport stays in-frame (Figma Body)
          if (_activeDrawer != 'premium')
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Center(
                child: PermanentNavBar(
                  isComposerSummoned: _isComposerSummoned,
                  onToggleComposer: _toggleComposer,
                  onHome: () {
                    if (_activeDrawer != null) {
                      _requestSwitchSurface(null);
                    } else {
                      _openHomeComposer();
                    }
                  },
                  onApps: () => _openDrawer('apps'),
                  onSettings: () => _openDrawer('settings'),
                  activeDrawer: _activeDrawer,
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}

