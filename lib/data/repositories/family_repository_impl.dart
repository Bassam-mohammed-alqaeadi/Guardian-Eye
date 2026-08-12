import 'package:guardian_ai/domain/entities/family_entity.dart';
import 'package:guardian_ai/domain/repositories/family_repository.dart';

class FamilyRepositoryImpl implements FamilyRepository {
  @override
  Future<FamilyEntity> getFamilyDetails(String familyId) async {
    // Mock data for initial skeleton
    await Future.delayed(const Duration(milliseconds: 500));
    return FamilyEntity(
      id: familyId,
      familyName: 'عائلة أحمد (Al-Ahmad Family)',
      members: [
        FamilyMember(
          id: '1',
          name: 'أحمد (الأب)',
          role: MemberRole.primaryParent,
          deviceRole: DeviceRole.parentDevice,
          avatarUrl: '',
          permissions: ['all'],
        ),
        FamilyMember(
          id: '2',
          name: 'سارة (الأم)',
          role: MemberRole.parent,
          deviceRole: DeviceRole.parentDevice,
          avatarUrl: '',
          permissions: ['view', 'manage_screen_time'],
        ),
        FamilyMember(
          id: '3',
          name: 'عمر (الابن - 12 سنة)',
          role: MemberRole.child,
          deviceRole: DeviceRole.childDevice,
          avatarUrl: '',
          permissions: ['child_limited'],
        ),
      ],
      createdAt: '2026-01-01',
    );
  }

  @override
  Future<void> createFamily(String familyName, FamilyMember admin) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> joinFamily(String inviteCode, FamilyMember member) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
