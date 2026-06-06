import 'package:intl/intl.dart';

final _date = DateFormat('yyyy-MM-dd');

class Pet {
  final int id;
  final String name;
  final String species; // dog | cat
  final String? breed;
  final DateTime birthDate;
  final String sex; // male | female
  final bool neutered;
  final double? weightKg;
  final int ageWeeks;
  final double ageMonths;

  final String? photoUrl;

  Pet({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.birthDate,
    required this.sex,
    required this.neutered,
    required this.weightKg,
    required this.ageWeeks,
    required this.ageMonths,
    required this.photoUrl,
  });

  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
        id: j['id'] as int,
        name: j['name'] as String,
        species: j['species'] as String,
        breed: j['breed'] as String?,
        birthDate: DateTime.parse(j['birth_date'] as String),
        sex: j['sex'] as String,
        neutered: j['neutered'] as bool,
        weightKg: (j['weight_kg'] as num?)?.toDouble(),
        ageWeeks: j['age_weeks'] as int,
        ageMonths: (j['age_months'] as num).toDouble(),
        photoUrl: j['photo_url'] as String?,
      );

  String get speciesKo => species == 'dog' ? '강아지' : '고양이';
  String get sexKo => sex == 'male' ? '남아' : '여아';
  String get ageKo {
    if (ageWeeks < 16) return '생후 $ageWeeks주';
    return '생후 ${ageMonths.toStringAsFixed(0)}개월';
  }
}

class PetCreate {
  final String name;
  final String species;
  final String? breed;
  final DateTime birthDate;
  final String sex;
  final bool neutered;
  final double? weightKg;

  PetCreate({
    required this.name,
    required this.species,
    required this.breed,
    required this.birthDate,
    required this.sex,
    required this.neutered,
    required this.weightKg,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'species': species,
        if (breed != null && breed!.isNotEmpty) 'breed': breed,
        'birth_date': _date.format(birthDate),
        'sex': sex,
        'neutered': neutered,
        if (weightKg != null) 'weight_kg': weightKg,
      };
}

class Event {
  final int id;
  final int petId;
  final String title;
  final String category;
  final DateTime dueDate;
  final bool recurring;
  final int? intervalDays;
  final String sourceDocId;
  final String? notes;
  final bool done;

  Event({
    required this.id,
    required this.petId,
    required this.title,
    required this.category,
    required this.dueDate,
    required this.recurring,
    required this.intervalDays,
    required this.sourceDocId,
    required this.notes,
    required this.done,
  });

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as int,
        petId: j['pet_id'] as int,
        title: j['title'] as String,
        category: j['category'] as String,
        dueDate: DateTime.parse(j['due_date'] as String),
        recurring: j['recurring'] as bool,
        intervalDays: j['interval_days'] as int?,
        sourceDocId: j['source_doc_id'] as String,
        notes: j['notes'] as String?,
        done: j['done'] as bool,
      );
}

class Citation {
  final String docId;
  final String title;
  final String category;
  final String? source;
  final int? year;
  final int? page;
  final String? docType;

  Citation({
    required this.docId,
    required this.title,
    required this.category,
    required this.source,
    required this.year,
    required this.page,
    required this.docType,
  });

  factory Citation.fromJson(Map<String, dynamic> j) => Citation(
        docId: j['doc_id'] as String,
        title: j['title'] as String? ?? '',
        category: j['category'] as String? ?? '',
        source: j['source'] as String?,
        year: j['year'] as int?,
        page: j['page'] as int?,
        docType: j['doc_type'] as String?,
      );

  String get label {
    final parts = <String>[];
    if (source != null && source!.isNotEmpty) parts.add(source!);
    if (year != null && year != 0) parts.add('$year');
    if (page != null) parts.add('p.$page');
    if (parts.isEmpty) return title;
    return parts.join(' ');
  }
}

class Guide {
  final int petId;
  final String summary;
  final List<GuideSection> sections;
  final List<Citation> citations;
  final DateTime generatedAt;

  Guide({
    required this.petId,
    required this.summary,
    required this.sections,
    required this.citations,
    required this.generatedAt,
  });

  factory Guide.fromJson(Map<String, dynamic> j) => Guide(
        petId: j['pet_id'] as int,
        summary: j['summary'] as String,
        sections: (j['sections'] as List)
            .map((s) => GuideSection.fromJson(s as Map<String, dynamic>))
            .toList(),
        citations: (j['citations'] as List)
            .map((c) => Citation.fromJson(c as Map<String, dynamic>))
            .toList(),
        generatedAt: DateTime.parse(j['generated_at'] as String),
      );
}

class GuideSection {
  final String topic;
  final String advice;
  final List<String> citations;

  GuideSection({
    required this.topic,
    required this.advice,
    required this.citations,
  });

  factory GuideSection.fromJson(Map<String, dynamic> j) => GuideSection(
        topic: j['topic'] as String? ?? '',
        advice: j['advice'] as String? ?? '',
        citations: ((j['citations'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

class ChatAnswer {
  final String answer;
  final List<Citation> citations;

  ChatAnswer({required this.answer, required this.citations});

  factory ChatAnswer.fromJson(Map<String, dynamic> j) => ChatAnswer(
        answer: j['answer'] as String,
        citations: (j['citations'] as List)
            .map((c) => Citation.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class Product {
  final int id;
  final String name;
  final String species; // dog | cat | both
  final String category;
  final int price;
  final String imageUrl; // 백엔드 상대경로 (예: /uploads/products/cloth1.jpg)
  final List<String> tags;
  final double? sizeMinKg;
  final double? sizeMaxKg;

  Product({
    required this.id,
    required this.name,
    required this.species,
    required this.category,
    required this.price,
    required this.imageUrl,
    required this.tags,
    required this.sizeMinKg,
    required this.sizeMaxKg,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as int,
        name: j['name'] as String,
        species: j['species'] as String,
        category: j['category'] as String,
        price: j['price'] as int,
        imageUrl: j['image_url'] as String? ?? '',
        tags: ((j['tags'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        sizeMinKg: (j['size_min_kg'] as num?)?.toDouble(),
        sizeMaxKg: (j['size_max_kg'] as num?)?.toDouble(),
      );
}

class Generation {
  final int id;
  final int petId;
  final int productId;
  final String sourcePhotoUrl;
  final String? resultUrl;
  final String status; // pending | done | failed
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;

  Generation({
    required this.id,
    required this.petId,
    required this.productId,
    required this.sourcePhotoUrl,
    required this.resultUrl,
    required this.status,
    required this.error,
    required this.createdAt,
    required this.completedAt,
  });

  factory Generation.fromJson(Map<String, dynamic> j) => Generation(
        id: j['id'] as int,
        petId: j['pet_id'] as int,
        productId: j['product_id'] as int,
        sourcePhotoUrl: j['source_photo_url'] as String,
        resultUrl: j['result_url'] as String?,
        status: j['status'] as String,
        error: j['error'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        completedAt: j['completed_at'] != null
            ? DateTime.parse(j['completed_at'] as String)
            : null,
      );

  bool get isDone => status == 'done';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
}
