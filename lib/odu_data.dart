class OduEntry {
  const OduEntry({
    required this.name,
    required this.marks,
    required this.isMeji,
  });
  final String name;
  final List<bool> marks;
  final bool isMeji;
}

const oduEntries = <OduEntry>[
  OduEntry(
    name: "BABA EJIOGBE",
    marks: [false, false, false, false, false, false, false, false],
    isMeji: true,
  ),
  OduEntry(
    name: "OYEKUN MEJI",
    marks: [true, true, true, true, true, true, true, true],
    isMeji: true,
  ),
  OduEntry(
    name: "IWORI MEJI",
    marks: [true, true, false, false, false, false, true, true],
    isMeji: true,
  ),
  OduEntry(
    name: "ODI MEJI",
    marks: [false, false, true, true, true, true, false, false],
    isMeji: true,
  ),
  OduEntry(
    name: "IROSO MEJI",
    marks: [false, false, false, false, true, true, true, true],
    isMeji: true,
  ),
  OduEntry(
    name: "OJUANI MEJI",
    marks: [true, true, true, true, false, false, false, false],
    isMeji: true,
  ),
  OduEntry(
    name: "OBARA MEJI",
    marks: [false, false, true, true, true, true, true, true],
    isMeji: true,
  ),
  OduEntry(
    name: "OKANA MEJI",
    marks: [true, true, true, true, true, true, false, false],
    isMeji: true,
  ),
  OduEntry(
    name: "OGUNDA MEJI",
    marks: [false, false, false, false, false, false, true, true],
    isMeji: true,
  ),
  OduEntry(
    name: "OSA MEJI",
    marks: [true, true, false, false, false, false, false, false],
    isMeji: true,
  ),
  OduEntry(
    name: "IKA MEJI",
    marks: [true, true, false, false, true, true, true, true],
    isMeji: true,
  ),
  OduEntry(
    name: "OTRUPON MEJI",
    marks: [true, true, true, true, false, false, true, true],
    isMeji: true,
  ),
  OduEntry(
    name: "OTURA MEJI",
    marks: [false, false, true, true, false, false, false, false],
    isMeji: true,
  ),
  OduEntry(
    name: "IRETE MEJI",
    marks: [false, false, false, false, true, true, false, false],
    isMeji: true,
  ),
  OduEntry(
    name: "OSHE MEJI",
    marks: [false, false, true, true, false, false, true, true],
    isMeji: true,
  ),
  OduEntry(
    name: "OFUN MEJI",
    marks: [true, true, false, false, true, true, false, false],
    isMeji: true,
  ),
  OduEntry(
    name: "OGBE YEKU",
    marks: [true, false, true, false, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGBE WEÑE",
    marks: [true, false, false, false, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGBE DI",
    marks: [false, false, true, false, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGBE ROSO",
    marks: [false, false, false, false, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGBE WANLE",
    marks: [true, false, true, false, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGBE BARA",
    marks: [false, false, true, false, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGBE KANA",
    marks: [true, false, true, false, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGBE YONO",
    marks: [false, false, false, false, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGBE SA",
    marks: [true, true, false, false, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGBE KA",
    marks: [true, false, false, false, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGBE TUMAKO",
    marks: [true, false, true, false, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGBE TUA",
    marks: [false, false, true, false, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGBE ATE",
    marks: [false, false, false, false, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGBE SHE",
    marks: [false, false, true, false, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGBE FUN",
    marks: [true, false, false, false, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN NILOGBE",
    marks: [false, true, false, true, false, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN PITI",
    marks: [true, false, false, false, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN DI",
    marks: [false, false, true, false, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN BIROSO",
    marks: [false, false, false, false, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN JUANI",
    marks: [true, false, true, false, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN BARA",
    marks: [false, false, true, false, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN PELEKA",
    marks: [true, false, true, false, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN TEKUNDA",
    marks: [false, false, false, false, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN BIRIKUSA",
    marks: [true, false, false, false, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN BIKA",
    marks: [true, false, false, false, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN BATRUPON",
    marks: [true, false, true, false, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN TESIA",
    marks: [false, false, true, false, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN BIRETE",
    marks: [false, false, false, false, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN PAKIOSHE",
    marks: [false, false, true, false, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OYEKUN BEDURA",
    marks: [true, false, false, false, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI BOGDE",
    marks: [false, true, false, false, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI YEKU",
    marks: [true, true, true, false, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI BODE",
    marks: [false, true, true, false, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI KOSO",
    marks: [false, true, false, false, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI JUANI",
    marks: [true, true, true, false, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI BARA",
    marks: [false, true, true, false, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI KANA",
    marks: [true, false, true, true, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI OGUNDA",
    marks: [false, true, false, false, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI BOSASO",
    marks: [true, true, false, false, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI BOKA",
    marks: [true, true, false, false, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI BATRUPON",
    marks: [true, true, true, false, false, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI TURALE",
    marks: [false, true, true, false, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI ROTE",
    marks: [false, true, false, false, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI BOSHE",
    marks: [false, true, true, false, false, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IWORI BOFUN",
    marks: [true, true, false, false, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI BERE",
    marks: [false, false, false, true, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI YEKU",
    marks: [true, false, true, true, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI ORO",
    marks: [true, false, false, true, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI ROSO",
    marks: [false, false, false, true, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI OMONI",
    marks: [true, false, true, true, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI BARA",
    marks: [false, false, true, true, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI KANA",
    marks: [true, false, true, true, true, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI TOLA",
    marks: [false, false, false, true, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI SA",
    marks: [true, false, false, true, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI KA",
    marks: [true, false, false, true, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI BATRUPON",
    marks: [true, false, true, true, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI TAURO",
    marks: [false, false, true, true, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI LEKE",
    marks: [false, false, false, true, true, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI SHE",
    marks: [false, false, true, true, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "ODI FUMBO",
    marks: [true, false, false, true, true, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO UMBO",
    marks: [false, false, false, false, false, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO MATELEKUN",
    marks: [true, false, true, false, true, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO WIRO",
    marks: [true, false, false, false, false, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO ODI",
    marks: [false, false, true, false, true, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO WALE",
    marks: [true, false, true, false, false, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO GAN",
    marks: [false, false, true, false, true, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO KALU",
    marks: [true, false, true, false, true, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO TOLDA",
    marks: [false, false, false, false, false, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO SA",
    marks: [true, false, true, false, true, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO KA",
    marks: [true, false, false, false, true, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO BATUTO",
    marks: [true, false, true, false, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO TUANILARA",
    marks: [false, false, true, false, false, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO UNKUEMI",
    marks: [false, false, false, false, true, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO SHE",
    marks: [false, false, true, false, false, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IROSO FUMBO",
    marks: [true, false, false, false, true, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANI SHOGBE",
    marks: [false, true, false, true, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANI YEKUN",
    marks: [true, false, true, false, true, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANI TANSHELA",
    marks: [true, true, true, false, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANI SHIDI",
    marks: [false, true, true, true, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANI HERMOSO",
    marks: [false, true, false, true, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANI LOSURE",
    marks: [false, true, true, true, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANI POKON",
    marks: [true, true, true, true, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANI DAWAN",
    marks: [false, true, false, true, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANI BOSASO",
    marks: [true, true, false, true, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANO BOKA",
    marks: [true, true, false, true, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANI BATRUPON",
    marks: [true, true, true, true, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANI ALAKENTU",
    marks: [false, true, true, true, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANI BIRETE",
    marks: [false, true, false, true, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANI BOSHE",
    marks: [false, true, true, true, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OJUANI BOFUN",
    marks: [true, true, false, true, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA BOGBE",
    marks: [false, false, false, true, false, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA YEKUN",
    marks: [true, false, true, true, true, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA WEREKO",
    marks: [true, false, false, true, false, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA DILA",
    marks: [false, false, true, true, true, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA KOSO",
    marks: [false, false, false, true, true, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA OJUANI",
    marks: [true, false, true, true, false, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA KANA",
    marks: [true, false, true, true, true, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA KUÑA",
    marks: [false, false, false, true, false, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA SA",
    marks: [true, false, false, true, false, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA KASIKA",
    marks: [true, false, false, true, true, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA TUMBUN",
    marks: [true, false, true, true, false, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA KUSHIYA",
    marks: [false, false, true, true, false, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA KETE",
    marks: [false, false, false, true, true, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA SHE",
    marks: [false, false, true, true, false, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OBARA FUN",
    marks: [true, false, false, true, true, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA SODE",
    marks: [false, true, false, true, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA OYEKUN",
    marks: [true, true, true, true, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA JIO",
    marks: [true, true, false, true, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA DI",
    marks: [false, true, true, true, true, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA ROSO",
    marks: [false, true, false, true, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA YABILE",
    marks: [true, true, true, true, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA BARA",
    marks: [false, true, true, true, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA KAKUIN",
    marks: [false, true, false, true, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA SA",
    marks: [true, true, false, true, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA KA",
    marks: [true, true, false, true, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA TRUPON",
    marks: [true, true, true, true, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA TURALE",
    marks: [false, true, true, true, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA WETE",
    marks: [false, true, false, true, true, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA SHE",
    marks: [false, true, true, true, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OKANA FUN",
    marks: [true, true, false, true, true, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA BIODE",
    marks: [false, false, false, false, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA YEKUN",
    marks: [true, false, true, false, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA KUANEYE",
    marks: [true, false, false, false, false, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA DIO",
    marks: [false, false, true, false, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA KOROSO",
    marks: [false, false, false, false, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA LENI",
    marks: [true, false, true, false, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA BAMBO",
    marks: [false, false, true, false, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA KO",
    marks: [true, false, true, false, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA MASA",
    marks: [true, false, false, false, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA KA",
    marks: [true, false, false, false, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA TRUPON",
    marks: [true, false, true, false, false, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA TETURA",
    marks: [false, false, true, false, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA KETE",
    marks: [false, false, false, false, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA SHE",
    marks: [false, false, true, false, false, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OGUNDA FUN",
    marks: [true, false, false, false, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA LOFOBEYO",
    marks: [false, true, false, false, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA YEKUN",
    marks: [true, true, true, false, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA WORIWO",
    marks: [true, true, false, false, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA DI",
    marks: [false, true, true, false, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA ROSO",
    marks: [false, true, false, false, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA LONI",
    marks: [true, true, true, false, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA SHEPE",
    marks: [false, true, true, false, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA KANA",
    marks: [true, true, true, false, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA KULEYA",
    marks: [false, true, false, false, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA KA",
    marks: [true, true, false, false, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA TRUPON",
    marks: [true, true, true, false, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA URE",
    marks: [false, true, true, false, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA RETE",
    marks: [false, true, false, false, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA SHE",
    marks: [false, true, true, false, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSA FUN",
    marks: [true, true, false, false, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA BEMI",
    marks: [false, true, false, false, false, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA OYECUN",
    marks: [true, true, true, false, true, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA FEFE",
    marks: [true, true, false, false, false, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA DI",
    marks: [false, true, true, false, true, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA ROSO",
    marks: [false, true, false, false, true, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA JUNKO",
    marks: [true, true, true, false, false, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA BARA",
    marks: [false, true, true, false, true, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA KANA",
    marks: [true, true, true, false, true, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA OGUNDA",
    marks: [false, true, false, false, false, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA SA",
    marks: [true, true, false, false, false, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA TRUPON",
    marks: [true, true, true, false, false, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA FOGUERO",
    marks: [false, true, true, false, false, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA RETE",
    marks: [false, true, false, false, true, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA FA",
    marks: [false, true, true, false, false, true, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "IKA FUN",
    marks: [true, true, false, false, true, true, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON BEKONWAO",
    marks: [false, true, false, true, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON YEKUN",
    marks: [true, true, true, true, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON ADAKINO",
    marks: [true, true, false, true, false, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON DI",
    marks: [false, true, true, true, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON KOSO",
    marks: [false, true, false, true, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON ÑAO",
    marks: [true, true, true, true, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON BARA IFE",
    marks: [false, true, true, true, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON KANA",
    marks: [true, true, true, true, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON ODUNDA",
    marks: [true, true, false, true, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON SA",
    marks: [true, true, false, true, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON KA",
    marks: [true, true, false, true, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON TAURO",
    marks: [false, true, true, true, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON BIRETE",
    marks: [false, true, false, true, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON SHE",
    marks: [false, true, true, true, false, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTRUPON BALOFUN",
    marks: [true, true, false, true, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA NIKO",
    marks: [false, false, false, true, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA YEKUN",
    marks: [true, false, true, true, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA POMPEYO",
    marks: [true, false, false, true, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA DI",
    marks: [false, false, true, true, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA ROSO",
    marks: [false, false, false, true, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA LAKENTU",
    marks: [true, false, true, true, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA BARA",
    marks: [false, false, true, true, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA KITU",
    marks: [true, false, true, true, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA AIRA",
    marks: [false, false, false, true, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA SA",
    marks: [true, false, false, true, false, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA KA",
    marks: [true, false, false, true, true, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA TRUPON",
    marks: [true, false, true, true, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA TIYU",
    marks: [false, false, false, true, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA SHE",
    marks: [false, false, true, true, false, false, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OTURA ADAKOY",
    marks: [true, false, false, true, true, false, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE UNTELU",
    marks: [false, false, false, false, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE YEKUN",
    marks: [true, false, true, false, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE YERO",
    marks: [true, false, false, false, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE UNTENDI",
    marks: [false, false, true, false, true, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE LAZO",
    marks: [false, false, false, false, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE WAN WAN",
    marks: [true, false, true, false, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE OBA",
    marks: [false, false, true, false, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE KANA",
    marks: [true, false, true, false, true, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE KUTAN",
    marks: [false, false, false, false, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE ANSA",
    marks: [true, false, false, false, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE KA",
    marks: [true, false, false, false, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE TRUPON",
    marks: [true, false, true, false, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE SUKA",
    marks: [false, false, true, false, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE UNFA",
    marks: [false, false, true, false, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "IRETE FILE",
    marks: [true, false, false, false, true, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE NILOGBE",
    marks: [false, false, false, true, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE YEKUN",
    marks: [true, false, true, true, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE PAURE",
    marks: [true, false, false, true, false, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE DI",
    marks: [false, false, true, true, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE LEZO",
    marks: [false, false, false, true, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE NIWO",
    marks: [true, false, true, true, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE BARA",
    marks: [false, false, true, true, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE KANA",
    marks: [true, false, true, true, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE OMOLU",
    marks: [false, false, false, true, false, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE SA",
    marks: [true, false, false, true, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE KA",
    marks: [true, false, false, true, true, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE TRUPON",
    marks: [true, false, true, true, false, false, true, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE TURA",
    marks: [false, false, true, true, false, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE BILE",
    marks: [false, false, false, true, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OSHE FUN",
    marks: [true, false, false, true, true, false, false, true],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN NALBE",
    marks: [false, true, false, false, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN YEMILO",
    marks: [true, true, true, false, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN GANDO",
    marks: [true, true, false, false, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN DI",
    marks: [false, true, true, false, true, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN BIROSO",
    marks: [false, true, false, false, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN FUNI",
    marks: [true, true, true, false, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN SUSU",
    marks: [false, true, true, false, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN KANA",
    marks: [true, true, true, false, true, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN FUNDA",
    marks: [false, true, false, false, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN SA",
    marks: [true, true, false, false, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN KAMALA",
    marks: [true, true, false, false, true, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN BATRUPON",
    marks: [true, true, true, false, false, true, true, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN TEMPOLA",
    marks: [false, true, true, false, false, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN BIRETE",
    marks: [false, true, false, false, true, true, false, false],
    isMeji: false,
  ),
  OduEntry(
    name: "OFUN SHE",
    marks: [false, true, true, false, false, true, true, false],
    isMeji: false,
  ),
];
