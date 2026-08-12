enum MemberRole { primaryParent, parent, spouse, coParent, child }

enum DeviceRole {
  unconfigured,
  parentDevice,
  childDevice,
  spouseDevice,
  coParentDevice
}

class FamilyMember {
  final String id;
  final String name;
  final MemberRole role;
  final DeviceRole deviceRole;
  final String avatarUrl;
  final List<String> permissions;

  FamilyMember({
    required this.id,
    required this.name,
    required this.role,
    required this.deviceRole,
    required this.avatarUrl,
    required this.permissions,
  });
}

class FamilyEntity {
  final String id;
  final String familyName;
  final List<FamilyMember> members;
  final String createdAt;

  FamilyEntity({
    required this.id,
    required this.familyName,
    required this.members,
    required this.createdAt,
  });
}
