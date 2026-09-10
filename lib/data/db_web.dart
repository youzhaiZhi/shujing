import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'models.dart';

/// Web 端 SQLite（基于 WASM + IndexedDB）
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await databaseFactoryFfiWeb.openDatabase('shujing.db');
    await _migrate(_db!);
    return _db!;
  }

  Future<void> _migrate(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sources(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        url TEXT NOT NULL UNIQUE,
        group_name TEXT DEFAULT '',
        enabled INTEGER DEFAULT 1,
        sort_order INTEGER DEFAULT 0,
        raw TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_id INTEGER NOT NULL,
        book_url TEXT NOT NULL,
        name TEXT NOT NULL,
        author TEXT DEFAULT '',
        cover_url TEXT DEFAULT '',
        intro TEXT DEFAULT '',
        kind TEXT DEFAULT '',
        word_count TEXT DEFAULT '',
        last_chapter TEXT DEFAULT '',
        toc_url TEXT DEFAULT '',
        in_shelf INTEGER DEFAULT 0,
        last_read INTEGER DEFAULT 0,
        chapter_count INTEGER DEFAULT 0,
        UNIQUE(source_id, book_url)
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chapters(
        book_id INTEGER NOT NULL,
        idx INTEGER NOT NULL,
        title TEXT NOT NULL,
        url TEXT DEFAULT '',
        PRIMARY KEY(book_id, idx)
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contents(
        book_id INTEGER NOT NULL,
        idx INTEGER NOT NULL,
        body TEXT NOT NULL,
        PRIMARY KEY(book_id, idx)
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS progress(
        book_id INTEGER PRIMARY KEY,
        chapter_idx INTEGER DEFAULT 0,
        scroll INTEGER DEFAULT 0,
        updated INTEGER DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        chapter_idx INTEGER NOT NULL,
        label TEXT DEFAULT '',
        created INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS read_stats(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        day TEXT NOT NULL,
        seconds INTEGER NOT NULL DEFAULT 0
      )''');
  }

  // ---------- 书源 ----------

  Future<List<BookSource>> sources() async {
    final db = await database;
    final rows = await db.query('sources', orderBy: 'sort_order ASC, id ASC');
    return rows.map(BookSource.fromRow).toList();
  }

  Future<void> importSources(List<BookSource> list) async {
    final db = await database;
    final batch = db.batch();
    for (final s in list) {
      batch.insert('sources', s.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> setSourceEnabled(int id, bool enabled) async {
    final db = await database;
    await db.update('sources', {'enabled': enabled ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSource(int id) async {
    final db = await database;
    await db.delete('sources', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- 书籍 ----------

  /// 保持 id 稳定：已存在则按 id 更新，避免章节/进度失联
  Future<int> upsertBook(Book book) async {
    final db = await database;
    final rows = await db.query('books',
        where: 'source_id = ? AND book_url = ?',
        whereArgs: [book.sourceId, book.bookUrl]);
    if (rows.isNotEmpty) {
      final id = rows.first['id'] as int;
      final row = book.toRow()..remove('id');
      await db.update('books', row, where: 'id = ?', whereArgs: [id]);
      return id;
    }
    final row = book.toRow()..remove('id');
    return db.insert('books', row);
  }

  Future<List<Book>> shelfBooks() async {
    final db = await database;
    final rows = await db.query('books',
        where: 'in_shelf = 1', orderBy: 'last_read DESC');
    return rows.map(Book.fromRow).toList();
  }

  Future<void> setInShelf(int bookId, bool inShelf) async {
    final db = await database;
    await db.update('books', {'in_shelf': inShelf ? 1 : 0},
        where: 'id = ?', whereArgs: [bookId]);
  }

  Future<void> touchBook(int bookId) async {
    final db = await database;
    await db.update('books', {'last_read': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [bookId]);
  }

  // ---------- 章节 ----------

  Future<void> saveChapters(int bookId, List<Chapter> chapters) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('chapters', where: 'book_id = ?', whereArgs: [bookId]);
    for (final c in chapters) {
      batch.insert('chapters', c.toRow(bookId),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await db.update('books', {'chapter_count': chapters.length},
        where: 'id = ?', whereArgs: [bookId]);
  }

  Future<List<Chapter>> chapters(int bookId) async {
    final db = await database;
    final rows = await db.query('chapters',
        where: 'book_id = ?', whereArgs: [bookId], orderBy: 'idx ASC');
    return rows.map(Chapter.fromRow).toList();
  }

  Future<void> saveContent(int bookId, int idx, String body) async {
    final db = await database;
    await db.insert('contents', {'book_id': bookId, 'idx': idx, 'body': body},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> content(int bookId, int idx) async {
    final db = await database;
    final rows = await db.query('contents',
        where: 'book_id = ? AND idx = ?', whereArgs: [bookId, idx]);
    return rows.isEmpty ? null : rows.first['body'] as String;
  }

  // ---------- 进度 ----------

  Future<void> saveProgress(int bookId, int chapterIdx, int scroll) async {
    final db = await database;
    await db.insert('progress', {
      'book_id': bookId,
      'chapter_idx': chapterIdx,
      'scroll': scroll,
      'updated': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await touchBook(bookId);
  }

  Future<(int, int)?> progress(int bookId) async {
    final db = await database;
    final rows = await db.query('progress',
        where: 'book_id = ?', whereArgs: [bookId]);
    if (rows.isEmpty) return null;
    return (rows.first['chapter_idx'] as int, rows.first['scroll'] as int);
  }

  // ---------- 书签 ----------

  Future<void> addBookmark(int bookId, int chapterIdx, String label) async {
    final db = await database;
    await db.insert('bookmarks', {
      'book_id': bookId,
      'chapter_idx': chapterIdx,
      'label': label,
      'created': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> bookmarks(int bookId) async {
    final db = await database;
    return db.query('bookmarks',
        where: 'book_id = ?', whereArgs: [bookId], orderBy: 'created DESC');
  }

  // ---------- 统计 ----------

  Future<void> addReadTime(int bookId, int seconds) async {
    if (seconds <= 0) return;
    final db = await database;
    final now = DateTime.now();
    final day =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final rows = await db.query('read_stats',
        where: 'book_id = ? AND day = ?', whereArgs: [bookId, day]);
    if (rows.isEmpty) {
      await db.insert(
          'read_stats', {'book_id': bookId, 'day': day, 'seconds': seconds});
    } else {
      await db.rawUpdate(
          'UPDATE read_stats SET seconds = seconds + ? WHERE book_id = ? AND day = ?',
          [seconds, bookId, day]);
    }
  }

  Future<List<Map<String, dynamic>>> statsForDays(int days) async {
    final db = await database;
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    final fmt = (DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return db.rawQuery(
        'SELECT day, SUM(seconds) as s FROM read_stats WHERE day >= ? GROUP BY day ORDER BY day ASC',
        [fmt(start)]);
  }

  Future<List<Map<String, dynamic>>> bookRanking() async {
    final db = await database;
    return db.rawQuery('''
      SELECT b.name, SUM(r.seconds) as s FROM read_stats r
      JOIN books b ON b.id = r.book_id
      GROUP BY r.book_id ORDER BY s DESC LIMIT 10''');
  }

  Future<Map<String, dynamic>> totals() async {
    final db = await database;
    final t = await db.rawQuery('SELECT SUM(seconds) as s FROM read_stats');
    final c = await db
        .rawQuery('SELECT COUNT(DISTINCT day) as c FROM read_stats');
    return {
      'totalSeconds': (t.first['s'] ?? 0) as int,
      'activeDays': (c.first['c'] ?? 0) as int,
    };
  }
}
