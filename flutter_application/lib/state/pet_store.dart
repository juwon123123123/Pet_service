import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/models.dart';

/// 현재 선택된 펫과 보호자 이름을 보관하는 단순 전역 상태.
/// - SharedPreferences에 pet_id / guardian_name 저장
/// - 한 번에 한 마리만 다루는 MVP 가정
class PetStore extends ChangeNotifier {
  static const _kPetId = 'pet_id';
  static const _kGuardian = 'guardian_name';

  Pet? _pet;
  String _guardianName = '';

  Pet? get pet => _pet;
  String get guardianName => _guardianName;
  bool get hasPet => _pet != null;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _guardianName = sp.getString(_kGuardian) ?? '';
    final id = sp.getInt(_kPetId);
    if (id != null) {
      try {
        _pet = await api.getPet(id);
      } catch (e) {
        debugPrint('PetStore.load: pet $id 로드 실패: $e');
        await sp.remove(_kPetId);
        _pet = null;
      }
    }
    notifyListeners();
  }

  Future<void> setGuardianName(String name) async {
    _guardianName = name;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kGuardian, name);
    notifyListeners();
  }

  Future<void> setPet(Pet pet) async {
    _pet = pet;
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kPetId, pet.id);
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_pet == null) return;
    _pet = await api.getPet(_pet!.id);
    notifyListeners();
  }

  Future<void> clear() async {
    _pet = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kPetId);
    notifyListeners();
  }
}

final petStore = PetStore();
