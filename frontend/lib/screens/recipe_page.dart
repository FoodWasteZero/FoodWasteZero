import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../common/theme.dart';

// ─── ENTRY POINT ─────────────────────────────────────────────────────────────

class RecipePage extends StatefulWidget {
  const RecipePage({super.key});

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage>
    with SingleTickerProviderStateMixin {
  // Izbrani sestavini
  final Set<String> _selected = {};

  // Generiran seznam receptov
  List<_Recipe> _recipes = [];
  bool _loadingRecipes = false;
  String? _recipeError;

  // AI chat panel
  bool _aiOpen = false;
  late AnimationController _slideCtrl;
  late Animation<double> _slideAnim;

  final List<_ChatMsg> _chatMsgs = [];
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  bool _aiThinking = false;

  // Sestavine iz Firestore
  Set<String> _ingredients = {};
  bool _loadingIngredients = true;

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
      final snap = await FirebaseFirestore.instance
          .collection('oglasi')
          .where('reservedByUid', isEqualTo: user.uid)
          .get();

      final result = <String>{};
      for (final doc in snap.docs) {
        final d = doc.data();
        final status = d['status'] as String? ?? '';
        if (status != 'rezervirano' && status != 'prevzeto') {
          // Tudi delna rezervacija (naRazpolago z nastavljenim reservedByUid) velja
          if (status == 'naRazpolago') {
            final reservedBy = d['reservedByUid'] as String? ?? '';
            if (reservedBy.isEmpty) continue;
          } else {
            continue;
          }
        }
        final title = d['title'] as String? ?? '';
        final category = d['category'] as String? ?? '';
        // Vse kategorije — ne samo sestavine
        final parts = title.split(RegExp(r'[,;|/\n]'));
        for (final p in parts) {
          final t = p.trim();
          if (t.length > 2 && t.length < 60) result.add(t);
        }
        // Dodaj tudi kategorijo kot tag
        if (category.isNotEmpty) result.add(category);
      }
      if (mounted) setState(() {
        _ingredients = result;
        _loadingIngredients = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingIngredients = false);
    }
  }

  // ── AI: generiraj recepte ───────────────────────────────────────────────────

  Future<void> _generateRecipes() async {
    if (_selected.isEmpty) return;
    setState(() {
      _loadingRecipes = true;
      _recipeError = null;
      _recipes = [];
    });

    try {
      final apiKey = dotenv.maybeGet('ANTHROPIC_API_KEY') ?? dotenv.maybeGet('OPENROUTER_API_KEY') ?? '';
      if (apiKey.isEmpty) throw Exception('Manjka ANTHROPIC_API_KEY v .env');

      final sestavine = _selected.join(', ');
      final prompt = 'Si kuhar. Generiraj 3 kratke recepte z sestavinami: ' + sestavine + '. '
          'Odgovori SAMO z veljavnim JSON nizom. Brez Markdown. Brez ```json. Samo čisti JSON: '
          '[{"name":"...","emoji":"...","time":"15 min","difficulty":"lahka",'
          '"description":"Kratek opis.","steps":["Korak 1.","Korak 2.","Korak 3."],'
          '"matchedIngredients":["..."]}] '
          'Vsak recept naj ima NAJVEČ 4 korake. Opisi naj bodo kratki.';

      final bool useAnthropic = (dotenv.maybeGet('ANTHROPIC_API_KEY') ?? '').isNotEmpty;

      final http.Response resp;
      if (useAnthropic) {
        resp = await http.post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'claude-haiku-4-5-20251001',
            'max_tokens': 1500,
            'messages': [{'role': 'user', 'content': prompt}],
          }),
        );
      } else {
        resp = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer ' + apiKey,
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://foodwastezero.app',
            'X-Title': 'FoodWasteZero',
          },
          body: jsonEncode({
            'model': 'google/gemini-2.0-flash-lite-001',
            'messages': [{'role': 'user', 'content': prompt}],
            'max_tokens': 2500,
          }),
        );
      }

      if (resp.statusCode != 200) {
        throw Exception('API napaka ' + resp.statusCode.toString() + ': ' + resp.body);
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final String text;
      if (useAnthropic) {
        text = (body['content'] as List).first['text'] as String? ?? '';
      } else {
        text = (body['choices'] as List).first['message']['content'] as String? ?? '';
      }

      // Počisti morebitne markdown fence bloke
      final cleaned = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final List<dynamic> jsonList = jsonDecode(cleaned);
      final recipes = jsonList.map((e) => _Recipe.fromJson(e as Map<String, dynamic>)).toList();

      if (mounted) setState(() {
        _recipes = recipes;
        _loadingRecipes = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _recipeError = 'Napaka: ' + e.toString();
        _loadingRecipes = false;
      });
    }
  }

  // ── AI chat ─────────────────────────────────────────────────────────────────

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
      final apiKey = dotenv.maybeGet('OPENROUTER_API_KEY') ?? '';
      if (apiKey.isEmpty) throw Exception('Manjka OPENROUTER_API_KEY');

      // Sestavi zgodovino sporočil
      final messages = <Map<String, String>>[
        {
          'role': 'system',
          'content': 'Si prijazni kuhar pomočnik v aplikaciji FoodWasteZero. '
              'Pomagaj z recepti, sestavinami in kuhanjem. '
              'Odgovori kratko (največ 3 stavke). Piši v slovenščini.',
        },
        ..._chatMsgs.map((m) => {
          'role': m.isAi ? 'assistant' : 'user',
          'content': m.text,
        }),
      ];

      final chatResp = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://foodwastezero.app',
          'X-Title': 'FoodWasteZero',
        },
        body: jsonEncode({
          'model': 'google/gemini-2.0-flash-lite-001',
          'messages': messages,
          'max_tokens': 400,
        }),
      );

      if (chatResp.statusCode != 200) throw Exception('OpenRouter error');
      final chatBody = jsonDecode(chatResp.body) as Map<String, dynamic>;
      final reply = (chatBody['choices'] as List).first['message']['content'] as String? ?? 'Oprostite, nisem razumel.';

      if (mounted) setState(() {
        _chatMsgs.add(_ChatMsg(text: reply, isAi: true));
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
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kSurface,
      body: Stack(
        children: [
          // ── Glavna vsebina (se premakne levo ko je AI odprt) ──────────────
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

          // ── AI panel (drsi z desne) ───────────────────────────────────────
          AnimatedBuilder(
            animation: _slideAnim,
            builder: (_, __) {
              final w = MediaQuery.of(context).size.width * 0.75;
              final right = w * (_slideAnim.value - 1);
              return Positioned(
                top: 0,
                bottom: 0,
                right: right,
                width: w,
                child: _buildAiPanel(),
              );
            },
          ),

          // ── Overlay ko je AI odprt (tap zapre) ───────────────────────────
          if (_aiOpen)
            AnimatedBuilder(
              animation: _slideAnim,
              builder: (_, __) => Positioned(
                top: 0,
                left: 0,
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
                    ? const Center(child: CircularProgressIndicator(color: kGreenMid))
                    : _recipes.isNotEmpty
                        ? _buildRecipeList()
                        : _buildIngredientPicker(),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Nazaj gumb če so recepti prikazani
          if (_recipes.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() { _recipes = []; _selected.clear(); }),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                width: 36, height: 36,
                decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadius8),
                child: const Icon(Icons.arrow_back_rounded, color: kGreenMid, size: 18),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _recipes.isNotEmpty ? 'Recepti za tebe' : 'Recepti',
                  style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: kTextDark, letterSpacing: -0.5,
                  ),
                ),
                if (_recipes.isNotEmpty)
                  Text(
                    _selected.join(' · '),
                    style: const TextStyle(fontSize: 11, color: kGreenMid, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  const Text(
                    'Izberi sestavine in generiraj recept z AI',
                    style: TextStyle(fontSize: 12, color: kTextLight),
                  ),
              ],
            ),
          ),
          // AI gumb
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
              child: Center(
                child: Text(
                  '✨',
                  style: TextStyle(fontSize: _aiOpen ? 18 : 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ni prijavljen ───────────────────────────────────────────────────────────

  Widget _buildNotLoggedIn() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(color: kGreenPale, shape: BoxShape.circle),
            child: const Icon(Icons.lock_outline_rounded, size: 36, color: kGreenMid),
          ),
          const SizedBox(height: 16),
          const Text('Niste prijavljeni', style: kHeading2),
          const SizedBox(height: 8),
          const Text(
            'Prijavite se za dostop do receptov.',
            style: TextStyle(color: kTextLight, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Izbira sestavin ─────────────────────────────────────────────────────────

  Widget _buildIngredientPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Navodilo
        Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kGreenPale,
            borderRadius: kRadius12,
            border: Border.all(color: kGreenMid.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Text('👇', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kako deluje',
                        style: TextStyle(fontWeight: FontWeight.w800, color: kTextDark, fontSize: 13)),
                    SizedBox(height: 2),
                    Text(
                      'Izberi sestavine, ki jih imaš. AI bo ustvaril recepte posebej zate.',
                      style: TextStyle(color: kTextMid, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Sestavine
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              const Text('Tvoje sestavine',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kTextDark)),
              const Spacer(),
              if (_selected.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _selected.clear()),
                  child: const Text('Počisti',
                      style: TextStyle(fontSize: 12, color: kGreenMid, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),

        if (_ingredients.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: kRadius12,
                boxShadow: kCardShadow,
              ),
              child: const Text(
                'Nimaš še nobene rezervacije. Rezerviraj oglas na domači strani.',
                style: TextStyle(color: kTextLight, fontSize: 13, height: 1.5),
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _ingredients.map((ing) {
                  final sel = _selected.contains(ing);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (sel) _selected.remove(ing);
                      else _selected.add(ing);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? kGreenMid : Colors.white,
                        borderRadius: kRadiusFull,
                        border: Border.all(
                          color: sel ? kGreenMid : kGreenMid.withOpacity(0.25),
                          width: sel ? 0 : 1,
                        ),
                        boxShadow: sel ? [
                          BoxShadow(color: kGreenMid.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))
                        ] : kCardShadow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (sel) ...[
                            const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            ing,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : kGreenMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

        // Generiraj gumb
        if (_ingredients.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _selected.isEmpty || _loadingRecipes ? null : _generateRecipes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreenMid,
                  disabledBackgroundColor: kGreenMid.withOpacity(0.35),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: kRadius12),
                ),
                child: _loadingRecipes
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            _selected.isEmpty
                                ? 'Izberi sestavine'
                                : 'Generiraj recepte (${_selected.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

        if (_recipeError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(_recipeError!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
      ],
    );
  }

  // ── Seznam receptov ─────────────────────────────────────────────────────────

  Widget _buildRecipeList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      itemCount: _recipes.length,
      itemBuilder: (_, i) => _RecipeCard(
        recipe: _recipes[i],
        onAskAi: (q) {
          if (!_aiOpen) _toggleAi();
          _sendChat(q);
        },
      ),
    );
  }

  // ── AI panel ─────────────────────────────────────────────────────────────────

  Widget _buildAiPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(-4, 0)),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: kGreenMid,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(0),
                  bottomRight: Radius.circular(0),
                ),
              ),
              child: Row(
                children: [
                  const Text('✨', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('AI pomočnik',
                        style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  GestureDetector(
                    onTap: _toggleAi,
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  ),
                ],
              ),
            ),

            // Sporočila
            Expanded(
              child: ListView.builder(
                controller: _chatScroll,
                padding: const EdgeInsets.all(12),
                itemCount: _chatMsgs.length + (_aiThinking ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _chatMsgs.length && _aiThinking) {
                    return _ChatBubble(
                      msg: _ChatMsg(text: '...', isAi: true),
                      isTyping: true,
                    );
                  }
                  return _ChatBubble(msg: _chatMsgs[i]);
                },
              ),
            ),

            // Hitre možnosti
            if (_recipes.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    for (final q in [
                      'Kaj mogu z ostanki?',
                      'Kalorije?',
                      'Brez glutena?',
                      'Hitrejši recept?',
                    ])
                      GestureDetector(
                        onTap: () => _sendChat(q),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: kGreenPale,
                            borderRadius: kRadiusFull,
                            border: Border.all(color: kGreenMid.withOpacity(0.3)),
                          ),
                          child: Text(q,
                              style: const TextStyle(
                                  fontSize: 11, color: kGreenMid, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ),

            // Input
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Vprašaj karkoli...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        filled: true,
                        fillColor: kSurface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: kRadius24,
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _sendChat,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _sendChat(_chatCtrl.text),
                    child: Container(
                      width: 38, height: 38,
                      decoration: const BoxDecoration(color: kGreenMid, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
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
    final r = widget.recipe;
    final diffColor = r.difficulty == 'lahka'
        ? const Color(0xFF2E7D32)
        : r.difficulty == 'srednja'
            ? const Color(0xFFE65100)
            : const Color(0xFFC62828);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius16,
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Glava kartice
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Emoji
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(color: kGreenPale, borderRadius: kRadius12),
                    child: Center(child: Text(r.emoji, style: const TextStyle(fontSize: 26))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15, color: kTextDark)),
                        const SizedBox(height: 5),
                        Row(children: [
                          _Tag(text: r.time, icon: Icons.access_time_rounded, color: kTextLight),
                          const SizedBox(width: 8),
                          _Tag(text: r.difficulty, color: diffColor),
                        ]),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: kTextLight,
                  ),
                ],
              ),
            ),
          ),

          // Opis
          if (!_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(r.description,
                  style: const TextStyle(fontSize: 13, color: kTextMid, height: 1.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),

          // Razširjena vsebina
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(r.description,
                  style: const TextStyle(fontSize: 13, color: kTextMid, height: 1.5)),
            ),

            // Sestavine ki se ujemajo
            if (r.matchedIngredients.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  children: r.matchedIngredients.map((ing) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kGreenPale,
                      borderRadius: kRadiusFull,
                      border: Border.all(color: kGreenMid.withOpacity(0.3)),
                    ),
                    child: Text(ing,
                        style: const TextStyle(fontSize: 11, color: kGreenMid, fontWeight: FontWeight.w700)),
                  )).toList(),
                ),
              ),

            // Koraki
            if (r.steps.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Postopek',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kTextDark)),
              ),
              for (int i = 0; i < r.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(color: kGreenMid, shape: BoxShape.circle),
                        child: Center(
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(r.steps[i],
                            style: const TextStyle(fontSize: 13, color: kTextMid, height: 1.5)),
                      ),
                    ],
                  ),
                ),
            ],

            // AI gumb
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: GestureDetector(
                onTap: () => widget.onAskAi('Povej mi več o receptu "${r.name}"'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: kGreenPale,
                    borderRadius: kRadius8,
                    border: Border.all(color: kGreenMid.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('✨', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text('Vprašaj AI za pomoč',
                          style: TextStyle(
                              fontSize: 13, color: kGreenMid, fontWeight: FontWeight.w700)),
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
    final isAi = msg.isAi;
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
        decoration: BoxDecoration(
          color: isAi ? kGreenPale : kGreenMid,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isAi ? 4 : 14),
            bottomRight: Radius.circular(isAi ? 14 : 4),
          ),
        ),
        child: isTyping
            ? const _TypingIndicator()
            : Text(
                msg.text,
                style: TextStyle(
                  fontSize: 13,
                  color: isAi ? kTextDark : Colors.white,
                  height: 1.45,
                ),
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

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
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
            decoration: BoxDecoration(
              color: kGreenMid.withOpacity(opacity),
              shape: BoxShape.circle,
            ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
        ],
        Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── MODELI ───────────────────────────────────────────────────────────────────

class _Recipe {
  final String name;
  final String emoji;
  final String time;
  final String difficulty;
  final String description;
  final List<String> steps;
  final List<String> matchedIngredients;

  const _Recipe({
    required this.name,
    required this.emoji,
    required this.time,
    required this.difficulty,
    required this.description,
    required this.steps,
    required this.matchedIngredients,
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
  _ChatMsg({required this.text, required this.isAi});
}