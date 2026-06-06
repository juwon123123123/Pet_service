import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';

import 'models.dart';

/// 배포된 Cloud Run 서버를 기본 base URL로 사용.
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   (안드 에뮬)
///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000  (iOS/web/macOS)
const _kProdBaseUrl = 'https://pet-times-901998453571.asia-northeast3.run.app';

String _resolveBaseUrl() {
  const fromDefine = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (fromDefine.isNotEmpty) return fromDefine;
  return _kProdBaseUrl;
}

final _date = DateFormat('yyyy-MM-dd');

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => 'ApiException($status): $message';
}

class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? _resolveBaseUrl();

  final String baseUrl;
  final http.Client _http = http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = query?.map((k, v) => MapEntry(k, '$v'));
    return Uri.parse('$baseUrl$path').replace(queryParameters: q);
  }

  Future<dynamic> _decode(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    String msg = res.body;
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is Map && j['detail'] != null) msg = '${j['detail']}';
    } catch (_) {}
    throw ApiException(res.statusCode, msg);
  }

  Future<Map<String, String>> _jsonHeaders() async => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };

  // ── Pets ─────────────────────────────────────────────────────────────
  Future<Pet> createPet(PetCreate body) async {
    final res = await _http.post(
      _uri('/pets'),
      headers: await _jsonHeaders(),
      body: jsonEncode(body.toJson()),
    );
    return Pet.fromJson(await _decode(res) as Map<String, dynamic>);
  }

  Future<List<Pet>> listPets() async {
    final res = await _http.get(_uri('/pets'));
    final list = await _decode(res) as List;
    return list.map((j) => Pet.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Pet> getPet(int id) async {
    final res = await _http.get(_uri('/pets/$id'));
    return Pet.fromJson(await _decode(res) as Map<String, dynamic>);
  }

  Future<void> deletePet(int id) async {
    final res = await _http.delete(_uri('/pets/$id'));
    await _decode(res);
  }

  /// 변경할 필드만 비-null로 채워서 PATCH. species는 변경 불가.
  Future<Pet> updatePet(
    int id, {
    String? name,
    String? breed,
    DateTime? birthDate,
    String? sex,
    bool? neutered,
    double? weightKg,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (breed != null) body['breed'] = breed;
    if (birthDate != null) body['birth_date'] = _date.format(birthDate);
    if (sex != null) body['sex'] = sex;
    if (neutered != null) body['neutered'] = neutered;
    if (weightKg != null) body['weight_kg'] = weightKg;
    final res = await _http.patch(
      _uri('/pets/$id'),
      headers: await _jsonHeaders(),
      body: jsonEncode(body),
    );
    return Pet.fromJson(await _decode(res) as Map<String, dynamic>);
  }

  // ── Calendar ─────────────────────────────────────────────────────────
  Future<List<Event>> rebuildCalendar(int petId, {int horizonDays = 365}) async {
    final res = await _http.post(
      _uri('/calendar/$petId/rebuild', {'horizon_days': horizonDays}),
    );
    final list = await _decode(res) as List;
    return list.map((j) => Event.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Event>> listEvents(
    int petId, {
    DateTime? start,
    DateTime? end,
    bool includeDone = false,
  }) async {
    final res = await _http.get(_uri('/calendar/$petId', {
      if (start != null) 'start': _date.format(start),
      if (end != null) 'end': _date.format(end),
      'include_done': includeDone,
    }));
    final list = await _decode(res) as List;
    return list.map((j) => Event.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Event>> upcoming(int petId, {int days = 30}) async {
    final res = await _http.get(_uri('/calendar/$petId/upcoming', {'days': days}));
    final list = await _decode(res) as List;
    return list.map((j) => Event.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Event> updateEvent(
    int eventId, {
    String? title,
    String? category,
    DateTime? dueDate,
    bool? recurring,
    int? intervalDays,
    String? notes,
    bool? done,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (category != null) body['category'] = category;
    if (dueDate != null) body['due_date'] = _date.format(dueDate);
    if (recurring != null) body['recurring'] = recurring;
    if (intervalDays != null) body['interval_days'] = intervalDays;
    if (notes != null) body['notes'] = notes;
    if (done != null) body['done'] = done;
    final res = await _http.patch(
      _uri('/calendar/event/$eventId'),
      headers: await _jsonHeaders(),
      body: jsonEncode(body),
    );
    return Event.fromJson(await _decode(res) as Map<String, dynamic>);
  }

  Future<Event> createEvent(
    int petId, {
    required String title,
    String category = 'other',
    required DateTime dueDate,
    bool recurring = false,
    int? intervalDays,
    String? notes,
  }) async {
    final res = await _http.post(
      _uri('/calendar/$petId'),
      headers: await _jsonHeaders(),
      body: jsonEncode({
        'title': title,
        'category': category,
        'due_date': _date.format(dueDate),
        'recurring': recurring,
        'interval_days': ?intervalDays,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }),
    );
    return Event.fromJson(await _decode(res) as Map<String, dynamic>);
  }

  Future<void> deleteEvent(int eventId) async {
    final res = await _http.delete(_uri('/calendar/event/$eventId'));
    await _decode(res);
  }

  // ── Guides ───────────────────────────────────────────────────────────
  Future<Guide> createGuide(int petId, {List<String>? topics}) async {
    final res = await _http.post(
      _uri('/guides'),
      headers: await _jsonHeaders(),
      body: jsonEncode({
        'pet_id': petId,
        if (topics != null && topics.isNotEmpty) 'topics': topics,
      }),
    );
    return Guide.fromJson(await _decode(res) as Map<String, dynamic>);
  }

  Future<Guide?> latestGuide(int petId) async {
    final res = await _http.get(_uri('/guides/$petId/latest'));
    if (res.statusCode == 404) return null;
    return Guide.fromJson(await _decode(res) as Map<String, dynamic>);
  }

  // ── Pet photo upload ─────────────────────────────────────────────────
  Future<Pet> uploadPetPhoto(int petId, String filePath) async {
    final req = http.MultipartRequest('POST', _uri('/pets/$petId/photo'))
      ..files.add(await _imageFile(filePath));
    final streamed = await _http.send(req);
    final res = await http.Response.fromStream(streamed);
    return Pet.fromJson(await _decode(res) as Map<String, dynamic>);
  }

  // ── Products ─────────────────────────────────────────────────────────
  Future<Product> getProduct(int id) async {
    final res = await _http.get(_uri('/products/$id'));
    return Product.fromJson(await _decode(res) as Map<String, dynamic>);
  }

  Future<List<Product>> listProducts({String? species, String? category}) async {
    final res = await _http.get(_uri('/products', {
      'species': ?species,
      'category': ?category,
    }));
    final list = await _decode(res) as List;
    return list.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();
  }

  // ── Generations ──────────────────────────────────────────────────────
  /// 즉석 사진(앨범에서 새로 고른 사진)을 임시 업로드해서 path 받기.
  Future<String> uploadTempPhoto(String filePath) async {
    final req = http.MultipartRequest('POST', _uri('/generations/upload_temp'))
      ..files.add(await _imageFile(filePath));
    final streamed = await _http.send(req);
    final res = await http.Response.fromStream(streamed);
    final body = await _decode(res) as Map<String, dynamic>;
    return body['photo_path'] as String;
  }

  Future<List<Generation>> startGenerations({
    required int petId,
    required bool useRegistered,
    String? tempPhotoPath,
    List<int>? productIds,
  }) async {
    final res = await _http.post(
      _uri('/generations'),
      headers: await _jsonHeaders(),
      body: jsonEncode({
        'pet_id': petId,
        'use_registered': useRegistered,
        'temp_photo_path': ?tempPhotoPath,
        if (productIds != null && productIds.isNotEmpty)
          'product_ids': productIds,
      }),
    );
    final list = await _decode(res) as List;
    return list
        .map((j) => Generation.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<Generation>> listGenerations(int petId, {int limit = 50}) async {
    final res = await _http.get(
      _uri('/generations', {'pet_id': petId, 'limit': limit}),
    );
    final list = await _decode(res) as List;
    return list
        .map((j) => Generation.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteGeneration(int genId) async {
    final res = await _http.delete(_uri('/generations/$genId'));
    await _decode(res);
  }

  Future<http.MultipartFile> _imageFile(String path) async {
    final lower = path.toLowerCase();
    MediaType? mt;
    if (lower.endsWith('.png')) {
      mt = MediaType('image', 'png');
    } else if (lower.endsWith('.webp')) {
      mt = MediaType('image', 'webp');
    } else {
      mt = MediaType('image', 'jpeg');
    }
    return http.MultipartFile.fromPath('file', path, contentType: mt);
  }

  /// 백엔드가 돌려준 상대 URL(`/uploads/...`)을 풀 URL로 합쳐줌.
  String resolveUrl(String pathOrUrl) {
    if (pathOrUrl.startsWith('http')) return pathOrUrl;
    return '$baseUrl$pathOrUrl';
  }

  void dispose() => _http.close();
}

/// 전역 싱글톤. 화면 어디서든 `api.createPet(...)` 식으로 호출.
final api = ApiClient();
