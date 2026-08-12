import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/domain/family_authorization.dart';
import 'package:guardian_ai/domain/guardian_models.dart';

void main() {
  test('family and child drafts reject empty input before persistence', () {
    expect(
        const FamilyDraft(familyName: '  ', primaryParentName: 'Parent')
            .isValid,
        isFalse);
    expect(
        const FamilyDraft(
                familyName: 'Guardian family', primaryParentName: 'Parent')
            .isValid,
        isTrue);
    expect(const ChildDraft(displayName: '').isValid, isFalse);
    expect(const ChildDraft(displayName: 'Child').isValid, isTrue);
  });

  test('child role cannot manage family, device, or incident acknowledgement',
      () {
    const authorization = FamilyAuthorization();
    expect(authorization.canManageFamily(FamilyRole.child), isFalse);
    expect(
        authorization.canManageDevice(
            actorRole: FamilyRole.child,
            actorMemberId: 'child',
            ownerMemberId: 'parent'),
        isFalse);
    expect(authorization.canAcknowledgeIncident(FamilyRole.child), isFalse);
  });

  test(
      'device owner and primary parent are authorized while unrelated parent is denied',
      () {
    const authorization = FamilyAuthorization();
    expect(
        authorization.canManageDevice(
            actorRole: FamilyRole.parent,
            actorMemberId: 'owner',
            ownerMemberId: 'owner'),
        isTrue);
    expect(
        authorization.canManageDevice(
            actorRole: FamilyRole.primaryParent,
            actorMemberId: 'primary',
            ownerMemberId: 'owner'),
        isTrue);
    expect(
        authorization.canManageDevice(
            actorRole: FamilyRole.parent,
            actorMemberId: 'other',
            ownerMemberId: 'owner'),
        isFalse);
  });
}
