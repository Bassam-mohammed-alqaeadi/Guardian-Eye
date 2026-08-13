import 'package:guardian_ai/domain/entities/family_entity.dart';

abstract class FamilyRepository {
  Future<FamilyEntity> getFamilyDetails(String familyId);
  Future<void> createFamily(String familyName, FamilyMember admin);
  Future<void> joinFamily(String inviteCode, FamilyMember member);
}
