import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/stock_asset.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('portfolio.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const textNullableType = 'TEXT';

    await db.execute('''
    CREATE TABLE $tableStockAssets (
      ${StockAssetFields.id} $idType,
      ${StockAssetFields.userId} $textType,
      ${StockAssetFields.symbol} $textType,
      ${StockAssetFields.name} $textNullableType, 
      ${StockAssetFields.shares} $realType,
      ${StockAssetFields.avgCostPrice} $realType,
      ${StockAssetFields.purchaseDate} $textType, 
      ${StockAssetFields.industry} $textNullableType
    )
    ''');
  }

  Future<StockAsset> create(StockAsset asset, String userId) async {
    final db = await instance.database;
    final jsonToInsert = asset.toJson();
    jsonToInsert[StockAssetFields.userId] = userId;
    final id = await db.insert(tableStockAssets, jsonToInsert);
    return asset.copyWith(id: id);
  }

  Future<StockAsset?> readAsset(int id, String userId) async {
    final db = await instance.database;
    final maps = await db.query(
      tableStockAssets,
      columns: StockAssetFields.values,
      where: '${StockAssetFields.id} = ? AND ${StockAssetFields.userId} = ?',
      whereArgs: [id, userId],
    );

    if (maps.isNotEmpty) {
      return StockAsset.fromJson(maps.first);
    } else {
      return null;
    }
  }

  Future<List<StockAsset>> readAllAssets(String userId) async {
    final db = await instance.database;
    const orderBy = '${StockAssetFields.symbol} ASC';
    final result = await db.query(
      tableStockAssets,
      orderBy: orderBy,
      where: '${StockAssetFields.userId} = ?',
      whereArgs: [userId],
    );
    return result.map((json) => StockAsset.fromJson(json)).toList();
  }

  Future<int> update(StockAsset asset, String userId) async {
    final db = await instance.database;
    return db.update(
      tableStockAssets,
      asset.toJson(),
      where: '${StockAssetFields.id} = ? AND ${StockAssetFields.userId} = ?',
      whereArgs: [asset.id, userId],
    );
  }

  Future<int> delete(int id, String userId) async {
    final db = await instance.database;
    return await db.delete(
      tableStockAssets,
      where: '${StockAssetFields.id} = ? AND ${StockAssetFields.userId} = ?',
      whereArgs: [id, userId],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
