import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../common/theme.dart';

// ─── AI API URL ──────────────────────────────────────────────────────────────
// Za lokalni razvoj: 'http://localhost:8080'
// Za produkcijo:     'https://risbo.onrender.com'
const _kRisboBaseUrl = 'https://risbo.onrender.com';

// ─── ENTRY POINT ─────────────────────────────────────────────────────────────

class RecipePage extends StatefulWidget {
  const RecipePage({super.key});

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage>
    with SingleTickerProviderStateMixin {
  AppColors get c => AppColors.of(context);
  final Set<String> _selected = {};
  List<_Recipe> _recipes = [];
  bool _loadingRecipes = false;
  String? _recipeError;

  bool _aiOpen = false;
  late AnimationController _slideCtrl;
  late Animation<double> _slideAnim;

  final List<_ChatMsg> _chatMsgs = [];
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  bool _aiThinking = false;

  Set<String> _ingredients = {};
  bool _loadingIngredients = true;

  // ── Slika sestavin ──────────────────────────────────────────────────────────
  XFile? _pickedImage;
  bool _generatingFromImage = false;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _loadIngredients();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  // ── Sestavine iz Firestore ──────────────────────────────────────────────────

  Future<void> _loadIngredients() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingIngredients = false);
      return;
    }
    try {
      // Queryjaj kolekciju 'rezervacije' direktno po userId
      final rezSnap = await FirebaseFirestore.instance
          .collection('rezervacije')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['rezervirano', 'prevzeto'])
          .get();

      if (rezSnap.docs.isEmpty) {
        if (mounted) setState(() => _loadingIngredients = false);
        return;
      }

      // Dohvati sve oglas IDje iz rezervacija
      final oglasIds = rezSnap.docs
          .map((d) => d.data()['oglasId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final result = <String>{};

      // Firestore 'whereIn' max 30 po pozivu — dijelimo u grupe
      for (var i = 0; i < oglasIds.length; i += 30) {
        final end = i + 30 > oglasIds.length ? oglasIds.length : i + 30;
        final chunk = oglasIds.sublist(i, end);
        final oglasSnap = await FirebaseFirestore.instance
            .collection('oglasi')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in oglasSnap.docs) {
          final d = doc.data();
          final title = d['title'] as String? ?? '';
          final category = d['category'] as String? ?? '';
          final parts = title.split(RegExp(r'[,;|/\n]'));
          for (final p in parts) {
            final t = p.trim();
            if (t.length > 2 && t.length < 60) result.add(t);
          }
          if (category.isNotEmpty) result.add(category);
        }
      }

      if (mounted) setState(() {
        _ingredients = result;
        _loadingIngredients = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingIngredients = false);
    }
  }

  // ── AI: generiraj recepte z Gemini ─────────────────────────────────────────

  Future<void> _generateRecipes() async {
    if (_selected.isEmpty) return;
    setState(() {
      _loadingRecipes = true;
      _recipeError = null;
      _recipes = [];
    });

    final sestavine = _selected.join(', ');
    final prompt = 'Si kuhar. Generiraj 3 kratke recepte z sestavinami: $sestavine. '
        'Odgovori SAMO z veljavnim JSON nizom. Brez Markdown. Brez ```json. Samo čisti JSON: '
        '[{"name":"...","emoji":"...","time":"15 min","difficulty":"lahka",'
        '"description":"Kratek opis.","steps":["Korak 1.","Korak 2.","Korak 3."],'
        '"matchedIngredients":["..."]}] '
        'Vsak recept naj ima NAJVEČ 4 korake. Opisi naj bodo kratki.';

    try {
      final resp = await http.post(
        Uri.parse('$_kRisboBaseUrl/generate-recipe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 90)); // Render free tier ima cold start ~60s

      if (resp.statusCode != 200) {
        throw Exception('Risbo API napaka ${resp.statusCode}');
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final text = body['response'] as String? ?? '';

      // Izvleci JSON array iz odgovora
      final cleaned = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final startIdx = cleaned.indexOf('[');
      final endIdx = cleaned.lastIndexOf(']');
      if (startIdx == -1 || endIdx == -1) throw Exception('Napaka pri razčlenjevanju receptov');

      final jsonStr = cleaned.substring(startIdx, endIdx + 1);
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      final recipes = jsonList.map((e) => _Recipe.fromJson(e as Map<String, dynamic>)).toList();

      if (mounted) setState(() { _recipes = recipes; _loadingRecipes = false; });
    } on TimeoutException {
      if (mounted) setState(() {
        _recipeError = 'Strežnik se zagotavlja (hladni zagon ~60s). Počakajte in poskusite znova.';
        _loadingRecipes = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _recipeError = 'Napaka: ${e.toString()}';
        _loadingRecipes = false;
      });
    }
  }

  // ── AI: generiraj iz slike ─────────────────────────────────────────────────

  Future<void> _pickAndGenerateFromImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (file == null) return;

    setState(() {
      _pickedImage = file;
      _generatingFromImage = true;
      _loadingRecipes = true;
      _recipeError = null;
      _recipes = [];
    });

    try {
      final bytes = await File(file.path).readAsBytes();
      final b64 = base64Encode(bytes);

      final prompt = 'Na sliki so sestavine. Generiraj 3 kratke recepte z njimi. '
          'Odgovori SAMO z veljavnim JSON nizom. Brez Markdown. Brez ```json. Samo čisti JSON: '
          '[{"name":"...","emoji":"...","time":"15 min","difficulty":"lahka",'
          '"description":"Kratek opis.","steps":["Korak 1.","Korak 2.","Korak 3."],'
          '"matchedIngredients":["..."]}] '
          'Vsak recept naj ima NAJVEČ 4 korake. Opisi naj bodo kratki.';

      final resp = await http.post(
        Uri.parse('$_kRisboBaseUrl/generate-recipe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt, 'images': [b64]}),
      ).timeout(const Duration(seconds: 90));

      if (resp.statusCode != 200) throw Exception('Risbo API napaka \${resp.statusCode}');

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final text = body['response'] as String? ?? '';

      final cleaned = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final startIdx = cleaned.indexOf('[');
      final endIdx = cleaned.lastIndexOf(']');
      if (startIdx == -1 || endIdx == -1) throw Exception('Napaka pri razčlenjevanju receptov');

      final jsonStr = cleaned.substring(startIdx, endIdx + 1);
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      final recipes = jsonList.map((e) => _Recipe.fromJson(e as Map<String, dynamic>)).toList();

      if (mounted) setState(() {
        _recipes = recipes;
        _loadingRecipes = false;
        _generatingFromImage = false;
      });
    } on TimeoutException {
      if (mounted) setState(() {
        _recipeError = 'Strežnik se zagotavlja (hladni zagon ~60s). Počakajte in poskusite znova.';
        _loadingRecipes = false;
        _generatingFromImage = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _recipeError = 'Napaka: \${e.toString()}';
        _loadingRecipes = false;
        _generatingFromImage = false;
      });
    }
  }

  // ── AI: pošlji sliko v chat ─────────────────────────────────────────────────

  Future<void> _sendChatWithImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (file == null) return;

    setState(() {
      _chatMsgs.add(_ChatMsg(text: '📷 Slika sestavin', isAi: false, imageFile: file));
      _aiThinking = true;
    });
    _scrollChat();

    try {
      final bytes = await File(file.path).readAsBytes();
      final b64 = base64Encode(bytes);

      final prompt = 'Si kuhar pomočnik. Na sliki so sestavine. '
          'Predlagaj 2-3 ideje za obroke. Odgovori kratko v slovenščini.';

      final resp = await http.post(
        Uri.parse('$_kRisboBaseUrl/generate-recipe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt, 'images': [b64]}),
      ).timeout(const Duration(seconds: 90));

      if (resp.statusCode != 200) throw Exception('API error');

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final reply = (body['response'] as String? ?? 'Oprostite, nisem razumel.').trim();

      if (mounted) setState(() {
        _chatMsgs.add(_ChatMsg(text: reply, isAi: true));
        _aiThinking = false;
      });
      _scrollChat();
    } on TimeoutException {
      if (mounted) setState(() {
        _chatMsgs.add(_ChatMsg(text: 'Strežnik se zagotavlja (~60s). Poskusite znova.', isAi: true));
        _aiThinking = false;
      });
      _scrollChat();
    } catch (_) {
      if (mounted) setState(() {
        _chatMsgs.add(_ChatMsg(text: 'Napaka pri obdelavi slike.', isAi: true));
        _aiThinking = false;
      });
      _scrollChat();
    }
  }

  // ── AI chat (OpenRouter) ─────────────────────────────────────────────────────

  void _toggleAi() {
    setState(() => _aiOpen = !_aiOpen);
    if (_aiOpen) {
      _slideCtrl.forward();
      if (_chatMsgs.isEmpty) {
        _chatMsgs.add(_ChatMsg(
          text: 'Živjo! 👋 Pomagam ti s kuhanjem. Imaš vprašanje o sestavinah, receptu ali čem drugem?',
          isAi: true,
        ));
      }
    } else {
      _slideCtrl.reverse();
    }
  }

  Future<void> _sendChat(String text) async {
    if (text.trim().isEmpty) return;
    _chatCtrl.clear();
    setState(() {
      _chatMsgs.add(_ChatMsg(text: text.trim(), isAi: false));
      _aiThinking = true;
    });
    _scrollChat();

    try {
      // Složi kontekst pogovora v en prompt
      final history = _chatMsgs
          .map((m) => '${m.isAi ? "Asistent" : "Uporabnik"}: ${m.text}')
          .join('\n');

      final prompt = 'Si prijazni kuhar pomočnik v aplikaciji FoodWasteZero. '
          'Pomagaj z recepti, sestavinami in kuhanjem. '
          'Odgovori kratko (največ 3 stavke). Piši v slovenščini.\n\n'
          'Pogovor do sedaj:\n$history\n\nTvoj odgovor:';

      final chatResp = await http.post(
        Uri.parse('$_kRisboBaseUrl/generate-recipe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 90));

      if (chatResp.statusCode != 200) throw Exception('Risbo API error');

      final chatBody = jsonDecode(chatResp.body) as Map<String, dynamic>;
      final reply = (chatBody['response'] as String? ?? 'Oprostite, nisem razumel.').trim();

      if (mounted) setState(() {
        _chatMsgs.add(_ChatMsg(text: reply, isAi: true));
        _aiThinking = false;
      });
      _scrollChat();
    } on TimeoutException {
      if (mounted) setState(() {
        _chatMsgs.add(_ChatMsg(text: 'Strežnik se zagotavlja (~60s hladni zagon). Počakajte in poskusite znova.', isAi: true));
        _aiThinking = false;
      });
      _scrollChat();
    } catch (_) {
      if (mounted) setState(() {
        _chatMsgs.add(_ChatMsg(text: 'Napaka pri povezavi z AI. Poskusite znova.', isAi: true));
        _aiThinking = false;
      });
      _scrollChat();
    }
  }

  void _scrollChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: c.surface,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _slideAnim,
            builder: (_, child) {
              final shift = MediaQuery.of(context).size.width * 0.75 * _slideAnim.value;
              return Transform.translate(
                offset: Offset(-shift, 0),
                child: child,
              );
            },
            child: _buildMain(user),
          ),
          AnimatedBuilder(
            animation: _slideAnim,
            builder: (_, __) {
              final w = MediaQuery.of(context).size.width * 0.75;
              final right = w * (_slideAnim.value - 1);
              return Positioned(
                top: 0, bottom: 0, right: right, width: w,
                child: _buildAiPanel(),
              );
            },
          ),
          if (_aiOpen)
            AnimatedBuilder(
              animation: _slideAnim,
              builder: (_, __) => Positioned(
                top: 0, left: 0,
                right: MediaQuery.of(context).size.width * 0.75,
                bottom: 0,
                child: GestureDetector(
                  onTap: _toggleAi,
                  child: Container(
                    color: Colors.black.withOpacity(0.3 * _slideAnim.value),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMain(User? user) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: user == null
                ? _buildNotLoggedIn()
                : _loadingIngredients
                    ? Center(child: CircularProgressIndicator(color: kGreenMid))
                    : _recipes.isNotEmpty
                        ? _buildRecipeList()
                        : _buildIngredientPicker(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: c.card,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          if (_recipes.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() { _recipes = []; _selected.clear(); }),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                width: 36, height: 36,
                decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadius8),
                child: Icon(Icons.arrow_back_rounded, color: kGreenMid, size: 18),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _recipes.isNotEmpty ? 'Recepti za tebe' : 'Recepti',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.textDark, letterSpacing: -0.5),
                ),
                if (_recipes.isNotEmpty)
                  Text(_selected.join(' · '),
                      style: TextStyle(fontSize: 11, color: kGreenMid, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis)
                else
                  Text('Izberi sestavine in generiraj recept z AI',
                      style: TextStyle(fontSize: 12, color: c.textLight)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _toggleAi,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _aiOpen ? kGreenMid : kGreenPale,
                shape: BoxShape.circle,
                boxShadow: _aiOpen
                    ? [BoxShadow(color: kGreenMid.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Center(child: Text('✨', style: TextStyle(fontSize: _aiOpen ? 18 : 16))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
            child: Icon(Icons.lock_outline_rounded, size: 36, color: kGreenMid),
          ),
          SizedBox(height: 16),
          Text('Niste prijavljeni', style: kHeading2),
          SizedBox(height: 8),
          Text('Prijavite se za dostop do receptov.',
              style: TextStyle(color: c.textLight, fontSize: 14), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildIngredientPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kGreenPale, borderRadius: kRadius12,
            border: Border.all(color: kGreenMid.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Text('👇', style: TextStyle(fontSize: 24)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kako deluje', style: TextStyle(fontWeight: FontWeight.w800, color: c.textDark, fontSize: 13)),
                    SizedBox(height: 2),
                    Text('Izberi sestavine, ki jih imaš. AI bo ustvaril recepte posebej zate.',
                        style: TextStyle(color: c.textMid, fontSize: 12, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Text('Tvoje sestavine', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: c.textDark)),
              const Spacer(),
              if (_selected.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _selected.clear()),
                  child: Text('Počisti', style: TextStyle(fontSize: 12, color: kGreenMid, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        if (_ingredients.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.card, borderRadius: kRadius12, boxShadow: kCardShadow),
              child: Text('Nimaš še nobene rezervacije. Rezerviraj oglas na domači strani.',
                  style: TextStyle(color: c.textLight, fontSize: 13, height: 1.5)),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: _ingredients.map((ing) {
                  final sel = _selected.contains(ing);
                  return GestureDetector(
                    onTap: () => setState(() { if (sel) _selected.remove(ing); else _selected.add(ing); }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? kGreenMid : c.card,
                        borderRadius: kRadiusFull,
                        border: Border.all(color: sel ? kGreenMid : kGreenMid.withOpacity(0.25), width: sel ? 0 : 1),
                        boxShadow: sel
                            ? [BoxShadow(color: kGreenMid.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                            : kCardShadow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (sel) ...[Icon(Icons.check_rounded, size: 13, color: c.card), SizedBox(width: 5)],
                          Text(ing, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : kGreenMid)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        // ── Gumbi za generiranje ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Row(
            children: [
              GestureDetector(
                onTap: _generatingFromImage ? null : _pickAndGenerateFromImage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _generatingFromImage ? kGreenMid.withOpacity(0.5) : c.cardAlt,
                    borderRadius: kRadius12,
                    border: Border.all(color: kGreenMid.withOpacity(0.3)),
                  ),
                  child: _generatingFromImage
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: kGreenMid, strokeWidth: 2.5))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.camera_alt_rounded, color: kGreenMid, size: 20),
                          const SizedBox(width: 6),
                          Text('Foto', style: TextStyle(color: kGreenMid, fontWeight: FontWeight.w700, fontSize: 14)),
                        ]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _selected.isEmpty || _loadingRecipes ? null : _generateRecipes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreenMid,
                      disabledBackgroundColor: kGreenMid.withOpacity(0.35),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: kRadius12),
                    ),
                    child: _loadingRecipes && !_generatingFromImage
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: c.card, strokeWidth: 2.5))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('✨', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(
                                _selected.isEmpty ? 'Izberi sestavine' : 'Generiraj (${_selected.length})',
                                style: TextStyle(color: c.card, fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_recipeError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(_recipeError!, style: TextStyle(color: Colors.red, fontSize: 13)),
          ),
      ],
    );
  }

  Widget _buildRecipeList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      itemCount: _recipes.length,
      itemBuilder: (_, i) => _RecipeCard(
        recipe: _recipes[i],
        onAskAi: (q) { if (!_aiOpen) _toggleAi(); _sendChat(q); },
      ),
    );
  }

  Widget _buildAiPanel() {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(-4, 0))],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              color: kGreenMid,
              child: Row(
                children: [
                  Text('✨', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Expanded(child: Text('AI pomočnik',
                      style: TextStyle(color: c.card, fontWeight: FontWeight.w800, fontSize: 15))),
                  GestureDetector(onTap: _toggleAi,
                      child: Icon(Icons.close_rounded, color: Colors.white70, size: 20)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _chatScroll,
                padding: const EdgeInsets.all(12),
                itemCount: _chatMsgs.length + (_aiThinking ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _chatMsgs.length && _aiThinking) {
                    return _ChatBubble(msg: _ChatMsg(text: '...', isAi: true), isTyping: true);
                  }
                  return _ChatBubble(msg: _chatMsgs[i]);
                },
              ),
            ),
            if (_recipes.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    for (final q in ['Kaj mogu z ostanki?', 'Kalorije?', 'Brez glutena?', 'Hitrejši recept?'])
                      GestureDetector(
                        onTap: () => _sendChat(q),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: kGreenPale, borderRadius: kRadiusFull,
                            border: Border.all(color: kGreenMid.withOpacity(0.3)),
                          ),
                          child: Text(q, style: TextStyle(fontSize: 11, color: kGreenMid, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border.withOpacity(0.4)))),
              child: Row(
                children: [
                  // Foto dugme u chatu
                  GestureDetector(
                    onTap: _sendChatWithImage,
                    child: Container(
                      width: 38, height: 38,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: c.cardAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: kGreenMid.withOpacity(0.3)),
                      ),
                      child: Icon(Icons.camera_alt_rounded, color: kGreenMid, size: 18),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _chatCtrl,
                      style: TextStyle(fontSize: 13, color: c.textDark),
                      decoration: InputDecoration(
                        hintText: 'Vprašaj karkoli...',
                        hintStyle: TextStyle(fontSize: 13, color: c.textLight),
                        filled: true, fillColor: c.cardAlt,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: kRadius24, borderSide: BorderSide.none),
                      ),
                      onSubmitted: _sendChat,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _sendChat(_chatCtrl.text),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: kGreenMid, shape: BoxShape.circle),
                      child: Icon(Icons.send_rounded, color: c.card, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── RECEPT KARTICA ───────────────────────────────────────────────────────────

class _RecipeCard extends StatefulWidget {
  final _Recipe recipe;
  final void Function(String question) onAskAi;
  const _RecipeCard({required this.recipe, required this.onAskAi});

  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final r = widget.recipe;
    final diffColor = r.difficulty == 'lahka'
        ? const Color(0xFF2E7D32)
        : r.difficulty == 'srednja' ? const Color(0xFFE65100) : const Color(0xFFC62828);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: c.card, borderRadius: kRadius16, boxShadow: kCardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadius12),
                    child: Center(child: Text(r.emoji, style: TextStyle(fontSize: 26))),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: c.textDark)),
                        SizedBox(height: 5),
                        Row(children: [
                          _Tag(text: r.time, icon: Icons.access_time_rounded, color: c.textLight),
                          SizedBox(width: 8),
                          _Tag(text: r.difficulty, color: diffColor),
                        ]),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: c.textLight),
                ],
              ),
            ),
          ),
          if (!_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(r.description, style: TextStyle(fontSize: 13, color: c.textMid, height: 1.5),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(r.description, style: TextStyle(fontSize: 13, color: c.textMid, height: 1.5)),
            ),
            if (r.matchedIngredients.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  children: r.matchedIngredients.map((ing) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kGreenPale, borderRadius: kRadiusFull,
                      border: Border.all(color: kGreenMid.withOpacity(0.3)),
                    ),
                    child: Text(ing, style: TextStyle(fontSize: 11, color: kGreenMid, fontWeight: FontWeight.w700)),
                  )).toList(),
                ),
              ),
            if (r.steps.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Postopek', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: c.textDark)),
              ),
              for (int i = 0; i < r.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(color: kGreenMid, shape: BoxShape.circle),
                        child: Center(child: Text('${i + 1}',
                            style: TextStyle(color: c.card, fontSize: 11, fontWeight: FontWeight.w800))),
                      ),
                      SizedBox(width: 10),
                      Expanded(child: Text(r.steps[i], style: TextStyle(fontSize: 13, color: c.textMid, height: 1.5))),
                    ],
                  ),
                ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: GestureDetector(
                onTap: () => widget.onAskAi('Povej mi več o receptu "${r.name}"'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: kGreenPale, borderRadius: kRadius8,
                    border: Border.all(color: kGreenMid.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('✨', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text('Vprašaj AI za pomoč',
                          style: TextStyle(fontSize: 13, color: kGreenMid, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── CHAT BUBBLE ─────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final _ChatMsg msg;
  final bool isTyping;
  const _ChatBubble({required this.msg, this.isTyping = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isAi = msg.isAi;
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
        decoration: BoxDecoration(
          color: isAi ? kGreenPale : kGreenMid,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14), topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isAi ? 4 : 14),
            bottomRight: Radius.circular(isAi ? 14 : 4),
          ),
        ),
        child: isTyping
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: const _TypingIndicator(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (msg.imageFile != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      child: Image.file(
                        File(msg.imageFile!.path),
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Text(msg.text,
                        style: TextStyle(fontSize: 13, color: isAi ? c.textDark : Colors.white, height: 1.45)),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i * 0.33;
          final t = ((_c.value - delay) % 1.0).clamp(0.0, 1.0);
          final opacity = (0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2)).clamp(0.0, 1.0);
          return Container(
            width: 6, height: 6,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: kGreenMid.withOpacity(opacity), shape: BoxShape.circle),
          );
        }),
      ),
    );
  }
}

// ─── HELPER WIDGETI ──────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  const _Tag({required this.text, this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 11, color: color), SizedBox(width: 3)],
        Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── MODELI ───────────────────────────────────────────────────────────────────

class _Recipe {
  final String name, emoji, time, difficulty, description;
  final List<String> steps, matchedIngredients;

  const _Recipe({
    required this.name, required this.emoji, required this.time,
    required this.difficulty, required this.description,
    required this.steps, required this.matchedIngredients,
  });

  factory _Recipe.fromJson(Map<String, dynamic> j) => _Recipe(
    name: j['name'] as String? ?? 'Recept',
    emoji: j['emoji'] as String? ?? '🍽️',
    time: j['time'] as String? ?? '—',
    difficulty: j['difficulty'] as String? ?? 'lahka',
    description: j['description'] as String? ?? '',
    steps: List<String>.from(j['steps'] as List? ?? []),
    matchedIngredients: List<String>.from(j['matchedIngredients'] as List? ?? []),
  );
}

class _ChatMsg {
  final String text;
  final bool isAi;
  final XFile? imageFile;
  _ChatMsg({required this.text, required this.isAi, this.imageFile});
}