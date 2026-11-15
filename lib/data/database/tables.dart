import 'package:drift/drift.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  // Arayüzdeki simge listesinin dizini; veritabanı Flutter simgesi bilmez.
  IntColumn get icon => integer()();
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

@TableIndex(name: 'transactions_day', columns: {#day})
@TableIndex(name: 'transactions_category_day', columns: {#categoryId, #day})
@TableIndex(name: 'transactions_note_norm', columns: {#noteNorm})
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amountKurus =>
      // ignore: recursive_getters
      integer().check(amountKurus.isBiggerThanValue(0))();
  BoolColumn get isIncome => boolean()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get noteNorm => text().withDefault(const Constant(''))();
  // Yerel takvim günü, yyyymmdd.
  IntColumn get day => integer()();
  // Epoch ms.
  IntColumn get createdAt => integer()();
}

class Budgets extends Table {
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get monthlyLimitKurus => integer()();

  @override
  Set<Column> get primaryKey => {categoryId};
}

class KeywordHits extends Table {
  TextColumn get keyword => text()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get hits => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {keyword, categoryId};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
