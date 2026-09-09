import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/settings_provider.dart';

final appStringsProvider = Provider<AppStrings>((ref) {
  final language = ref.watch(appLanguageProvider);
  return AppStrings(language);
});

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isRu => language == AppLanguage.ru;

  String get health => isRu ? 'Здоровье' : 'Sog‘liq';
  String get devices => isRu ? 'Устройства' : 'Qurilmalar';
  String get settings => isRu ? 'Настройки' : 'Sozlamalar';
  String get history => isRu ? 'История' : 'Tarix';
  String get last7Days => isRu ? 'Последние 7 дней' : 'Oxirgi 7 kun';
  String get calories => isRu ? 'Калории' : 'Kaloriya';
  String get steps => isRu ? 'Шаги' : 'Qadamlar';
  String get distance => isRu ? 'Дистанция' : 'Masofa';
  String get sleep => isRu ? 'Сон' : 'Uyqu';
  String get heartRate => isRu ? 'Пульс' : 'Yurak urish tezligi';
  String get bloodPressure => isRu ? 'Давление' : 'Qon bosimi';
  String get oxygen => isRu ? 'Кислород' : 'Kislorod miqdori';
  String get stress => isRu ? 'Стресс' : 'Stress';
  String get met => 'MET';
  String get ecg => isRu ? 'ЭКГ' : 'EKG';
  String get startMeasurement => isRu ? 'Начать измерение' : 'O‘lchashni boshlash';
  String get measuring => isRu ? 'Измеряется' : 'O‘lchanmoqda';
  String get measure => isRu ? 'Измерить' : 'O‘lchash';
  String get latest => isRu ? 'Последнее' : 'So‘nggi';
  String get average => isRu ? 'Среднее' : 'O‘rtacha';
  String get min => isRu ? 'Мин' : 'Eng past';
  String get max => isRu ? 'Макс' : 'Eng baland';
  String get dailyMetric => isRu ? 'Дневной показатель' : 'Kunlik ko‘rsatkich';
  String get weeklyTrend => isRu ? 'Тренд за 7 дней' : '7 kunlik trend';
  String get noDataYet => isRu ? 'Данных пока нет' : 'Ma’lumot hali yo‘q';
  String get normal => isRu ? 'Норма' : 'Normal';
  String get lastMeasurement => isRu ? 'Последнее измерение' : 'Oxirgi o‘lchov';
  String get connectedRequired =>
      isRu ? 'Подключите браслет!' : 'Brasletni ulang!';
  String get howMeasured => isRu ? 'Как измеряется?' : 'Qanday o‘lchanadi?';
  String get languageTitle => isRu ? 'Язык' : 'Til';
  String get uzbek => isRu ? 'Узбекский' : 'O‘zbek';
  String get russian => isRu ? 'Русский' : 'Rus';
  String get theme => isRu ? 'Тема' : 'Mavzu';
  String get system => isRu ? 'Система' : 'Tizim';
  String get light => isRu ? 'Светлая' : 'Yorug‘';
  String get dark => isRu ? 'Темная' : 'Qorong‘i';
  String get autoReconnect => isRu ? 'Автоподключение' : 'Avto ulanish';
  String get syncOnConnect => isRu ? 'Синхронизация при подключении' : 'Ulanganda sinxronlash';
  String get showAllBle => isRu ? 'Показывать все BLE устройства' : 'Barcha BLE qurilmalarni ko‘rsatish';
  String get devicePassword => isRu ? 'Пароль устройства' : 'Qurilma paroli';
  String get clearLocalData => isRu ? 'Очистить локальные данные' : 'Lokal ma’lumotlarni tozalash';
  String get clearLocalDataHint =>
      isRu ? 'Удаляет устройства и историю здоровья с телефона.' : 'Telefondagi qurilmalar va tarixni o‘chiradi.';
  String get noDevice => isRu ? 'Браслет не подключен' : 'Braslet ulanmagan';
  String get connected => isRu ? 'Подключено' : 'Ulangan';
  String get syncNow => isRu ? 'Синхронизировать' : 'Sinxronlash';

  String get sleepDescription =>
      isRu ? 'Качество и длительность сна' : 'Uyqu sifati va davomiyligini kuzating';
  String get heartDescription =>
      isRu ? 'Контроль показателей пульса' : 'Puls ko‘rsatkichlarini nazorat qiling';
  String get bloodPressureDescription =>
      isRu ? 'Регулярно следите за давлением' : 'Qon bosimini muntazam kuzating';
  String get oxygenDescription => isRu ? 'Измеряйте уровень кислорода' : 'Kislorod darajasini o‘lchang';
  String get stressDescription =>
      isRu ? 'Отслеживайте стресс за день' : 'Kun davomida stress darajasini kuzating';
  String get metDescription =>
      isRu ? 'Интенсивность активности' : 'Faollik intensivligini kuzating';
  String get ecgDescription =>
      isRu ? 'Следите за сигналом сердца' : 'Yuragingizga bugundan g‘amxo‘rlik qiling';
  String get metExplanation => isRu
      ? 'MET не измеряется вручную. Браслет рассчитывает значение по шагам и интенсивности движения.'
      : 'MET qo‘lda o‘lchanmaydi. Braslet qadamlar sur’ati va harakat intensivligidan qiymatni avtomatik hisoblaydi.';
  String get ecgHelp => isRu
      ? 'Наденьте браслет плотно, сохраняйте спокойствие и держите руку неподвижно во время измерения.'
      : 'Brasletni mahkam taqing, tinch turing va o‘lchov paytida qo‘lingizni qimirlatmang.';
}
