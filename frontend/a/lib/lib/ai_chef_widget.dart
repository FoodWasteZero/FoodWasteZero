import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';

// ── Floating AI Chef button ───────────────────────────────────────────────────
class AiChefFab extends StatelessWidget {
  const AiChefFab({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAiChefPanel(context),
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
          ),
          borderRadius: kRadiusFull,
          boxShadow: [
            BoxShadow(
              color: kGreenMid.withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('👨‍🍳', style: TextStyle(fontSize: 22)),
            Text('AI Chef',
                style: TextStyle(
                    color: Colors.white, fontSize: 8,
                    fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }

  void _showAiChefPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AiChefPanel(),
    );
  }
}

// ── AI Chef bottom sheet panel ────────────────────────────────────────────────
class _AiChefPanel extends StatefulWidget {
  const _AiChefPanel();

  @override
  State<_AiChefPanel> createState() => _AiChefPanelState();
}

class _AiChefPanelState extends State<_AiChefPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _selectedIngredients = <String>{};
  final _chatMessages = <_ChatMsg>[
    _ChatMsg(
      text: 'Zdravo! 👋 Sem vaš AI Chef. Izberite sestavine in vam bom pomagal ustvariti okusne obroke!',
      isAi: true,
    ),
  ];
  final _inputCtrl = TextEditingController();

  static const _allIngredients = [
    ('Jabolka', Icons.apple, Color(0xFFE8F5E9)),
    ('Paradižnik', Icons.grass, Color(0xFFFFEBEE)),
    ('Moka', Icons.bakery_dining, Color(0xFFF5F5F5)),
    ('Jajca', Icons.egg_alt, Color(0xFFFFF9C4)),
    ('Maslo', Icons.opacity, Color(0xFFFFFDE7)),
    ('Sladkor', Icons.cookie, Color(0xFFFCE4EC)),
    ('Čebula', Icons.circle, Color(0xFFFFF3E0)),
    ('Česen', Icons.spa, Color(0xFFF3E5F5)),
    ('Mleko', Icons.water_drop, Color(0xFFE3F2FD)),
    ('Sir', Icons.lunch_dining, Color(0xFFFFF8E1)),
    ('Piščanec', Icons.set_meal, Color(0xFFE8EAF6)),
    ('Riž', Icons.rice_bowl, Color(0xFFE0F2F1)),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _toggleIngredient(String name) {
    setState(() {
      if (_selectedIngredients.contains(name)) {
        _selectedIngredients.remove(name);
      } else {
        _selectedIngredients.add(name);
      }
    });
  }

  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _chatMessages.add(_ChatMsg(text: text, isAi: false));
      _inputCtrl.clear();
      // Mock AI reply
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _chatMessages.add(_ChatMsg(
              text: _generateAiReply(text, _selectedIngredients.toList()),
              isAi: true,
            ));
          });
        }
      });
    });
  }

  String _generateAiReply(String question, List<String> ingredients) {
    if (ingredients.isEmpty) {
      return 'Prosim, najprej izberite sestavine na zavihku "Sestavine", da vam lahko predlagam recepte! 🥘';
    }
    final list = ingredients.join(', ');
    return 'Z ${ingredients.length} sestavinami ($list) vam predlagam: okusno enolončnico ali jušno osnovo. Potrebujete podroben recept? 👨‍🍳';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildIngredientTab(),
                _buildChatTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        width: 36, height: 4,
        decoration: BoxDecoration(
          color: kBorder, borderRadius: kRadiusFull,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kGreenMid, kGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: kRadius12,
            ),
            child: const Center(
              child: Text('👨‍🍳', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Chef', style: kHeading2),
              Text('Pametni pomočnik za recepte',
                  style: TextStyle(fontSize: 12, color: kTextLight)),
            ],
          ),
          const Spacer(),
          if (_selectedIngredients.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: kGreenPale, borderRadius: kRadiusFull,
              ),
              child: Text('${_selectedIngredients.length} izbrano',
                  style: const TextStyle(
                      color: kGreenMid, fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: kSurface, borderRadius: kRadius12,
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          color: kGreenMid, borderRadius: kRadius12,
          boxShadow: kElevatedShadow,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: kTextMid,
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '🥦  Sestavine'),
          Tab(text: '💬  AI Chef Chat'),
        ],
      ),
    );
  }

  Widget _buildIngredientTab() {
    return Column(
      children: [
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text('Izberite sestavine', style: kBodyBold),
              const Spacer(),
              if (_selectedIngredients.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(_selectedIngredients.clear),
                  child: const Text('Počisti',
                      style: TextStyle(
                          fontSize: 12, color: kGreenMid,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemCount: _allIngredients.length,
            itemBuilder: (_, i) {
              final (name, icon, color) = _allIngredients[i];
              final selected = _selectedIngredients.contains(name);
              return GestureDetector(
                onTap: () => _toggleIngredient(name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: selected ? kGreenMid : color,
                    borderRadius: kRadius12,
                    border: Border.all(
                      color: selected ? kGreenMid : kBorder,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected ? kElevatedShadow : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon,
                          color: selected
                              ? Colors.white
                              : kGreenMid,
                          size: 28),
                      const SizedBox(height: 6),
                      Text(name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : kTextDark,
                          ),
                          textAlign: TextAlign.center),
                      if (selected)
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(Icons.check_circle,
                              color: Colors.white, size: 14),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_selectedIngredients.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: ElevatedButton.icon(
              onPressed: () {
                _tabCtrl.animateTo(1);
                setState(() {
                  _chatMessages.add(_ChatMsg(
                    text: 'Imam: ${_selectedIngredients.join(", ")}. Kaj mi predlagaš?',
                    isAi: false,
                  ));
                  Future.delayed(const Duration(milliseconds: 700), () {
                    if (mounted) {
                      setState(() {
                        _chatMessages.add(_ChatMsg(
                          text: 'Odlično! Z ${_selectedIngredients.join(", ")} lahko naredite več jedi. Predlagam začeti z enostavno enolončnico ali morda slastno frittato. Želite podroben recept? 👨‍🍳✨',
                          isAi: true,
                        ));
                      });
                    }
                  });
                });
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: Text(
                  'Vprašaj AI Chefa (${_selectedIngredients.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreenMid,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: const RoundedRectangleBorder(
                    borderRadius: kRadius12),
                elevation: 0,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            itemCount: _chatMessages.length,
            itemBuilder: (_, i) => _ChatBubble(msg: _chatMessages[i]),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: kBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: kRadius24,
                    border: Border.all(color: kBorder),
                  ),
                  child: TextField(
                    controller: _inputCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Vprašajte AI Chefa...',
                      hintStyle: TextStyle(color: kTextLight, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: kGreenMid,
                    borderRadius: kRadiusFull,
                    boxShadow: kElevatedShadow,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatMsg {
  final String text;
  final bool isAi;
  _ChatMsg({required this.text, required this.isAi});
}

class _ChatBubble extends StatelessWidget {
  final _ChatMsg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isAi ? kGreenPale : kGreenMid,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isAi ? 4 : 16),
            bottomRight: Radius.circular(msg.isAi ? 16 : 4),
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            fontSize: 13,
            color: msg.isAi ? kTextDark : Colors.white,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
