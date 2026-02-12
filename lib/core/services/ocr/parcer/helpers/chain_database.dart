// lib/core/services/ocr/parcer/helpers/chain_database.dart

class ChainInfo {
  final String name;
  final String category;
  final List<String> variations;
  final List<String> countries;
  final String? parentCompany;

  ChainInfo({
    required this.name,
    required this.category,
    required this.variations,
    required this.countries,
    this.parentCompany,
  });

  factory ChainInfo.fromJson(Map<String, dynamic> json) {
    return ChainInfo(
      name: json['name'],
      category: json['category'],
      variations: List<String>.from(json['variations']),
      countries: List<String>.from(json['countries']),
      parentCompany: json['parentCompany'],
    );
  }
}

class ChainDatabase {
  static Map<String, ChainInfo>? _chains;
  static final Map<String, String> _vendorCache = {};
  
  // International company name formats
  static const Map<String, String> _companyFormats = {
    // German
    'GMBH': 'GmbH',
    'AG': 'AG',
    'GMBH & CO KG': 'GmbH & Co. KG',
    'KG': 'KG',
    
    // English
    'LTD': 'Ltd.',
    'LIMITED': 'Limited',
    'LLC': 'LLC',
    'INC': 'Inc.',
    'CORP': 'Corp.',
    'CORPORATION': 'Corporation',
    'PLC': 'PLC',
    
    // French
    'SA': 'S.A.',
    'SAS': 'S.A.S.',
    'SARL': 'SARL',
    'EURL': 'EURL',
    
    // Spanish
    'SL': 'S.L.',
    'SRL': 'S.R.L.',
    
    // Italian
    'SPA': 'S.p.A.',
    'SNC': 'S.n.c.',
    
    // Dutch
    'BV': 'B.V.',
    'NV': 'N.V.',
    
    // Other European
    'AS': 'A/S', // Danish/Norwegian
    'AB': 'AB', // Swedish
    'OY': 'Oy', // Finnish
    'SRO': 's.r.o.', // Czech/Slovak
    'KFT': 'Kft.', // Hungarian
    'SP ZOO': 'Sp. z o.o.', // Polish
  };

  // Country-specific OCR character fixes
  static const Map<String, Map<String, String>> _countrySpecificOCRFixes = {
    'DE': {
      'ß': 'ss', // German eszett
      'ö': 'o', 'ä': 'a', 'ü': 'u',
      'Ö': 'O', 'Ä': 'A', 'Ü': 'U',
    },
    'FR': {
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'à': 'a', 'â': 'a', 'ä': 'a',
      'ç': 'c', 'ô': 'o', 'ö': 'o',
      'ù': 'u', 'û': 'u', 'ü': 'u',
      'î': 'i', 'ï': 'i',
      'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
      'À': 'A', 'Â': 'A', 'Ä': 'A',
      'Ç': 'C', 'Ô': 'O', 'Ö': 'O',
      'Ù': 'U', 'Û': 'U', 'Ü': 'U',
      'Î': 'I', 'Ï': 'I',
    },
    'ES': {
      'ñ': 'n', 'Ñ': 'N',
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
      'ü': 'u',
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U',
      'Ü': 'U',
    },
    'IT': {
      'à': 'a', 'è': 'e', 'é': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
      'À': 'A', 'È': 'E', 'É': 'E', 'Ì': 'I', 'Ò': 'O', 'Ù': 'U',
    },
    'NL': {
      'ë': 'e', 'ï': 'i', 'ö': 'o', 'ü': 'u',
      'Ë': 'E', 'Ï': 'I', 'Ö': 'O', 'Ü': 'U',
      'ij': 'y', 'IJ': 'Y', // Dutch digraph
    },
    'PL': {
      'ą': 'a', 'ć': 'c', 'ę': 'e', 'ł': 'l', 'ń': 'n',
      'ó': 'o', 'ś': 's', 'ź': 'z', 'ż': 'z',
      'Ą': 'A', 'Ć': 'C', 'Ę': 'E', 'Ł': 'L', 'Ń': 'N',
      'Ó': 'O', 'Ś': 'S', 'Ź': 'Z', 'Ż': 'Z',
    },
    'CZ': {
      'á': 'a', 'č': 'c', 'ď': 'd', 'é': 'e', 'ě': 'e',
      'í': 'i', 'ň': 'n', 'ó': 'o', 'ř': 'r', 'š': 's',
      'ť': 't', 'ú': 'u', 'ů': 'u', 'ý': 'y', 'ž': 'z',
      'Á': 'A', 'Č': 'C', 'Ď': 'D', 'É': 'E', 'Ě': 'E',
      'Í': 'I', 'Ň': 'N', 'Ó': 'O', 'Ř': 'R', 'Š': 'S',
      'Ť': 'T', 'Ú': 'U', 'Ů': 'U', 'Ý': 'Y', 'Ž': 'Z',
    },
  };

  // Enhanced OCR error patterns (common misreadings)
  static const Map<String, String> _commonOCRSubstitutions = {
    // Number/Letter confusion
    '0': 'O', 'O': '0', '1': 'I', 'I': '1', '5': 'S', 'S': '5',
    '6': 'G', 'G': '6', '8': 'B', 'B': '8', '9': 'g', 'g': '9',
    // Common letter confusion
    'rn': 'm', 'm': 'rn', 'vv': 'w', 'w': 'vv',
    'cl': 'd', 'd': 'cl', 'fi': 'h', 'h': 'fi',
    // Punctuation confusion
    '.': ',', ',': '.', ':': ';', ';': ':',
  };

  static Map<String, ChainInfo> get chains {
    _chains ??= _loadChains();
    return _chains!;
  }

  static Map<String, ChainInfo> _loadChains() {
    return {
      // GROCERY CHAINS
      'ALDI': ChainInfo(
        name: 'ALDI',
        category: 'Groceries',
        variations: ['ALDI ALCOY', 'ALDI SÜD', 'ALDI NORD', 'ALDI STORES'],
        countries: ['DE', 'US', 'UK', 'AU', 'ES', 'FR', 'IT', 'NL', 'BE'],
      ),
      'LIDL': ChainInfo(
        name: 'LIDL',
        category: 'Groceries',
        variations: ['LIDL STIFTUNG', 'LIDL STORES'],
        countries: ['DE', 'US', 'UK', 'FR', 'ES', 'IT', 'NL', 'BE', 'AT'],
      ),
      'TESCO': ChainInfo(
        name: 'TESCO',
        category: 'Groceries',
        variations: ['TESCO STORES', 'TESCO EXPRESS', 'TESCO EXTRA'],
        countries: ['UK', 'IE', 'CZ', 'HU', 'SK', 'PL'],
      ),
      'WALMART': ChainInfo(
        name: 'WALMART',
        category: 'Groceries',
        variations: ['WALMART SUPERMARKET', 'WALMART STORES', 'WALMART NEIGHBORHOOD MARKET'],
        countries: ['US', 'CA', 'MX', 'UK', 'DE', 'JP', 'IN'],
      ),
      'TARGET': ChainInfo(
        name: 'TARGET',
        category: 'Groceries',
        variations: ['TARGET STORES', 'TARGET CORPORATION', 'TARGET EXPRESS'],
        countries: ['US'],
      ),
      'COSTCO': ChainInfo(
        name: 'COSTCO',
        category: 'Groceries',
        variations: ['COSTCO WHOLESALE', 'COSTCO WHOLESALE CORPORATION'],
        countries: ['US', 'CA', 'MX', 'UK', 'JP', 'KR', 'TW', 'AU', 'ES', 'FR', 'IS'],
      ),
      'KROGER': ChainInfo(
        name: 'KROGER',
        category: 'Groceries',
        variations: ['KROGER COMPANY', 'KROGER STORES', 'RALPHS', 'FRED MEYER', 'SMITH\'S', 'KING SOOPERS'],
        countries: ['US'],
      ),
      'SAFEWAY': ChainInfo(
        name: 'SAFEWAY',
        category: 'Groceries',
        variations: ['SAFEWAY INC', 'SAFEWAY STORES'],
        countries: ['US'],
      ),
      'WHOLE FOODS': ChainInfo(
        name: 'WHOLE FOODS',
        category: 'Groceries',
        variations: ['WHOLE FOODS MARKET', 'WHOLE FOODS MARKET INC'],
        countries: ['US', 'UK', 'CA'],
      ),
      'TRADER JOE\'S': ChainInfo(
        name: 'TRADER JOE\'S',
        category: 'Groceries',
        variations: ['TRADER JOE\'S COMPANY', 'TRADER JOE\'S STORES'],
        countries: ['US'],
      ),
      'CARREFOUR': ChainInfo(
        name: 'CARREFOUR',
        category: 'Groceries',
        variations: ['CARREFOUR MARKET', 'CARREFOUR EXPRESS', 'CARREFOUR CITY'],
        countries: ['FR', 'ES', 'IT', 'BE', 'PL', 'BR', 'AR', 'CN'],
      ),
      'REWE': ChainInfo(
        name: 'REWE',
        category: 'Groceries',
        variations: ['REWE MARKT', 'REWE CITY', 'REWE TO GO'],
        countries: ['DE', 'AT', 'CZ', 'HU'],
      ),
      'EROSKI': ChainInfo(
        name: 'EROSKI',
        category: 'Groceries',
        variations: ['EROSKI ALCOY', 'EROSKI STORES'],
        countries: ['ES'],
      ),
      'AHOLD': ChainInfo(
        name: 'AHOLD',
        category: 'Groceries',
        variations: ['AHOLD DELHAIZE', 'ALBERT HEIJN', 'STOP & SHOP'],
        countries: ['NL', 'BE', 'US', 'CZ', 'RO'],
      ),
      'ASDA': ChainInfo(
        name: 'ASDA',
        category: 'Groceries',
        variations: ['ASDA STORES', 'ASDA STORES LTD', 'ASDA SUPERMARKET', 'ASDA WALMART'],
        countries: ['UK', 'GB'],
      ),
      'SAINSBURY': ChainInfo(
        name: 'SAINSBURY\'S',
        category: 'Groceries',
        variations: ['SAINSBURYS', 'SAINSBURY\'S LOCAL', 'SAINSBURY\'S CENTRAL'],
        countries: ['UK', 'GB'],
      ),
      'MORRISONS': ChainInfo(
        name: 'MORRISONS',
        category: 'Groceries',
        variations: ['MORRISONS SUPERMARKET', 'WM MORRISON'],
        countries: ['UK', 'GB'],
      ),
      'WAITROSE': ChainInfo(
        name: 'WAITROSE',
        category: 'Groceries',
        variations: ['WAITROSE & PARTNERS', 'WAITROSE SUPERMARKET'],
        countries: ['UK', 'GB'],
      ),

      // FOOD & DINING
      'MCDONALD': ChainInfo(
        name: 'MCDONALD\'S',
        category: 'Food & Dining',
        variations: ['MCDONALDS', 'MCDONALD\'S RESTAURANT', 'MCDONALD\'S CORP'],
        countries: ['GLOBAL'],
      ),
      'STARBUCKS': ChainInfo(
        name: 'STARBUCKS',
        category: 'Food & Dining',
        variations: ['STARBUCKS COFFEE', 'STARBUCKS STORES'],
        countries: ['GLOBAL'],
      ),
      'KFC': ChainInfo(
        name: 'KFC',
        category: 'Food & Dining',
        variations: ['KENTUCKY FRIED CHICKEN', 'KFC RESTAURANT'],
        countries: ['GLOBAL'],
      ),
      'SUBWAY': ChainInfo(
        name: 'SUBWAY',
        category: 'Food & Dining',
        variations: ['SUBWAY RESTAURANT', 'SUBWAY SANDWICHES'],
        countries: ['GLOBAL'],
      ),
      'BURGER KING': ChainInfo(
        name: 'BURGER KING',
        category: 'Food & Dining',
        variations: ['BURGER KING RESTAURANT', 'BK'],
        countries: ['GLOBAL'],
      ),

      // FURNITURE & HOME
      'IKEA': ChainInfo(
        name: 'IKEA',
        category: 'Furniture & Home',
        variations: ['IKEA STORES', 'IKEA FURNITURE'],
        countries: ['GLOBAL'],
      ),
      'HOMEDEPOT': ChainInfo(
        name: 'HOME DEPOT',
        category: 'Furniture & Home',
        variations: ['THE HOME DEPOT', 'HOMEDEPOT'],
        countries: ['US', 'CA', 'MX'],
      ),
      'LOWES': ChainInfo(
        name: 'LOWE\'S',
        category: 'Furniture & Home',
        variations: ['LOWES', 'LOWE\'S HOME IMPROVEMENT'],
        countries: ['US', 'CA', 'MX'],
      ),

      // ELECTRONICS
      'BEST BUY': ChainInfo(
        name: 'BEST BUY',
        category: 'Electronics',
        variations: ['BESTBUY', 'BEST BUY STORES'],
        countries: ['US', 'CA', 'MX'],
      ),
      'MEDIA MARKT': ChainInfo(
        name: 'MEDIA MARKT',
        category: 'Electronics',
        variations: ['MEDIAMARKT', 'MEDIA MARKT SATURN'],
        countries: ['DE', 'AT', 'CH', 'ES', 'IT', 'NL', 'BE', 'PL'],
      ),
      'SATURN': ChainInfo(
        name: 'SATURN',
        category: 'Electronics',
        variations: ['SATURN STORES'],
        countries: ['DE', 'AT', 'CH'],
      ),
      'AMAZON': ChainInfo(
        name: 'AMAZON',
        category: 'Electronics',
        variations: ['AMAZON.COM', 'AMAZON FRESH', 'AMAZON GO', 'AMAZON BOOKSTORE'],
        countries: ['US', 'CA', 'MX', 'UK', 'DE', 'FR', 'IT', 'ES', 'JP', 'IN', 'AU', 'BR'],
      ),
      'APPLE': ChainInfo(
        name: 'APPLE',
        category: 'Electronics',
        variations: ['APPLE STORE', 'APPLE INC', 'APPLE RETAIL'],
        countries: ['US', 'CA', 'MX', 'UK', 'DE', 'FR', 'IT', 'ES', 'JP', 'CN', 'AU', 'SG', 'HK'],
      ),
      'MICROSOFT': ChainInfo(
        name: 'MICROSOFT',
        category: 'Electronics',
        variations: ['MICROSOFT STORE', 'MICROSOFT CORPORATION'],
        countries: ['US', 'CA', 'UK', 'DE', 'FR', 'AU', 'SG'],
      ),
      'GOOGLE': ChainInfo(
        name: 'GOOGLE',
        category: 'Electronics',
        variations: ['GOOGLE STORE', 'GOOGLE LLC', 'GOOGLE PLAY'],
        countries: ['US', 'CA', 'UK', 'DE', 'FR', 'AU', 'JP'],
      ),

      // PHARMACY & HEALTH
      'CVS': ChainInfo(
        name: 'CVS',
        category: 'Pharmacy & Health',
        variations: ['CVS PHARMACY', 'CVS HEALTH'],
        countries: ['US'],
      ),
      'WALGREENS': ChainInfo(
        name: 'WALGREENS',
        category: 'Pharmacy & Health',
        variations: ['WALGREEN', 'WALGREENS PHARMACY'],
        countries: ['US'],
      ),
      'BOOTS': ChainInfo(
        name: 'BOOTS',
        category: 'Pharmacy & Health',
        variations: ['BOOTS PHARMACY', 'BOOTS UK'],
        countries: ['UK', 'IE'],
      ),
      'ROSSMANN': ChainInfo(
        name: 'ROSSMANN',
        category: 'Pharmacy & Health',
        variations: ['ROSSMANN DROGERIE', 'ROSSMANN DROGERIEMARKT', 'MEIN DROGERIEMARKT'],
        countries: ['DE', 'AT', 'CH', 'PL', 'HU', 'CZ', 'SK'],
      ),

      // FASHION & CLOTHING
      'H&M': ChainInfo(
        name: 'H&M',
        category: 'Fashion & Clothing',
        variations: ['H&M STORES', 'HENNES & MAURITZ'],
        countries: ['GLOBAL'],
      ),
      'ZARA': ChainInfo(
        name: 'ZARA',
        category: 'Fashion & Clothing',
        variations: ['ZARA STORES', 'INDITEX'],
        countries: ['GLOBAL'],
      ),
      'UNIQLO': ChainInfo(
        name: 'UNIQLO',
        category: 'Fashion & Clothing',
        variations: ['UNIQLO STORES'],
        countries: ['GLOBAL'],
      ),
      'NIKE': ChainInfo(
        name: 'NIKE',
        category: 'Fashion & Clothing',
        variations: ['NIKE STORE', 'NIKE INC', 'NIKE TOWN'],
        countries: ['GLOBAL'],
      ),
      'ADIDAS': ChainInfo(
        name: 'ADIDAS',
        category: 'Fashion & Clothing',
        variations: ['ADIDAS STORE', 'ADIDAS AG', 'ADIDAS ORIGINALS'],
        countries: ['GLOBAL'],
      ),
      'GAP': ChainInfo(
        name: 'GAP',
        category: 'Fashion & Clothing',
        variations: ['GAP INC', 'GAP STORES', 'GAP KIDS', 'BANANA REPUBLIC', 'OLD NAVY'],
        countries: ['GLOBAL'],
      ),
      'FOREVER 21': ChainInfo(
        name: 'FOREVER 21',
        category: 'Fashion & Clothing',
        variations: ['FOREVER 21 INC', 'FOREVER XXI'],
        countries: ['GLOBAL'],
      ),
      'PRIMARK': ChainInfo(
        name: 'PRIMARK',
        category: 'Fashion & Clothing',
        variations: ['PRIMARK STORES', 'PENNEY\'S'],
        countries: ['GLOBAL'],
      ),

      // TRANSPORT & FUEL
      'SHELL': ChainInfo(
        name: 'SHELL',
        category: 'Transport & Fuel',
        variations: ['SHELL STATIONS', 'SHELL OIL'],
        countries: ['GLOBAL'],
      ),
      'BP': ChainInfo(
        name: 'BP',
        category: 'Transport & Fuel',
        variations: ['BP STATIONS', 'BRITISH PETROLEUM'],
        countries: ['GLOBAL'],
      ),
      'EXXON': ChainInfo(
        name: 'EXXON',
        category: 'Transport & Fuel',
        variations: ['EXXONMOBIL', 'EXXON STATIONS'],
        countries: ['US', 'CA'],
      ),

      // DEPARTMENT STORES
      'MACY\'S': ChainInfo(
        name: 'MACY\'S',
        category: 'Fashion & Clothing',
        variations: ['MACY\'S INC', 'MACY\'S STORES', 'BLOOMINGDALE\'S'],
        countries: ['US'],
      ),
      'NORDSTROM': ChainInfo(
        name: 'NORDSTROM',
        category: 'Fashion & Clothing',
        variations: ['NORDSTROM INC', 'NORDSTROM RACK'],
        countries: ['US', 'CA'],
      ),
      'KOHL\'S': ChainInfo(
        name: 'KOHL\'S',
        category: 'Fashion & Clothing',
        variations: ['KOHL\'S CORPORATION', 'KOHL\'S STORES'],
        countries: ['US'],
      ),
      'JCPENNEY': ChainInfo(
        name: 'JCPENNEY',
        category: 'Fashion & Clothing',
        variations: ['JCPENNEY', 'J.C. PENNEY', 'JCP'],
        countries: ['US'],
      ),
      'SEARS': ChainInfo(
        name: 'SEARS',
        category: 'Furniture & Home',
        variations: ['SEARS HOLDINGS', 'SEARS STORES', 'KMART'],
        countries: ['US'],
      ),

      // SPECIALTY RETAIL
      'BED BATH & BEYOND': ChainInfo(
        name: 'BED BATH & BEYOND',
        category: 'Furniture & Home',
        variations: ['BED BATH & BEYOND INC', 'BBB'],
        countries: ['US', 'CA', 'MX'],
      ),
      'CONTAINER STORE': ChainInfo(
        name: 'CONTAINER STORE',
        category: 'Furniture & Home',
        variations: ['CONTAINER STORE GROUP', 'CONTAINER STORE INC'],
        countries: ['US'],
      ),
      'WILLIAMS SONOMA': ChainInfo(
        name: 'WILLIAMS SONOMA',
        category: 'Furniture & Home',
        variations: ['WILLIAMS SONOMA INC', 'POTTERY BARN', 'WEST ELM'],
        countries: ['US', 'CA', 'AU', 'UK'],
      ),
      'TJ MAXX': ChainInfo(
        name: 'TJ MAXX',
        category: 'Fashion & Clothing',
        variations: ['TJ MAXX', 'MARSHALLS', 'HOME GOODS', 'TJX COMPANIES'],
        countries: ['US', 'CA', 'UK', 'DE', 'AU'],
      ),
      'ROSS': ChainInfo(
        name: 'ROSS',
        category: 'Fashion & Clothing',
        variations: ['ROSS STORES', 'ROSS DRESS FOR LESS'],
        countries: ['US'],
      ),
      'BURLINGTON': ChainInfo(
        name: 'BURLINGTON',
        category: 'Fashion & Clothing',
        variations: ['BURLINGTON STORES', 'BURLINGTON COAT FACTORY'],
        countries: ['US'],
      ),

      // AUTOMOTIVE
      'AUTOZONE': ChainInfo(
        name: 'AUTOZONE',
        category: 'Transport & Fuel',
        variations: ['AUTOZONE INC', 'AUTOZONE STORES'],
        countries: ['US', 'MX', 'BR'],
      ),
      'ADVANCE AUTO PARTS': ChainInfo(
        name: 'ADVANCE AUTO PARTS',
        category: 'Transport & Fuel',
        variations: ['ADVANCE AUTO PARTS INC', 'ADVANCE AUTO'],
        countries: ['US', 'CA'],
      ),
      'ORILEY': ChainInfo(
        name: 'ORILEY',
        category: 'Transport & Fuel',
        variations: ['O\'REILLY AUTO PARTS', 'ORILEY AUTO PARTS'],
        countries: ['US'],
      ),
      'NAPA': ChainInfo(
        name: 'NAPA',
        category: 'Transport & Fuel',
        variations: ['NAPA AUTO PARTS', 'NAPA STORES'],
        countries: ['US', 'CA'],
      ),

      // OFFICE SUPPLIES
      'STAPLES': ChainInfo(
        name: 'STAPLES',
        category: 'Office Supplies',
        variations: ['STAPLES INC', 'STAPLES STORES'],
        countries: ['US', 'CA'],
      ),
      'OFFICE DEPOT': ChainInfo(
        name: 'OFFICE DEPOT',
        category: 'Office Supplies',
        variations: ['OFFICE DEPOT INC', 'OFFICE DEPOT STORES'],
        countries: ['US', 'CA', 'MX'],
      ),
      'OFFICEMAX': ChainInfo(
        name: 'OFFICEMAX',
        category: 'Office Supplies',
        variations: ['OFFICEMAX INC', 'OFFICEMAX STORES'],
        countries: ['US'],
      ),

      // REGIONAL CHAINS - GERMANY
      'EDEKA': ChainInfo(
        name: 'EDEKA',
        category: 'Groceries',
        variations: ['EDEKA MARKT', 'EDEKA CENTER', 'EDEKA NEUKAUF'],
        countries: ['DE'],
      ),
      'KAUFLAND': ChainInfo(
        name: 'KAUFLAND',
        category: 'Groceries',
        variations: ['KAUFLAND STIFTUNG', 'KAUFLAND STORES'],
        countries: ['DE', 'CZ', 'SK', 'PL', 'RO', 'BG'],
      ),
      'PENNY': ChainInfo(
        name: 'PENNY',
        category: 'Groceries',
        variations: ['PENNY MARKT', 'PENNY STORES'],
        countries: ['DE', 'AT', 'CZ', 'HU', 'RO', 'IT'],
      ),
      'NETTO': ChainInfo(
        name: 'NETTO',
        category: 'Groceries',
        variations: ['NETTO MARKEN-DISCOUNT', 'NETTO STORES'],
        countries: ['DE', 'DK'],
      ),
      'NORMA': ChainInfo(
        name: 'NORMA',
        category: 'Groceries',
        variations: ['NORMA STORES'],
        countries: ['DE', 'AT', 'CZ', 'FR'],
      ),
      'REAL': ChainInfo(
        name: 'REAL',
        category: 'Groceries',
        variations: ['REAL HYPERMARKET', 'REAL STORES'],
        countries: ['DE'],
      ),
      'TEGUT': ChainInfo(
        name: 'TEGUT',
        category: 'Groceries',
        variations: ['TEGUT GUTE LEBENSMITTEL'],
        countries: ['DE'],
      ),
      'GLOBUS': ChainInfo(
        name: 'GLOBUS',
        category: 'Groceries',
        variations: ['GLOBUS HYPERMARKET', 'GLOBUS SB-WARENHAUS'],
        countries: ['DE', 'CZ'],
      ),
      'FAMILA': ChainInfo(
        name: 'FAMILA',
        category: 'Groceries',
        variations: ['FAMILA NORDOST', 'FAMILA STORES'],
        countries: ['DE'],
      ),
      'COMBI': ChainInfo(
        name: 'COMBI',
        category: 'Groceries',
        variations: ['COMBI MARKT', 'COMBI STORES'],
        countries: ['DE'],
      ),

      // REGIONAL CHAINS - FRANCE
      'LECLERC': ChainInfo(
        name: 'E.LECLERC',
        category: 'Groceries',
        variations: ['LECLERC', 'E LECLERC', 'CENTRES E.LECLERC'],
        countries: ['FR', 'ES', 'PL'],
      ),
      'INTERMARCHE': ChainInfo(
        name: 'INTERMARCHÉ',
        category: 'Groceries',
        variations: ['INTERMARCHE', 'INTERMARCHÉ SUPER', 'INTERMARCHÉ HYPER'],
        countries: ['FR', 'BE', 'PL'],
      ),
      'SUPER U': ChainInfo(
        name: 'SUPER U',
        category: 'Groceries',
        variations: ['SYSTÈME U', 'HYPER U', 'MARCHÉ U'],
        countries: ['FR'],
      ),
      'MONOPRIX': ChainInfo(
        name: 'MONOPRIX',
        category: 'Groceries',
        variations: ['MONOPRIX STORES'],
        countries: ['FR'],
      ),
      'FRANPRIX': ChainInfo(
        name: 'FRANPRIX',
        category: 'Groceries',
        variations: ['FRANPRIX STORES'],
        countries: ['FR'],
      ),
      'SIMPLY MARKET': ChainInfo(
        name: 'SIMPLY MARKET',
        category: 'Groceries',
        variations: ['SIMPLY', 'SIMPLY STORES'],
        countries: ['FR'],
      ),
      'CORA': ChainInfo(
        name: 'CORA',
        category: 'Groceries',
        variations: ['CORA HYPERMARKET'],
        countries: ['FR', 'BE', 'LU', 'RO'],
      ),
      'GÉANT CASINO': ChainInfo(
        name: 'GÉANT CASINO',
        category: 'Groceries',
        variations: ['GEANT CASINO', 'CASINO HYPERMARKET'],
        countries: ['FR'],
      ),
      'MATCH': ChainInfo(
        name: 'MATCH',
        category: 'Groceries',
        variations: ['MATCH STORES'],
        countries: ['FR', 'BE'],
      ),
      'SPAR FRANCE': ChainInfo(
        name: 'SPAR',
        category: 'Groceries',
        variations: ['SPAR STORES', 'EUROSPAR'],
        countries: ['FR', 'AT', 'IE', 'NL', 'BE', 'UK'],
      ),

      // REGIONAL CHAINS - SPAIN
      'MERCADONA': ChainInfo(
        name: 'MERCADONA',
        category: 'Groceries',
        variations: ['MERCADONA S.A.', 'MERCADONA STORES'],
        countries: ['ES', 'PT'],
      ),
      'EL CORTE INGLÉS': ChainInfo(
        name: 'EL CORTE INGLÉS',
        category: 'Groceries',
        variations: ['EL CORTE INGLES', 'CORTE INGLÉS'],
        countries: ['ES', 'PT'],
      ),
      'DIA': ChainInfo(
        name: 'DIA',
        category: 'Groceries',
        variations: ['DIA MARKET', 'DIA STORES', 'DISTRIBUIDORA INTERNACIONAL'],
        countries: ['ES', 'PT', 'BR', 'AR'],
      ),
      'HIPERCOR': ChainInfo(
        name: 'HIPERCOR',
        category: 'Groceries',
        variations: ['HIPERCOR STORES'],
        countries: ['ES'],
      ),
      'CONSUM': ChainInfo(
        name: 'CONSUM',
        category: 'Groceries',
        variations: ['CONSUM COOPERATIVA'],
        countries: ['ES'],
      ),
      'ALCAMPO': ChainInfo(
        name: 'ALCAMPO',
        category: 'Groceries',
        variations: ['ALCAMPO HYPERMARKET'],
        countries: ['ES'],
      ),
      'CAPRABO': ChainInfo(
        name: 'CAPRABO',
        category: 'Groceries',
        variations: ['CAPRABO STORES'],
        countries: ['ES'],
      ),
      'CONDIS': ChainInfo(
        name: 'CONDIS',
        category: 'Groceries',
        variations: ['CONDIS SUPERMERCAT'],
        countries: ['ES'],
      ),
      'GADIS': ChainInfo(
        name: 'GADIS',
        category: 'Groceries',
        variations: ['GADIS SUPERMERCADOS'],
        countries: ['ES'],
      ),
      'BONPREU': ChainInfo(
        name: 'BONPREU',
        category: 'Groceries',
        variations: ['BONPREU ESCLAT'],
        countries: ['ES'],
      ),

      // REGIONAL CHAINS - ITALY
      'COOP ITALIA': ChainInfo(
        name: 'COOP',
        category: 'Groceries',
        variations: ['COOP STORES', 'UNICOOP', 'IPERCOOP'],
        countries: ['IT'],
      ),
      'CONAD': ChainInfo(
        name: 'CONAD',
        category: 'Groceries',
        variations: ['CONAD STORES', 'CONAD SUPERSTORE'],
        countries: ['IT'],
      ),
      'ESSELUNGA': ChainInfo(
        name: 'ESSELUNGA',
        category: 'Groceries',
        variations: ['ESSELUNGA STORES'],
        countries: ['IT'],
      ),
      'PAM': ChainInfo(
        name: 'PAM',
        category: 'Groceries',
        variations: ['PAM PANORAMA', 'PAM LOCAL'],
        countries: ['IT'],
      ),
      'FAMILA ITALY': ChainInfo(
        name: 'FAMILA',
        category: 'Groceries',
        variations: ['FAMILA STORES'],
        countries: ['IT'],
      ),
      'BENNET': ChainInfo(
        name: 'BENNET',
        category: 'Groceries',
        variations: ['BENNET HYPERMARKET'],
        countries: ['IT'],
      ),
      'SIGMA': ChainInfo(
        name: 'SIGMA',
        category: 'Groceries',
        variations: ['SIGMA STORES'],
        countries: ['IT'],
      ),
      'DESPAR ITALIA': ChainInfo(
        name: 'DESPAR',
        category: 'Groceries',
        variations: ['DESPAR STORES', 'EUROSPAR ITALY'],
        countries: ['IT', 'AT', 'SI', 'HR'],
      ),
      'ICA': ChainInfo(
        name: 'ICA',
        category: 'Groceries',
        variations: ['ICA STORES'],
        countries: ['IT'],
      ),
      'TIGROS': ChainInfo(
        name: 'TIGROS',
        category: 'Groceries',
        variations: ['TIGROS STORES'],
        countries: ['IT'],
      ),

      // REGIONAL CHAINS - NETHERLANDS
      'ALBERT HEIJN': ChainInfo(
        name: 'ALBERT HEIJN',
        category: 'Groceries',
        variations: ['AH', 'ALBERT HEIJN TO GO', 'AH XL'],
        countries: ['NL', 'BE'],
      ),
      'JUMBO': ChainInfo(
        name: 'JUMBO',
        category: 'Groceries',
        variations: ['JUMBO SUPERMARKTEN'],
        countries: ['NL', 'BE'],
      ),
      'PLUS': ChainInfo(
        name: 'PLUS',
        category: 'Groceries',
        variations: ['PLUS SUPERMARKT'],
        countries: ['NL'],
      ),
      'SPAR NEDERLAND': ChainInfo(
        name: 'SPAR',
        category: 'Groceries',
        variations: ['SPAR CITY', 'SPAR UNIVERSITY'],
        countries: ['NL'],
      ),
      'COOP NEDERLAND': ChainInfo(
        name: 'COOP',
        category: 'Groceries',
        variations: ['COOP SUPERMARKT'],
        countries: ['NL'],
      ),
      'DIRK': ChainInfo(
        name: 'DIRK',
        category: 'Groceries',
        variations: ['DIRK VAN DEN BROEK'],
        countries: ['NL'],
      ),
      'VOMAR': ChainInfo(
        name: 'VOMAR',
        category: 'Groceries',
        variations: ['VOMAR VOORDEELMARKT'],
        countries: ['NL'],
      ),
      'NETTORAMA': ChainInfo(
        name: 'NETTORAMA',
        category: 'Groceries',
        variations: ['NETTORAMA STORES'],
        countries: ['NL'],
      ),
      'PICNIC': ChainInfo(
        name: 'PICNIC',
        category: 'Groceries',
        variations: ['PICNIC ONLINE'],
        countries: ['NL', 'DE'],
      ),
      'HOOGVLIET': ChainInfo(
        name: 'HOOGVLIET',
        category: 'Groceries',
        variations: ['HOOGVLIET SUPERMARKTEN'],
        countries: ['NL'],
      ),

      // REGIONAL CHAINS - UNITED KINGDOM
      'ICELAND': ChainInfo(
        name: 'ICELAND',
        category: 'Groceries',
        variations: ['ICELAND FOODS', 'THE FOOD WAREHOUSE'],
        countries: ['UK', 'IE'],
      ),
      'MARKS & SPENCER': ChainInfo(
        name: 'MARKS & SPENCER',
        category: 'Groceries',
        variations: ['M&S', 'MARKS AND SPENCER', 'M&S FOOD'],
        countries: ['UK', 'IE'],
      ),
      'COOPERATIVE': ChainInfo(
        name: 'CO-OP',
        category: 'Groceries',
        variations: ['COOP', 'COOPERATIVE FOOD', 'THE CO-OPERATIVE'],
        countries: ['UK'],
      ),
      'BUDGENS': ChainInfo(
        name: 'BUDGENS',
        category: 'Groceries',
        variations: ['BUDGENS STORES'],
        countries: ['UK'],
      ),
      'SPAR UK': ChainInfo(
        name: 'SPAR',
        category: 'Groceries',
        variations: ['SPAR STORES'],
        countries: ['UK'],
      ),
      'LONDIS': ChainInfo(
        name: 'LONDIS',
        category: 'Groceries',
        variations: ['LONDIS STORES'],
        countries: ['UK', 'IE'],
      ),
      'PREMIER': ChainInfo(
        name: 'PREMIER',
        category: 'Groceries',
        variations: ['PREMIER STORES'],
        countries: ['UK'],
      ),
      'FARMFOODS': ChainInfo(
        name: 'FARMFOODS',
        category: 'Groceries',
        variations: ['FARMFOODS STORES'],
        countries: ['UK'],
      ),
      'NISA': ChainInfo(
        name: 'NISA',
        category: 'Groceries',
        variations: ['NISA LOCAL', 'NISA EXTRA'],
        countries: ['UK'],
      ),
      'COSTCUTTER': ChainInfo(
        name: 'COSTCUTTER',
        category: 'Groceries',
        variations: ['COSTCUTTER STORES'],
        countries: ['UK'],
      ),

      // REGIONAL CHAINS - UNITED STATES (Additional)
      'PUBLIX': ChainInfo(
        name: 'PUBLIX',
        category: 'Groceries',
        variations: ['PUBLIX SUPER MARKETS', 'PUBLIX STORES'],
        countries: ['US'],
      ),
      'H-E-B': ChainInfo(
        name: 'H-E-B',
        category: 'Groceries',
        variations: ['HEB', 'H E B', 'HEB PLUS'],
        countries: ['US'],
      ),
      'WEGMANS': ChainInfo(
        name: 'WEGMANS',
        category: 'Groceries',
        variations: ['WEGMANS FOOD MARKETS'],
        countries: ['US'],
      ),
      'GIANT EAGLE': ChainInfo(
        name: 'GIANT EAGLE',
        category: 'Groceries',
        variations: ['GIANT EAGLE STORES'],
        countries: ['US'],
      ),
      'MEIJER': ChainInfo(
        name: 'MEIJER',
        category: 'Groceries',
        variations: ['MEIJER STORES'],
        countries: ['US'],
      ),
      'WINN-DIXIE': ChainInfo(
        name: 'WINN-DIXIE',
        category: 'Groceries',
        variations: ['WINN DIXIE'],
        countries: ['US'],
      ),
      'HARRIS TEETER': ChainInfo(
        name: 'HARRIS TEETER',
        category: 'Groceries',
        variations: ['HARRIS TEETER SUPERMARKETS'],
        countries: ['US'],
      ),
      'FOOD LION': ChainInfo(
        name: 'FOOD LION',
        category: 'Groceries',
        variations: ['FOOD LION STORES'],
        countries: ['US'],
      ),
      'PIGGLY WIGGLY': ChainInfo(
        name: 'PIGGLY WIGGLY',
        category: 'Groceries',
        variations: ['PIGGLY WIGGLY STORES'],
        countries: ['US'],
      ),
      'ALDI US': ChainInfo(
        name: 'ALDI',
        category: 'Groceries',
        variations: ['ALDI USA', 'ALDI STORES'],
        countries: ['US'],
      ),

      // REGIONAL CHAINS - CANADA
      'LOBLAWS': ChainInfo(
        name: 'LOBLAWS',
        category: 'Groceries',
        variations: ['LOBLAWS COMPANIES', 'LOBLAW'],
        countries: ['CA'],
      ),
      'SOBEYS': ChainInfo(
        name: 'SOBEYS',
        category: 'Groceries',
        variations: ['SOBEYS STORES'],
        countries: ['CA'],
      ),
      'METRO CANADA': ChainInfo(
        name: 'METRO',
        category: 'Groceries',
        variations: ['METRO STORES'],
        countries: ['CA'],
      ),
      'SAVE-ON-FOODS': ChainInfo(
        name: 'SAVE-ON-FOODS',
        category: 'Groceries',
        variations: ['SAVE ON FOODS'],
        countries: ['CA'],
      ),
      'IGA CANADA': ChainInfo(
        name: 'IGA',
        category: 'Groceries',
        variations: ['IGA STORES'],
        countries: ['CA'],
      ),
      'NO FRILLS': ChainInfo(
        name: 'NO FRILLS',
        category: 'Groceries',
        variations: ['NOFRILLS'],
        countries: ['CA'],
      ),
      'FOOD BASICS': ChainInfo(
        name: 'FOOD BASICS',
        category: 'Groceries',
        variations: ['FOOD BASICS STORES'],
        countries: ['CA'],
      ),
      'FRESHCO': ChainInfo(
        name: 'FRESHCO',
        category: 'Groceries',
        variations: ['FRESHCO STORES'],
        countries: ['CA'],
      ),
      'SUPERSTORE': ChainInfo(
        name: 'SUPERSTORE',
        category: 'Groceries',
        variations: ['REAL CANADIAN SUPERSTORE', 'ATLANTIC SUPERSTORE'],
        countries: ['CA'],
      ),
      'MAXI': ChainInfo(
        name: 'MAXI',
        category: 'Groceries',
        variations: ['MAXI & CIE'],
        countries: ['CA'],
      ),

      // REGIONAL CHAINS - AUSTRALIA
      'WOOLWORTHS': ChainInfo(
        name: 'WOOLWORTHS',
        category: 'Groceries',
        variations: ['WOOLIES', 'WOOLWORTHS SUPERMARKETS'],
        countries: ['AU'],
      ),
      'COLES': ChainInfo(
        name: 'COLES',
        category: 'Groceries',
        variations: ['COLES SUPERMARKETS'],
        countries: ['AU'],
      ),
      'IGA AUSTRALIA': ChainInfo(
        name: 'IGA',
        category: 'Groceries',
        variations: ['IGA SUPERMARKETS'],
        countries: ['AU'],
      ),
      'ALDI AUSTRALIA': ChainInfo(
        name: 'ALDI',
        category: 'Groceries',
        variations: ['ALDI STORES'],
        countries: ['AU'],
      ),
      'HARRIS FARM': ChainInfo(
        name: 'HARRIS FARM',
        category: 'Groceries',
        variations: ['HARRIS FARM MARKETS'],
        countries: ['AU'],
      ),
      'DRAKES': ChainInfo(
        name: 'DRAKES',
        category: 'Groceries',
        variations: ['DRAKES SUPERMARKETS'],
        countries: ['AU'],
      ),
      'SPUDSHED': ChainInfo(
        name: 'SPUDSHED',
        category: 'Groceries',
        variations: ['SPUDSHED STORES'],
        countries: ['AU'],
      ),
      'FOODWORKS': ChainInfo(
        name: 'FOODWORKS',
        category: 'Groceries',
        variations: ['FOODWORKS STORES'],
        countries: ['AU'],
      ),
      'SUPA IGA': ChainInfo(
        name: 'SUPA IGA',
        category: 'Groceries',
        variations: ['SUPA IGA STORES'],
        countries: ['AU'],
      ),
      'RITCHIES': ChainInfo(
        name: 'RITCHIES',
        category: 'Groceries',
        variations: ['RITCHIES STORES'],
        countries: ['AU'],
      ),
    };
  }

  /// Detect vendor using chain database with fuzzy matching
  static String? detectVendor(List<String> lines) {
    // Check cache first for performance
    final text = lines.join(' ').toUpperCase();
    if (_vendorCache.containsKey(text)) {
      return _vendorCache[text];
    }
    
    print('🔍 CHAIN DB: Starting vendor detection for ${lines.length} lines');
    print('🔍 CHAIN DB: First few lines: ${lines.take(3).toList()}');

    // First, try to detect business entities (Inc., LLC, Corp., etc.)
    final businessEntity = _detectBusinessEntity(lines);
    if (businessEntity != null) {
      _vendorCache[text] = businessEntity;
      return businessEntity;
    }

    // Try exact matches first (fastest)
    for (final line in lines.take(5)) {
      final cleanLine = _cleanVendorName(line);
      if (cleanLine.isEmpty) continue;

      // Direct lookup
      if (chains.containsKey(cleanLine)) {
        final result = chains[cleanLine]!.name;
        // Validate the detection makes sense
        if (_validateVendorDetection(result, lines)) {
          _vendorCache[text] = result;
          return result;
        }
      }

      // Try enhanced cleaning for embedded symbols
      final enhancedCleanLine = _cleanVendorNameWithSymbols(line);
      if (enhancedCleanLine != cleanLine && chains.containsKey(enhancedCleanLine)) {
        final result = chains[enhancedCleanLine]!.name;
        if (_validateVendorDetection(result, lines)) {
          _vendorCache[text] = result;
          return result;
        }
      }

      // Try fixing missing letters (common OCR issue)
      final fixedLine = _fixMissingLetters(cleanLine);
      if (fixedLine != cleanLine && chains.containsKey(fixedLine)) {
        final result = chains[fixedLine]!.name;
        if (_validateVendorDetection(result, lines)) {
          _vendorCache[text] = result;
          return result;
        }
      }

      // Try fixing common OCR substitutions with country-specific fixes
      final substitutedLine = _fixCommonOCRSubstitutions(cleanLine);
      if (substitutedLine != cleanLine && chains.containsKey(substitutedLine)) {
        final result = chains[substitutedLine]!.name;
        if (_validateVendorDetection(result, lines)) {
          _vendorCache[text] = result;
          return result;
        }
      }

      // Handle concatenated text (common OCR issue)
      final separatedWords = _separateConcatenatedWords(cleanLine);
      for (final word in separatedWords) {
        if (chains.containsKey(word)) {
          final result = chains[word]!.name;
          if (_validateVendorDetection(result, lines)) {
            _vendorCache[text] = result;
            return result;
          }
        }
      }

      // Try enhanced cleaning on separated words
      final enhancedSeparatedWords = _separateConcatenatedWords(enhancedCleanLine);
      for (final word in enhancedSeparatedWords) {
        if (chains.containsKey(word)) {
          final result = chains[word]!.name;
          if (_validateVendorDetection(result, lines)) {
            _vendorCache[text] = result;
            return result;
          }
        }
      }

      // DISABLED: Fuzzy matching causes false positives for unknown vendors
      // When a vendor is not in the chain database, we should let the position-based
      // detection handle it instead of forcing a fuzzy match to a wrong chain store
      
      // Only use fuzzy matching for very close matches (exact or 1 character difference)
      final fuzzyMatch = _findFuzzyMatch(cleanLine);
      if (fuzzyMatch != null) {
        print('🔍 CHAIN DB: Found fuzzy match for "$cleanLine": "${fuzzyMatch.name}"');
        final isVeryClose = _isVeryCloseMatch(cleanLine, fuzzyMatch.name);
        print('🔍 CHAIN DB: Is very close match: $isVeryClose');
        if (isVeryClose) {
          final result = fuzzyMatch.name;
          if (_validateVendorDetection(result, lines)) {
            print('🔍 CHAIN DB: Using fuzzy match: "$result"');
            _vendorCache[text] = result;
            return result;
          } else {
            print('🔍 CHAIN DB: Fuzzy match failed validation: "$result"');
          }
        } else {
          print('🔍 CHAIN DB: Fuzzy match not close enough: "$cleanLine" vs "${fuzzyMatch.name}"');
        }
      }

      // Enhanced fuzzy matching for embedded symbols - only very close matches
      final enhancedFuzzyMatch = _findFuzzyMatch(enhancedCleanLine);
      if (enhancedFuzzyMatch != null && _isVeryCloseMatch(enhancedCleanLine, enhancedFuzzyMatch.name)) {
        final result = enhancedFuzzyMatch.name;
        if (_validateVendorDetection(result, lines)) {
          _vendorCache[text] = result;
          return result;
        }
      }

      // Fuzzy matching on separated words - only very close matches
      for (final word in separatedWords) {
        final fuzzyMatch = _findFuzzyMatch(word);
        if (fuzzyMatch != null && _isVeryCloseMatch(word, fuzzyMatch.name)) {
          final result = fuzzyMatch.name;
          if (_validateVendorDetection(result, lines)) {
            _vendorCache[text] = result;
            return result;
          }
        }
      }

      // Enhanced fuzzy matching on separated words - only very close matches
      for (final word in enhancedSeparatedWords) {
        final fuzzyMatch = _findFuzzyMatch(word);
        if (fuzzyMatch != null && _isVeryCloseMatch(word, fuzzyMatch.name)) {
          final result = fuzzyMatch.name;
          if (_validateVendorDetection(result, lines)) {
            _vendorCache[text] = result;
            return result;
          }
        }
      }
    }

    print('🔍 CHAIN DB: No vendor found in chain database, returning null for fallback detection');
    return null; // Not found in chain database
  }

  /// Get category for detected vendor
  static String? getCategory(String vendorName) {
    final cleanName = _cleanVendorName(vendorName);
    
    // Check if it's a business entity first
    if (_isBusinessEntity(vendorName)) {
      return getBusinessEntityCategory(vendorName);
    }
    
    // Check chain database
    return chains[cleanName]?.category;
  }

  /// Check if vendor name is a business entity
  static bool _isBusinessEntity(String vendorName) {
    // Check for business entity patterns in the vendor name
    final businessEntityPatterns = [
      RegExp(r'.*\s+(Inc\.?|LLC|Corp\.?|Corporation|Ltd\.?|Limited|GmbH|AG|S\.A\.|S\.L\.|S\.R\.L\.)$', caseSensitive: false),
      RegExp(r'.*\s+(Inc|LLC|Corp|Corporation|Ltd|Limited|GmbH|AG|SA|SL|SRL)$', caseSensitive: false),
    ];
    
    for (final pattern in businessEntityPatterns) {
      if (pattern.hasMatch(vendorName)) {
        return true;
      }
    }
    
    return false;
  }

  /// Clean vendor name for matching
  static String _cleanVendorName(String name) {
    return name
        .toUpperCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim();
  }

  /// Enhanced cleaning for vendor names with embedded symbols/logos
  static String _cleanVendorNameWithSymbols(String name) {
    String cleaned = name.toUpperCase();
    
    // Handle common embedded symbols that might be OCR'd as special characters
    // Replace common OCR artifacts for embedded logos/symbols
    cleaned = cleaned
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special chars first
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim();
    
    // Handle specific cases where symbols might be OCR'd as letters
    // For example, a horse head logo in 'O' might be OCR'd as '0', '@', or other chars
    cleaned = _normalizeEmbeddedSymbols(cleaned);
    
    return cleaned;
  }

  /// Normalize common embedded symbol OCR artifacts
  static String _normalizeEmbeddedSymbols(String text) {
    // Common OCR artifacts for embedded symbols
    final symbolReplacements = {
      // Numbers that might be OCR'd from symbols
      '0': 'O', // Zero might be OCR'd from circular logos
      '8': 'B', // Eight might be OCR'd from certain symbols
      '6': 'G', // Six might be OCR'd from certain symbols
      '1': 'I', // One might be OCR'd from certain symbols
      '5': 'S', // Five might be OCR'd from certain symbols
      '@': 'A', // @ symbol in company names
      '&': 'AND', // Ampersand
      
      // Common logo/symbol OCR errors
      'Ø': 'O', // Scandinavian O with stroke
      'Ö': 'O', // O with umlaut
      'Ü': 'U', // U with umlaut
      'Ä': 'A', // A with umlaut
      'ß': 'SS', // German eszett
      
      // Common symbol replacements
      '★': '', // Star symbols
      '☆': '', // Star symbols
      '●': '', // Circle symbols
      '○': '', // Circle symbols
      '◆': '', // Diamond symbols
      '◇': '', // Diamond symbols
      '■': '', // Square symbols
      '□': '', // Square symbols
      '▲': '', // Triangle symbols
      '△': '', // Triangle symbols
      '♥': '', // Heart symbols
      '♠': '', // Spade symbols
      '♣': '', // Club symbols
      '♦': '', // Diamond symbols
      
      // Common OCR artifacts for logos
      '◯': 'O', // Large circle might be OCR'd as O
      '◎': 'O', // Double circle
      '◉': 'O', // Circle with dot
    };
    
    String result = text;
    for (final entry in symbolReplacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    
    return result;
  }

  /// Separate concatenated words in OCR output
  static List<String> _separateConcatenatedWords(String text) {
    final words = <String>[];
    
    // Common patterns for concatenated company names
    final patterns = [
      // ROSSMANN patterns
      RegExp(r'RSSMANN', caseSensitive: false),
      RegExp(r'ROSSMANN', caseSensitive: false),
      RegExp(r'RSSMANNMEIN', caseSensitive: false),
      RegExp(r'ROSSMANNMEIN', caseSensitive: false),
      RegExp(r'RSSMANNDROGERIE', caseSensitive: false),
      RegExp(r'ROSSMANNDROGERIE', caseSensitive: false),
      
      // Other common concatenated patterns
      RegExp(r'([A-Z]{2,})([A-Z][a-z]+)', caseSensitive: false), // CAPS followed by mixed case
      RegExp(r'([A-Z][a-z]+)([A-Z]{2,})', caseSensitive: false), // Mixed case followed by CAPS
    ];
    
    // Try specific patterns first
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        if (pattern.pattern.contains('RSSMANN') || pattern.pattern.contains('ROSSMANN')) {
          // Handle ROSSMANN specifically
          if (text.toUpperCase().contains('RSSMANN')) {
            words.add('ROSSMANN'); // Fix missing O
          } else if (text.toUpperCase().contains('ROSSMANN')) {
            words.add('ROSSMANN');
          }
        } else {
          // Handle other patterns
          for (int i = 1; i <= match.groupCount; i++) {
            final group = match.group(i);
            if (group != null && group.length > 2) {
              words.add(group.toUpperCase());
            }
          }
        }
      }
    }
    
    // If no patterns matched, try to split on common boundaries
    if (words.isEmpty) {
      // Split on capital letters followed by lowercase (camelCase)
      final camelCaseSplit = RegExp(r'([A-Z][a-z]+)');
      final matches = camelCaseSplit.allMatches(text);
      for (final match in matches) {
        final word = match.group(0);
        if (word != null && word.length > 2) {
          words.add(word.toUpperCase());
        }
      }
      
      // Split on sequences of uppercase letters
      final upperCaseSplit = RegExp(r'([A-Z]{2,})');
      final upperMatches = upperCaseSplit.allMatches(text);
      for (final match in upperMatches) {
        final word = match.group(0);
        if (word != null && word.length > 2) {
          words.add(word.toUpperCase());
        }
      }
    }
    
    return words;
  }

  /// Fix common missing letter patterns in OCR output
  static String _fixMissingLetters(String text) {
    String result = text.toUpperCase();
    
    // Common missing letter patterns
    final missingLetterPatterns = {
      // ROSSMANN patterns
      'RSSMANN': 'ROSSMANN', // Missing O due to embedded logo
      'RSSMAN': 'ROSSMANN', // Missing O and N
      'RSSMANNMEIN': 'ROSSMANN MEIN', // Missing O and space
      'RSSMANNDROGERIE': 'ROSSMANN DROGERIE', // Missing O and space
      'RSSMANNMEINDROGERIEMARKT': 'ROSSMANN MEIN DROGERIEMARKT', // Missing O and spaces
      
      // Other common OCR errors
      'MCDONALDS': 'MCDONALDS', // Already correct
      'MCDONALD': 'MCDONALDS', // Missing S
      'STARBUCKS': 'STARBUCKS', // Already correct
      'STARBUCK': 'STARBUCKS', // Missing S
      'WALMART': 'WALMART', // Already correct
      'TARGET': 'TARGET', // Already correct
      'COSTCO': 'COSTCO', // Already correct
      
      // German specific patterns
      'ALDI': 'ALDI', // Already correct
      'LIDL': 'LIDL', // Already correct
      'REWE': 'REWE', // Already correct
      'EROSKI': 'EROSKI', // Already correct
    };
    
    // Check for exact matches first
    if (missingLetterPatterns.containsKey(result)) {
      return missingLetterPatterns[result]!;
    }
    
    // Check for partial matches
    for (final entry in missingLetterPatterns.entries) {
      if (result.contains(entry.key)) {
        result = result.replaceAll(entry.key, entry.value);
        break;
      }
    }
    
    return result;
  }

  /// Handle common OCR character substitutions with country-specific fixes
  static String _fixCommonOCRSubstitutions(String text, [String? countryHint]) {
    String result = text.toUpperCase();
    
    // Apply country-specific OCR fixes first if hint is provided
    if (countryHint != null && _countrySpecificOCRFixes.containsKey(countryHint)) {
      final countryFixes = _countrySpecificOCRFixes[countryHint]!;
      for (final entry in countryFixes.entries) {
        result = result.replaceAll(entry.key, entry.value);
      }
    } else {
      // Apply all country-specific fixes if no hint (more comprehensive)
      for (final countryFixes in _countrySpecificOCRFixes.values) {
        for (final entry in countryFixes.entries) {
          result = result.replaceAll(entry.key, entry.value);
        }
      }
    }
    
    // Apply enhanced common OCR substitutions
    final substitutions = {
      ..._commonOCRSubstitutions, // Use the new enhanced patterns
      
      // Legacy patterns (keeping for backward compatibility)
      // Common OCR errors
      '0': 'O', // Zero to O
      '1': 'I', // One to I
      '5': 'S', // Five to S
      '8': 'B', // Eight to B
      '6': 'G', // Six to G
      '@': 'A', // At symbol to A
      '&': 'AND', // Ampersand to AND
      
      // Common letter confusions
      'I': 'I', // Keep I
      'l': 'I', // Lowercase l to uppercase I
      'ị': 'I', // Vietnamese i with dot below to I (common OCR error)
      'í': 'I', // Spanish i with accent to I
      'ì': 'I', // Italian i with grave to I
      'î': 'I', // French i with circumflex to I
      'ï': 'I', // German i with diaeresis to I
      'O': 'O', // Keep O
      'Q': 'O', // Q sometimes confused with O
      'D': 'O', // D sometimes confused with O
      'ó': 'O', // Spanish o with accent to O
      'ò': 'O', // Italian o with grave to O
      'ô': 'O', // French o with circumflex to O
      'ö': 'O', // German o with diaeresis to O
      'õ': 'O', // Portuguese o with tilde to O
      'A': 'A', // Keep A
      'á': 'A', // Spanish a with accent to A
      'à': 'A', // Italian a with grave to A
      'â': 'A', // French a with circumflex to A
      'ä': 'A', // German a with diaeresis to A
      'ã': 'A', // Portuguese a with tilde to A
      'E': 'E', // Keep E
      'é': 'E', // Spanish e with accent to E
      'è': 'E', // Italian e with grave to E
      'ê': 'E', // French e with circumflex to E
      'ë': 'E', // German e with diaeresis to E
      'U': 'U', // Keep U
      'ú': 'U', // Spanish u with accent to U
      'ù': 'U', // Italian u with grave to U
      'û': 'U', // French u with circumflex to U
      'ü': 'U', // German u with diaeresis to U
      
      // Common spacing issues
      ' ': ' ', // Keep spaces
      '  ': ' ', // Double space to single
      '   ': ' ', // Triple space to single
    };
    
    // Apply substitutions
    for (final entry in substitutions.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    
    return result;
  }

  /// Detect business entities (Inc., LLC, Corp., etc.) in receipt text
  static String? _detectBusinessEntity(List<String> lines) {
    // Business entity patterns
    final businessEntityPatterns = [
      RegExp(r'([A-Z][A-Za-z\s&]+)\s+(Inc\.?|LLC|Corp\.?|Corporation|Ltd\.?|Limited|GmbH|AG|S\.A\.|S\.L\.|S\.R\.L\.)', caseSensitive: false),
      RegExp(r'([A-Z][A-Za-z\s&]+)\s+(Inc|LLC|Corp|Corporation|Ltd|Limited|GmbH|AG|SA|SL|SRL)', caseSensitive: false),
    ];
    
    for (final line in lines.take(3)) { // Check first 3 lines for business names
      for (final pattern in businessEntityPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final companyName = match.group(1)?.trim();
          if (companyName != null && companyName.length > 2) {
            return companyName.toUpperCase();
          }
        }
      }
    }
    
    return null;
  }

  /// Get category for business entities (always "Services")
  static String? getBusinessEntityCategory(String vendorName) {
    // All business entities are categorized as "Services"
    return 'Services';
  }

  /// Validate that vendor detection makes sense in context
  static bool _validateVendorDetection(String detectedVendor, List<String> lines) {
    final text = lines.join(' ').toUpperCase();
    
    // Check if this is clearly a business entity receipt
    final businessEntityKeywords = [
      'INC', 'LLC', 'CORP', 'CORPORATION', 'LTD', 'LIMITED', 'GMBH', 'AG',
      'RECEIPT', 'INVOICE', 'BILL TO', 'SHIP TO', 'PAYMENT', 'DUE DATE',
      'P.O.', 'PURCHASE ORDER', 'QUOTE', 'ESTIMATE'
    ];
    
    final hasBusinessKeywords = businessEntityKeywords.any((keyword) => text.contains(keyword));
    
    // If this looks like a business entity receipt, don't match chain stores
    if (hasBusinessKeywords) {
      // Check if the detected vendor is a known chain store
      final chainStoreKeywords = [
        'ALDI', 'LIDL', 'WALMART', 'TARGET', 'COSTCO', 'MCDONALDS', 'STARBUCKS',
        'KFC', 'SUBWAY', 'BURGER KING', 'IKEA', 'HOMEDEPOT', 'LOWES', 'BEST BUY'
      ];
      
      if (chainStoreKeywords.contains(detectedVendor)) {
        return false; // Don't match chain stores for business receipts
      }
    }
    
    // Check for context clues that don't match the detected vendor
    final vendorCategory = getVendorCategory(detectedVendor);
    if (vendorCategory != null) {
      // Check for mismatched context
      if (vendorCategory == 'Groceries' && (text.contains('REPAIR') || text.contains('SERVICE'))) {
        return false; // Grocery store detected for repair service
      }
      if (vendorCategory == 'Food & Dining' && (text.contains('REPAIR') || text.contains('SERVICE'))) {
        return false; // Restaurant detected for repair service
      }
      if (vendorCategory == 'Furniture & Home' && (text.contains('REPAIR') || text.contains('SERVICE'))) {
        return false; // Furniture store detected for repair service
      }
    }
    
    return true; // Validation passed
  }

  /// Find fuzzy match for OCR errors
  static ChainInfo? _findFuzzyMatch(String name) {
    for (final entry in chains.entries) {
      final chainName = entry.key;
      final chainInfo = entry.value;
      
      // Check variations
      for (final variation in chainInfo.variations) {
        if (_isFuzzyMatch(name, variation)) {
          return chainInfo;
        }
      }
      
      // Check main name with fuzzy matching
      if (_isFuzzyMatch(name, chainName)) {
        return chainInfo;
      }
    }
    
    return null;
  }

  /// Check if two strings are concatenated matches (e.g., "REWEMarkt" vs "REWE MARKT")
  static bool _isConcatenatedMatch(String str1, String str2) {
    // Remove spaces from both strings for comparison
    final noSpace1 = str1.replaceAll(' ', '');
    final noSpace2 = str2.replaceAll(' ', '');
    
    // Check if they match when spaces are removed
    if (noSpace1 == noSpace2) return true;
    
    // Check if one contains the other when spaces are removed
    if (noSpace1.contains(noSpace2) || noSpace2.contains(noSpace1)) return true;
    
    // Check for common concatenation patterns
    // Split str2 by spaces and check if str1 contains all parts
    final parts2 = str2.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts2.length > 1) {
      String remaining = str1;
      bool allPartsFound = true;
      
      for (final part in parts2) {
        if (remaining.contains(part)) {
          // Remove the found part from remaining
          final index = remaining.indexOf(part);
          remaining = remaining.substring(0, index) + remaining.substring(index + part.length);
        } else {
          allPartsFound = false;
          break;
        }
      }
      
      if (allPartsFound) return true;
    }
    
    return false;
  }

  /// Check if two strings are very close matches (exact or 1 character difference)
  static bool _isVeryCloseMatch(String str1, String str2) {
    final clean1 = _cleanVendorName(str1);
    final clean2 = _cleanVendorName(str2);
    
    // Exact match
    if (clean1 == clean2) return true;
    
    // Only allow 1 character difference for very close matches
    final distance = _levenshteinDistance(clean1, clean2);
    final maxLength = [clean1.length, clean2.length].reduce((a, b) => a > b ? a : b);
    
    // Very strict: only 1 character difference for short strings, 2 for longer
    final maxDistance = maxLength <= 4 ? 1 : 2;
    
    return distance <= maxDistance;
  }

  /// Check if two strings are fuzzy matches (handles OCR errors)
  static bool _isFuzzyMatch(String str1, String str2) {
    final clean1 = _cleanVendorName(str1);
    final clean2 = _cleanVendorName(str2);
    
    // Exact match
    if (clean1 == clean2) return true;
    
    // Enhanced cleaning for embedded symbols
    final enhanced1 = _cleanVendorNameWithSymbols(str1);
    final enhanced2 = _cleanVendorNameWithSymbols(str2);
    
    if (enhanced1 == enhanced2) return true;
    
    // ENHANCED: More flexible contains match for concatenated OCR text
    final lengthRatio = clean1.length / clean2.length;
    if (lengthRatio > 1.2 && clean1.contains(clean2)) return true; // str1 contains str2 (reduced from 1.5)
    if (lengthRatio < 0.83 && clean2.contains(clean1)) return true; // str2 contains str1 (increased from 0.67)
    
    // Enhanced contains match with same logic
    final enhancedLengthRatio = enhanced1.length / enhanced2.length;
    if (enhancedLengthRatio > 1.2 && enhanced1.contains(enhanced2)) return true; // Reduced from 1.5
    if (enhancedLengthRatio < 0.83 && enhanced2.contains(enhanced1)) return true; // Increased from 0.67
    
    // ENHANCED: Handle concatenated words (e.g., "REWEMarkt" vs "REWE MARKT")
    if (_isConcatenatedMatch(clean1, clean2)) return true;
    if (_isConcatenatedMatch(enhanced1, enhanced2)) return true;
    
    // Levenshtein distance for OCR errors - more conservative
    final distance = _levenshteinDistance(clean1, clean2);
    final enhancedDistance = _levenshteinDistance(enhanced1, enhanced2);
    final maxLength = [clean1.length, clean2.length].reduce((a, b) => a > b ? a : b);
    
    // ENHANCED: More flexible distance threshold for concatenated text
    final maxDistance = maxLength <= 6 ? 1 : (maxLength <= 10 ? 3 : 4); // Increased thresholds
    
    return distance <= maxDistance || enhancedDistance <= maxDistance;
  }

  /// Calculate Levenshtein distance for fuzzy matching
  static int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<List<int>> matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      // deletion
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j - 1] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// Detect company format suffixes (GmbH, Ltd., etc.)
  static String? detectCompanyFormat(String text) {
    final upperText = text.toUpperCase();
    
    for (final entry in _companyFormats.entries) {
      if (upperText.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Get all company formats for a country
  static List<String> getCompanyFormatsForCountry(String countryCode) {
    // This could be expanded to return country-specific formats
    return _companyFormats.values.toList();
  }

  /// Get category for a vendor (public access for confidence validator)
  static String? getVendorCategory(String vendorName) {
    final cleanName = _cleanVendorName(vendorName);
    
    // Check if it's a business entity first
    if (_isBusinessEntity(vendorName)) {
      return getBusinessEntityCategory(vendorName);
    }
    
    // Check in chains databaseR
    if (chains.containsKey(cleanName)) {
      return chains[cleanName]!.category;
    }
    
    // Check variations
    for (final entry in chains.entries) {
      if (entry.value.variations.any((v) => _cleanVendorName(v) == cleanName)) {
        return entry.value.category;
      }
    }
    
    return null;
  }

  /// Check if a country is supported by the chain database
  static bool isCountrySupported(String countryCode) {
    for (final chain in chains.values) {
      if (chain.countries.contains(countryCode) || chain.countries.contains('GLOBAL')) {
        return true;
      }
    }
    return false;
  }

  /// Get all supported countries
  static Set<String> getSupportedCountries() {
    final countries = <String>{};
    for (final chain in chains.values) {
      countries.addAll(chain.countries);
    }
    countries.remove('GLOBAL'); // Remove the special GLOBAL marker
    return countries;
  }

  /// Get vendors for a specific country
  static List<ChainInfo> getVendorsForCountry(String countryCode) {
    return chains.values
        .where((chain) => chain.countries.contains(countryCode) || chain.countries.contains('GLOBAL'))
        .toList();
  }

  /// Enhanced vendor detection with country hint for better OCR fixes
  static String? detectVendorWithCountryHint(List<String> lines, String? countryHint) {
    // Use the existing detectVendor method but with enhanced OCR fixes
    if (countryHint != null) {
      // Apply country-specific preprocessing
      final enhancedLines = lines.map((line) => _enhanceLineForCountry(line, countryHint)).toList();
      return detectVendor(enhancedLines);
    }
    
    return detectVendor(lines);
  }

  /// Apply country-specific enhancements to a line
  static String _enhanceLineForCountry(String line, String countryCode) {
    // Apply country-specific OCR fixes
    if (_countrySpecificOCRFixes.containsKey(countryCode)) {
      String enhanced = line;
      final fixes = _countrySpecificOCRFixes[countryCode]!;
      
      for (final entry in fixes.entries) {
        enhanced = enhanced.replaceAll(entry.key, entry.value);
      }
      
      return enhanced;
    }
    
    return line;
  }

  /// Normalize a detected vendor name to a canonical chain name when possible.
  /// Examples: "REWE CITY" -> "REWE", "ALDI SÜD" -> "ALDI"
  static String normalizeVendorName(String vendorName) {
    if (vendorName.isEmpty) return vendorName;

    final cleaned = _cleanVendorName(vendorName);

    // Direct chain match
    if (chains.containsKey(cleaned)) {
      return chains[cleaned]!.name;
    }

    // Match against variations
    for (final entry in chains.entries) {
      final chain = entry.value;
      for (final variation in chain.variations) {
        if (_cleanVendorName(variation) == cleaned) {
          return chain.name;
        }
      }
    }

    // Strip common branch/location suffixes and try again
    final stripped = _stripBranchSuffixes(cleaned);
    if (stripped != cleaned && chains.containsKey(stripped)) {
      return chains[stripped]!.name;
    }

    // Try variations with stripped name
    for (final entry in chains.entries) {
      final chain = entry.value;
      for (final variation in chain.variations) {
        if (_cleanVendorName(variation) == stripped) {
          return chain.name;
        }
      }
    }

    return vendorName;
  }

  static String _stripBranchSuffixes(String name) {
    String result = name;
    const suffixes = [
      ' CITY',
      ' MARKET',
      ' MARKT',
      ' EXPRESS',
      ' SUPER',
      ' SUPERMARKET',
      ' STORE',
      ' STORES',
      ' SOUTH',
      ' NORTH',
      ' SUD',
      ' NORD',
      ' TO GO',
      ' LOCAL',
    ];

    for (final suffix in suffixes) {
      if (result.endsWith(suffix)) {
        result = result.substring(0, result.length - suffix.length).trim();
      }
    }

    return result;
  }
}
