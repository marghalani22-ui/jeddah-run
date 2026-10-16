/// Demo data until Firebase is wired up (step 7).
class Demo {
  static const name = 'مها';
  static const code = 'maha_runs';
  static const home = 'الشاطئ';
  static const level = 7, xp = 640, xpMax = 1000;
  static const streak = 5, bestStreak = 21;
  static const weekKm = 18.4, goalKm = 30.0;
  static const balance = 2450, pending = 180;

  static const weeks = [22.0, 26.5, 19.0, 31.2, 28.4, 24.0, 27.6, 18.4];

  static const daily = [
    ('5 كم اليوم', 0.6, 50),
    ('كيلو أسرع من 6:00', 1.0, 30),
    ('جولة قبل 7 ص', 0.0, 40),
  ];

  static const runs = [
    ('جولة الكورنيش', 'اليوم 6:12 ص', 6.24, '37:40', '6:02'),
    ('حديقة الأمير ماجد', 'أمس', 4.10, '25:18', '6:10'),
    ('ممشى التحلية', 'الثلاثاء', 8.05, '49:51', '6:12'),
  ];

  static const offers = [
    ('قهوة مختصة', 'خصم 20%', 600, 'كافيه البلد'),
    ('حذاء جري', 'خصم 15%', 2400, 'متجر الرياضة'),
    ('عصير طازج', 'مجاناً', 350, 'عصائر الكورنيش'),
    ('جلسة مساج', 'خصم 25%', 1800, 'مركز الاستشفاء'),
  ];
}
