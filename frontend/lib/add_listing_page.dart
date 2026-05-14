import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';

// ── Add Listing Page ──────────────────────────────────────────────────────────
class AddListingPage extends StatefulWidget {
  const AddListingPage({super.key});

  @override
  State<AddListingPage> createState() => _AddListingPageState();
}

class _AddListingPageState extends State<AddListingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _IngredientForm(),
                  _PreparedMealForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: kRadius12,
                boxShadow: kCardShadow,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: kTextMid, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Novo', style: TextStyle(fontSize: 11, color: kTextLight)),
              Text('Dodaj oglas', style: kHeading2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: kRadius12,
          border: Border.all(color: kBorder),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kGreenMid, kGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: kRadius8,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(4),
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: kTextLight,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: '🥕  Sestavina'),
            Tab(text: '🍲  Pripravljena jed'),
          ],
        ),
      ),
    );
  }
}

// ── Ingredient Form ───────────────────────────────────────────────────────────
class _IngredientForm extends StatefulWidget {
  const _IngredientForm();

  @override
  State<_IngredientForm> createState() => _IngredientFormState();
}

class _IngredientFormState extends State<_IngredientForm> {
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = 'Zelenjava';

  // Default: 3 dni, uporabnik lahko zmanjša
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 3));

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  static const _categories = [
    '🥦 Zelenjava',
    '🍎 Sadje',
    '🥛 Mlečni izdelki',
    '🥩 Meso',
    '🐟 Ribe',
    '🌾 Žita & moka',
    '🫙 Konzerve',
    '🧂 Začimbe',
    '🍳 Drugo',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageUpload(kGreenMid, kGreenPale),
            const SizedBox(height: 20),

            _buildSectionLabel('Osnovni podatki'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titleCtrl,
              label: 'Ime sestavine',
              hint: 'npr. Paradižniki iz vrta',
              icon: Icons.eco_outlined,
              accentColor: kGreenMid,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Vnesite ime' : null,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _descCtrl,
              label: 'Opis',
              hint: 'Kratka opisanje, stanje...',
              icon: Icons.notes_rounded,
              accentColor: kGreenMid,
              maxLines: 3,
            ),

            const SizedBox(height: 20),
            _buildSectionLabel('Kategorija'),
            const SizedBox(height: 8),
            _buildCategoryPicker(),

            const SizedBox(height: 20),
            _buildSectionLabel('Količina'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _qtyCtrl,
              label: 'Količina',
              hint: 'npr. 500g / 3 kosi',
              icon: Icons.scale_outlined,
              accentColor: kGreenMid,
            ),

            const SizedBox(height: 20),
            _buildSectionLabel('Rok uporabe'),
            const SizedBox(height: 4),
            _buildInfoBanner(
              'Privzeto 3 dni — zmanjšajte po potrebi.',
              kGreenMid,
              kGreenPale,
            ),
            const SizedBox(height: 8),
            _buildExpiryPicker(
              context: context,
              currentDate: _expiryDate,
              maxDays: 365,
              accentColor: kGreenMid,
              bgColor: kGreenPale,
              onChanged: (d) => setState(() => _expiryDate = d),
            ),
            const SizedBox(height: 6),
            _buildExpiryChips(
              current: _expiryDate,
              accentColor: kGreenMid,
              options: const [
                {'label': '1 dan', 'days': 1},
                {'label': '2 dni', 'days': 2},
                {'label': '3 dni', 'days': 3},
              ],
              onSelect: (d) => setState(() => _expiryDate = d),
            ),

            const SizedBox(height: 28),
            _buildSubmitButton(
              context: context,
              label: 'Objavi sestavino',
              icon: Icons.eco,
              color: kGreenMid,
              snackMsg: 'Sestavina uspešno objavljena! 🥕',
              formKey: _formKey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final label = cat.substring(3);
        final isSelected = _selectedCategory == label;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? kGreenMid : Colors.white,
              borderRadius: kRadiusFull,
              border: Border.all(color: isSelected ? kGreenMid : kBorder),
              boxShadow: isSelected ? kElevatedShadow : kCardShadow,
            ),
            child: Text(
              cat,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : kTextMid,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Prepared Meal Form ────────────────────────────────────────────────────────
class _PreparedMealForm extends StatefulWidget {
  const _PreparedMealForm();

  @override
  State<_PreparedMealForm> createState() => _PreparedMealFormState();
}

class _PreparedMealFormState extends State<_PreparedMealForm> {
  final _formKey = GlobalKey<FormState>();

  // 🧊 hladilnik ali 🍽️ ne
  bool _inFridge = true;

  // Hladilnik: datum (max 3 dni). Brez: ure (max 2).
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 3));
  int _hoursLimit = 2;

  bool _isVegan = false;
  bool _isVegetarian = false;
  bool _isGlutenFree = false;
  int _portions = 1;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _allergensCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _allergensCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageUpload(kOrange, kOrangePale),
            const SizedBox(height: 20),

            _buildSectionLabel('Podatki o jedi'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titleCtrl,
              label: 'Ime jedi',
              hint: 'npr. Domača juha z rezanci',
              icon: Icons.restaurant_outlined,
              accentColor: kOrange,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Vnesite ime' : null,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _descCtrl,
              label: 'Opis',
              hint: 'Sestavine, način priprave...',
              icon: Icons.notes_rounded,
              accentColor: kOrange,
              maxLines: 3,
            ),

            const SizedBox(height: 20),
            _buildSectionLabel('Posebnosti'),
            const SizedBox(height: 8),
            _buildDietaryOptions(),

            const SizedBox(height: 20),
            _buildSectionLabel('Alergeni'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _allergensCtrl,
              label: 'Alergeni',
              hint: 'npr. gluten, laktoza, oreščki...',
              icon: Icons.warning_amber_outlined,
              accentColor: kOrange,
            ),

            const SizedBox(height: 20),
            _buildSectionLabel('Število porcij'),
            const SizedBox(height: 8),
            _buildPortionSelector(),

            const SizedBox(height: 20),
            _buildSectionLabel('Shranjevanje'),
            const SizedBox(height: 8),
            _buildFridgeSelector(),

            const SizedBox(height: 16),
            _buildSectionLabel(
                _inFridge ? 'Rok v hladilniku' : 'Rok prevzema'),
            const SizedBox(height: 4),
            _buildInfoBanner(
              _inFridge
                  ? 'Privzeto 3 dni — zmanjšajte/povečajte po potrebi.'
                  : 'Privzeto 2 uri — zmanjšajte/povečajte po potrebi.',
              _inFridge ? kGreenMid : kOrange,
              _inFridge ? kGreenPale : kOrangePale,
            ),
            const SizedBox(height: 8),

            if (_inFridge) ...[
              _buildExpiryPicker(
                context: context,
                currentDate: _expiryDate,
                maxDays: 365,
                accentColor: kGreenMid,
                bgColor: kGreenPale,
                onChanged: (d) => setState(() => _expiryDate = d),
              ),
              const SizedBox(height: 6),
              _buildExpiryChips(
                current: _expiryDate,
                accentColor: kGreenMid,
                options: const [
                  {'label': '1 dan', 'days': 1},
                  {'label': '2 dni', 'days': 2},
                  {'label': '3 dni', 'days': 3},
                ],
                onSelect: (d) => setState(() => _expiryDate = d),
              ),
            ] else ...[
              _buildHoursPicker(),
            ],

            const SizedBox(height: 28),
            _buildSubmitButton(
              context: context,
              label: 'Objavi jed',
              icon: Icons.restaurant,
              color: kOrange,
              snackMsg: 'Jed uspešno objavljena! 🍲',
              formKey: _formKey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFridgeSelector() {
    return Row(
      children: [
        Expanded(child: _buildFridgeOption(true)),
        const SizedBox(width: 10),
        Expanded(child: _buildFridgeOption(false)),
      ],
    );
  }

  Widget _buildFridgeOption(bool isFridgeOption) {
    final selected = _inFridge == isFridgeOption;
    final color = isFridgeOption ? kGreenMid : kOrange;
    final bg = isFridgeOption ? kGreenPale : kOrangePale;

    return GestureDetector(
      onTap: () => setState(() {
        _inFridge = isFridgeOption;
        if (isFridgeOption) {
          _expiryDate = DateTime.now().add(const Duration(days: 3));
        } else {
          _hoursLimit = 2;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? bg : Colors.white,
          borderRadius: kRadius12,
          border: Border.all(
            color: selected ? color : kBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              isFridgeOption ? '🧊' : '🍽️',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 6),
            Text(
              isFridgeOption ? 'V hladilniku' : 'Ni v hladilniku',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? color : kTextMid,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isFridgeOption ? 'do 3 dni' : 'do 2 uri',
              style: TextStyle(
                fontSize: 11,
                color: selected ? color : kTextLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoursPicker() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius12,
        border: Border.all(color: kOrange, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_rounded, color: kOrange, size: 18),
              const SizedBox(width: 8),
              Text(
                'Prevzem v $_hoursLimit ${_hoursLimit == 1 ? 'uri' : 'urah'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kOrange,
              inactiveTrackColor: kOrangePale,
              thumbColor: kOrange,
              overlayColor: kOrange.withOpacity(0.15),
              valueIndicatorColor: kOrange,
              showValueIndicator: ShowValueIndicator.always,
            ),
            child: Slider(
              value: _hoursLimit.toDouble(),
              min: 1,
              max: 2,
              divisions: 1,
              label: '$_hoursLimit ${_hoursLimit == 1 ? 'ura' : 'uri'}',
              onChanged: (v) => setState(() => _hoursLimit = v.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('1 ura',
                  style: TextStyle(fontSize: 11, color: kTextLight)),
              Text('2 uri',
                  style: TextStyle(fontSize: 11, color: kTextLight)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryOptions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _DietChip(
          label: '🌱 Vegansk',
          selected: _isVegan,
          accentColor: kOrange,
          bgColor: kOrangePale,
          onTap: () => setState(() => _isVegan = !_isVegan),
        ),
        _DietChip(
          label: '🥗 Vegetarijansko',
          selected: _isVegetarian,
          accentColor: kOrange,
          bgColor: kOrangePale,
          onTap: () => setState(() => _isVegetarian = !_isVegetarian),
        ),
        _DietChip(
          label: '🌾 Brez glutena',
          selected: _isGlutenFree,
          accentColor: kOrange,
          bgColor: kOrangePale,
          onTap: () => setState(() => _isGlutenFree = !_isGlutenFree),
        ),
      ],
    );
  }

  Widget _buildPortionSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius12,
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_outline, color: kTextMid, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Število porcij',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTextDark),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (_portions > 1) setState(() => _portions--);
            },
            child: Container(
              width: 32,
              height: 32,
              decoration:
                  BoxDecoration(color: kOrangePale, borderRadius: kRadiusFull),
              child: const Icon(Icons.remove, color: kOrange, size: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '$_portions',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kTextDark),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _portions++),
            child: Container(
              width: 32,
              height: 32,
              decoration:
                  BoxDecoration(color: kOrange, borderRadius: kRadiusFull),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers (top-level functions) ─────────────────────────────────────

Widget _buildImageUpload(Color accent, Color bg) {
  return GestureDetector(
    onTap: () {},
    child: Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius16,
        border: Border.all(color: kBorder, width: 1.5),
        boxShadow: kCardShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: bg, borderRadius: kRadiusFull),
            child: Icon(Icons.add_photo_alternate_outlined,
                color: accent, size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            'Dodaj fotografijo',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: accent),
          ),
          const SizedBox(height: 2),
          const Text('Tapnite za nalaganje',
              style: TextStyle(fontSize: 12, color: kTextLight)),
        ],
      ),
    ),
  );
}

Widget _buildSectionLabel(String text) {
  return Text(
    text,
    style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: kTextMid,
        letterSpacing: 0.3),
  );
}

Widget _buildInfoBanner(String text, Color color, Color bg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: bg, borderRadius: kRadius8),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12, color: color)),
        ),
      ],
    ),
  );
}

Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  required Color accentColor,
  int maxLines = 1,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    validator: validator,
    style: const TextStyle(fontSize: 14, color: kTextDark),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 13, color: kTextLight),
      hintStyle: const TextStyle(fontSize: 13, color: kTextLight),
      prefixIcon: Icon(icon, color: accentColor, size: 18),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: kRadius12,
          borderSide: const BorderSide(color: kBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: kRadius12,
          borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: kRadius12,
          borderSide: BorderSide(color: accentColor, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: kRadius12,
          borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: kRadius12,
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    ),
  );
}

Widget _buildExpiryPicker({
  required BuildContext context,
  required DateTime currentDate,
  required int maxDays,
  required Color accentColor,
  required Color bgColor,
  required void Function(DateTime) onChanged,
}) {
  final label =
      '${currentDate.day}. ${currentDate.month}. ${currentDate.year}';

  return GestureDetector(
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: currentDate,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(Duration(days: maxDays)),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: accentColor),
          ),
          child: child!,
        ),
      );
      if (picked != null) onChanged(picked);
    },
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kRadius12,
        border: Border.all(color: accentColor, width: 1.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.calendar_today_outlined, color: accentColor, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextDark),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(right: 12),
            decoration:
                BoxDecoration(color: bgColor, borderRadius: kRadiusFull),
            child: Text(
              'Spremenite',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accentColor),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildExpiryChips({
  required DateTime current,
  required Color accentColor,
  required List<Map<String, dynamic>> options,
  required void Function(DateTime) onSelect,
}) {
  return Row(
    children: options.map((opt) {
      final days = opt['days'] as int;
      final label = opt['label'] as String;
      final target = DateTime.now().add(Duration(days: days));
      final isSelected = current.day == target.day &&
          current.month == target.month &&
          current.year == target.year;

      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => onSelect(target),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? accentColor : Colors.white,
              borderRadius: kRadiusFull,
              border: Border.all(
                  color: isSelected ? accentColor : kBorder),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : kTextMid,
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

Widget _buildSubmitButton({
  required BuildContext context,
  required String label,
  required IconData icon,
  required Color color,
  required String snackMsg,
  required GlobalKey<FormState> formKey,
}) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton.icon(
      onPressed: () {
        if (formKey.currentState?.validate() ?? false) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(snackMsg),
              backgroundColor: color,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: kRadius12),
            ),
          );
        }
      },
      icon: Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: kRadius12),
      ),
    ),
  );
}

// ── Diet Chip ─────────────────────────────────────────────────────────────────
class _DietChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final Color bgColor;
  final VoidCallback onTap;

  const _DietChip({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? bgColor : Colors.white,
          borderRadius: kRadiusFull,
          border: Border.all(
              color: selected ? accentColor : kBorder,
              width: selected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? accentColor : kTextMid,
          ),
        ),
      ),
    );
  }
}