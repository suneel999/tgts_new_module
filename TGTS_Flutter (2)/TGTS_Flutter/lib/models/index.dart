enum Language { en, te }

enum UserRole { public, cadre, admin }

class ConstituencyRef {
  final int id;
  final int constituencyNumber;
  final String nameEn;
  final String nameTe;

  ConstituencyRef({
    required this.id,
    required this.constituencyNumber,
    required this.nameEn,
    required this.nameTe,
  });

  factory ConstituencyRef.fromJson(Map<String, dynamic> json) {
    return ConstituencyRef(
      id: json['id'] ?? json['constituencyNumber'] ?? 0,
      constituencyNumber: json['constituencyNumber'] ?? json['id'] ?? 0,
      nameEn: json['name_en'] ?? json['nameEn'] ?? '',
      nameTe: json['name_te'] ?? json['nameTe'] ?? json['name_en'] ?? json['nameEn'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'constituencyNumber': constituencyNumber,
      'name_en': nameEn,
      'name_te': nameTe,
    };
  }

  String getName(Language lang) {
    if (lang == Language.te && nameTe.isNotEmpty) {
      return nameTe;
    }
    return nameEn;
  }
}

class DistrictRef {
  final int id;
  final String nameEn;
  final String nameTe;
  final String? state;

  DistrictRef({
    required this.id,
    required this.nameEn,
    required this.nameTe,
    this.state,
  });

  factory DistrictRef.fromJson(Map<String, dynamic> json) {
    return DistrictRef(
      id: json['id'] ?? 0,
      nameEn: json['name_en'] ?? json['nameEn'] ?? '',
      nameTe: json['name_te'] ?? json['nameTe'] ?? json['name_en'] ?? json['nameEn'] ?? '',
      state: json['state'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_en': nameEn,
      'name_te': nameTe,
      if (state != null) 'state': state,
    };
  }

  String getName(Language lang) {
    if (lang == Language.te && nameTe.isNotEmpty) {
      return nameTe;
    }
    return nameEn;
  }
}

class MandalRef {
  final int id;
  final int districtId;
  final String nameEn;
  final String nameTe;
  final DistrictRef? districtRef;

  MandalRef({
    required this.id,
    required this.districtId,
    required this.nameEn,
    required this.nameTe,
    this.districtRef,
  });

  factory MandalRef.fromJson(Map<String, dynamic> json) {
    return MandalRef(
      id: json['id'] ?? 0,
      districtId: json['districtId'] ?? json['district_id'] ?? 0,
      nameEn: json['name_en'] ?? json['nameEn'] ?? '',
      nameTe: json['name_te'] ?? json['nameTe'] ?? json['name_en'] ?? json['nameEn'] ?? '',
      districtRef: json['districtRef'] != null 
          ? DistrictRef.fromJson(json['districtRef']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'districtId': districtId,
      'name_en': nameEn,
      'name_te': nameTe,
      if (districtRef != null) 'districtRef': districtRef!.toJson(),
    };
  }

  String getName(Language lang) {
    if (lang == Language.te && nameTe.isNotEmpty) {
      return nameTe;
    }
    return nameEn;
  }
}

class User {
  final String id;
  final String phone;
  final String name;
  final UserRole role;
  final String? region;
  final String? enrollmentDate;
  // Extended Member details
  final String? fullName;
  final String? fatherName;
  final String? dateOfBirth;
  final String? gender;
  final String? aadharNumber;
    final String? epicNumber;
    final String? epicFileUrl;
    final String? profilePictureUrl;
    final String? village;
  // New integer IDs (preferred)
  final int? districtId;
  final int? mandalId;
  // Legacy string fields (for backward compatibility)
  final String? mandal;
  final String? district;
  final String? parliamentConstituency; // Deprecated - use parliamentConstituencyRef
  final String? assemblyConstituency; // Deprecated - use assemblyConstituencyRef
  final int? parliamentConstituencyId;
  final int? assemblyConstituencyId;
  final ConstituencyRef? parliamentConstituencyRef;
  final ConstituencyRef? assemblyConstituencyRef;
  final DistrictRef? districtRef;
  final MandalRef? mandalRef;
  final String? fullAddress;
  final String? partyDesignation;
  final String? occupation;
  final bool? volunteerInterest;
  final bool? hasInsurance;
  final String? insuranceNumber;
  final String? status;

  User({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
    this.region,
    this.enrollmentDate,
    this.fullName,
    this.fatherName,
    this.dateOfBirth,
    this.gender,
    this.aadharNumber,
    this.epicNumber,
    this.epicFileUrl,
    this.profilePictureUrl,
    this.village,
    this.districtId,
    this.mandalId,
    this.mandal,
    this.district,
    this.parliamentConstituency,
    this.assemblyConstituency,
    this.parliamentConstituencyId,
    this.assemblyConstituencyId,
    this.parliamentConstituencyRef,
    this.assemblyConstituencyRef,
    this.districtRef,
    this.mandalRef,
    this.fullAddress,
    this.partyDesignation,
    this.occupation,
    this.volunteerInterest,
    this.hasInsurance,
    this.insuranceNumber,
    this.status,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phone: json['phone'],
      name: json['name'],
      role: UserRole.values.firstWhere((e) => e.name == json['role'], orElse: () => UserRole.public),
      region: json['region'],
      enrollmentDate: json['enrollmentDate'],
      fullName: json['fullName'],
      fatherName: json['fatherName'],
      dateOfBirth: json['dateOfBirth'],
      gender: json['gender'],
      aadharNumber: json['aadharNumber'],
      epicNumber: json['epicNumber'],
      epicFileUrl: json['epicFileUrl'],
      profilePictureUrl: json['profilePictureUrl'],
      village: json['village'],
      districtId: json['districtId'],
      mandalId: json['mandalId'],
      mandal: json['mandal'],
      district: json['district'],
      parliamentConstituency: json['parliamentConstituency'],
      assemblyConstituency: json['assemblyConstituency'],
      parliamentConstituencyId: json['parliamentConstituencyId'],
      assemblyConstituencyId: json['assemblyConstituencyId'],
      parliamentConstituencyRef: json['parliamentConstituencyRef'] != null 
          ? ConstituencyRef.fromJson(json['parliamentConstituencyRef']) 
          : null,
      assemblyConstituencyRef: json['assemblyConstituencyRef'] != null 
          ? ConstituencyRef.fromJson(json['assemblyConstituencyRef']) 
          : null,
      districtRef: json['districtRef'] != null 
          ? DistrictRef.fromJson(json['districtRef']) 
          : null,
      mandalRef: json['mandalRef'] != null 
          ? MandalRef.fromJson(json['mandalRef']) 
          : null,
      fullAddress: json['fullAddress'],
      partyDesignation: json['partyDesignation'],
      occupation: json['occupation'],
      volunteerInterest: json['volunteerInterest'],
      hasInsurance: json['hasInsurance'],
      insuranceNumber: json['insuranceNumber'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'role': role.name,
      'region': region,
      'enrollmentDate': enrollmentDate,
      'fullName': fullName,
      'fatherName': fatherName,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'aadharNumber': aadharNumber,
      'epicNumber': epicNumber,
      'epicFileUrl': epicFileUrl,
      'profilePictureUrl': profilePictureUrl,
      'village': village,
      'districtId': districtId,
      'mandalId': mandalId,
      'mandal': mandal,
      'district': district,
      'parliamentConstituency': parliamentConstituency,
      'assemblyConstituency': assemblyConstituency,
      'parliamentConstituencyId': parliamentConstituencyId,
      'assemblyConstituencyId': assemblyConstituencyId,
      'parliamentConstituencyRef': parliamentConstituencyRef?.toJson(),
      'assemblyConstituencyRef': assemblyConstituencyRef?.toJson(),
      'districtRef': districtRef?.toJson(),
      'mandalRef': mandalRef?.toJson(),
      'fullAddress': fullAddress,
      'partyDesignation': partyDesignation,
      'occupation': occupation,
      'volunteerInterest': volunteerInterest,
      'hasInsurance': hasInsurance,
      'insuranceNumber': insuranceNumber,
      'status': status,
    };
  }
}

class NewsLink {
  final String platform;
  final String url;

  NewsLink({
    required this.platform,
    required this.url,
  });

  factory NewsLink.fromJson(Map<String, dynamic> json) {
    return NewsLink(
      platform: json['platform'] ?? '',
      url: json['url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'url': url,
    };
  }
}

class NewsItem {
  final String id;
  final Map<String, String> title;
  final Map<String, String> description;
  final String image;
  final String date;
  final String category;
  final List<int>? districtIds;
  final List<int>? mandalIds;
  final List<int>? assemblyConstituencyIds;
  final List<int>? parliamentaryConstituencyIds;
  final List<NewsLink>? links;

  NewsItem({
    required this.id,
    required this.title,
    required this.description,
    required this.image,
    required this.date,
    required this.category,
    this.districtIds,
    this.mandalIds,
    this.assemblyConstituencyIds,
    this.parliamentaryConstituencyIds,
    this.links,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    List<NewsLink>? links;
    if (json['links'] != null && json['links'] is List) {
      links = (json['links'] as List)
          .map((link) => NewsLink.fromJson(link as Map<String, dynamic>))
          .toList();
    }
    
    return NewsItem(
      id: json['id'] ?? '',
      title: Map<String, String>.from(json['title'] ?? {'en': '', 'te': ''}),
      description: Map<String, String>.from(json['description'] ?? {'en': '', 'te': ''}),
      image: json['image'] ?? '',
      date: json['date'] ?? '',
      category: json['category'] ?? '',
      districtIds: (json['districtIds'] ?? json['district_ids']) != null
          ? List<int>.from(json['districtIds'] ?? json['district_ids'])
          : null,
      mandalIds: (json['mandalIds'] ?? json['mandal_ids']) != null
          ? List<int>.from(json['mandalIds'] ?? json['mandal_ids'])
          : null,
      assemblyConstituencyIds: (json['assemblyConstituencyIds'] ?? json['assembly_constituency_ids']) != null
          ? List<int>.from(json['assemblyConstituencyIds'] ?? json['assembly_constituency_ids'])
          : null,
      parliamentaryConstituencyIds: (json['parliamentaryConstituencyIds'] ?? json['parliamentary_constituency_ids'] ?? json['parliamentConstituencyIds'] ?? json['parliament_constituency_ids']) != null
          ? List<int>.from(json['parliamentaryConstituencyIds'] ?? json['parliamentary_constituency_ids'] ?? json['parliamentConstituencyIds'] ?? json['parliament_constituency_ids'])
          : null,
      links: links,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image': image,
      'date': date,
      'category': category,
    };
  }
}

class Event {
  final String id;
  final Map<String, String> title;
  final Map<String, String> description;
  final String date;
  final String time;
  final Map<String, String> location;
  final String? image;
  final int rsvpCount;
  final bool? isPublished;
  final bool? userHasRsvpd;
  final List<String> accessLevel;
  final List<int>? districtIds;
  final List<int>? mandalIds;
  final List<int>? assemblyConstituencyIds;
  final List<int>? parliamentaryConstituencyIds;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    this.image,
    required this.rsvpCount,
    this.isPublished,
    this.userHasRsvpd,
    required this.accessLevel,
    this.districtIds,
    this.mandalIds,
    this.assemblyConstituencyIds,
    this.parliamentaryConstituencyIds,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    // Handle accessLevel (camelCase from backend) or access_level (snake_case for backward compatibility)
    // Can be array or single role string
    // Store only the actual role, not hierarchical (e.g., 'cadre' becomes ['cadre'], not ['public', 'cadre'])
    // The hierarchical access logic (who can see what) is handled in the filtering mixin, not here
    List<String> accessLevelList = [];
    
    // Check camelCase first (what backend actually sends)
    dynamic accessLevelValue = json['accessLevel'] ?? json['access_level'];
    
    if (accessLevelValue != null) {
      if (accessLevelValue is List) {
        // If it's already an array, use it as-is (should be single-item array like ['cadre'])
        accessLevelList = accessLevelValue.map((e) => e.toString().toLowerCase()).toList();
      } else if (accessLevelValue is String) {
        // Single role string - store as single-item array with actual role only
        final role = accessLevelValue.toString().toLowerCase();
        // Validate and normalize the role
        if (role == 'admin' || role == 'cadre' || role == 'public') {
          accessLevelList = [role];
        } else {
          accessLevelList = ['public'];
        }
      }
    }
    if (accessLevelList.isEmpty) {
      accessLevelList = ['public'];
    }
    
    return Event(
      id: json['id']?.toString() ?? '',
      title: json['title'] != null 
          ? Map<String, String>.from(
              (json['title'] as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
            )
          : {'en': '', 'te': ''},
      description: json['description'] != null
          ? Map<String, String>.from(
              (json['description'] as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
            )
          : {'en': '', 'te': ''},
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      location: json['location'] != null
          ? Map<String, String>.from(
              (json['location'] as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
            )
          : {'en': '', 'te': ''},
      image: json['image']?.toString(),
      rsvpCount: json['rsvpCount'] is int ? json['rsvpCount'] : (int.tryParse(json['rsvpCount']?.toString() ?? '0') ?? 0),
      isPublished: json['isPublished'] is bool ? json['isPublished'] : null,
      userHasRsvpd: json['userHasRsvpd'] is bool ? json['userHasRsvpd'] : null,
      accessLevel: accessLevelList,
      districtIds: json['districtIds'] != null ? List<int>.from(json['districtIds']) : null,
      mandalIds: json['mandalIds'] != null ? List<int>.from(json['mandalIds']) : null,
      assemblyConstituencyIds: json['assemblyConstituencyIds'] != null ? List<int>.from(json['assemblyConstituencyIds']) : null,
      parliamentaryConstituencyIds: json['parliamentaryConstituencyIds'] != null ? List<int>.from(json['parliamentaryConstituencyIds']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'time': time,
      'location': location,
      'image': image,
      'rsvpCount': rsvpCount,
      if (isPublished != null) 'isPublished': isPublished,
      'access_level': accessLevel,
    };
  }
}

class MediaItem {
  final String id;
  final String type; // 'photo' or 'video'
  final String url;
  final String? thumbnail;
  final Map<String, String> title;
  final String date;
  final List<String> accessLevel;
  final List<int>? districtIds;
  final List<int>? mandalIds;
  final List<int>? assemblyConstituencyIds;
  final List<int>? parliamentaryConstituencyIds;

  MediaItem({
    required this.id,
    required this.type,
    required this.url,
    this.thumbnail,
    required this.title,
    required this.date,
    required this.accessLevel,
    this.districtIds,
    this.mandalIds,
    this.assemblyConstituencyIds,
    this.parliamentaryConstituencyIds,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    // Handle access_level - backend sends single-item array like ['cadre'] or ['public']
    // Prefer access_level_role if available (single role from backend)
    String actualRole = 'public';
    
    if (json['access_level_role'] != null) {
      // Backend provides the actual role
      actualRole = json['access_level_role'].toString().toLowerCase();
    } else if (json['access_level'] != null) {
      if (json['access_level'] is List) {
        // Backend should now return single-item array like ['cadre'], extract the role
        final levels = (json['access_level'] as List).map((e) => e.toString().toLowerCase()).toList();
        if (levels.isNotEmpty) {
          // Get the highest level (in case of multiple, though shouldn't happen now)
          if (levels.contains('admin')) {
            actualRole = 'admin';
          } else if (levels.contains('cadre')) {
            actualRole = 'cadre';
          } else {
            actualRole = 'public';
          }
        }
      } else if (json['access_level'] is String) {
        actualRole = json['access_level'].toString().toLowerCase();
      }
    }
    
    // Store as single-item array with actual role (not hierarchical)
    // The hierarchical access logic is handled in the filter, not here
    List<String> accessLevelList = [actualRole];
    
    return MediaItem(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      url: json['url'] ?? '',
      thumbnail: json['thumbnail'],
      title: Map<String, String>.from(json['title'] ?? {'en': '', 'te': ''}),
      date: json['date'] ?? '',
      accessLevel: accessLevelList,
      districtIds: json['districtIds'] != null ? List<int>.from(json['districtIds']) : null,
      mandalIds: json['mandalIds'] != null ? List<int>.from(json['mandalIds']) : null,
      assemblyConstituencyIds: json['assemblyConstituencyIds'] != null ? List<int>.from(json['assemblyConstituencyIds']) : null,
      parliamentaryConstituencyIds: json['parliamentaryConstituencyIds'] != null ? List<int>.from(json['parliamentaryConstituencyIds']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'url': url,
      'thumbnail': thumbnail ?? '',
      'title': title,
      'date': date,
      'access_level': accessLevel, // Include access level for caching
      'access_level_role': accessLevel.isNotEmpty ? accessLevel.first : 'public', // Include for compatibility
    };
  }
}

class Document {
  final String id;
  final String titleEn;
  final String? titleTe;
  final String category;
  final String date;
  final String url;
  final String fileType;
  final int fileSize;
  final List<String> accessLevel;
  final bool isPublished;
  final List<int>? districtIds;
  final List<int>? mandalIds;
  final List<int>? assemblyConstituencyIds;
  final List<int>? parliamentaryConstituencyIds;

  Document({
    required this.id,
    required this.titleEn,
    this.titleTe,
    required this.category,
    required this.date,
    required this.url,
    required this.fileType,
    required this.fileSize,
    required this.accessLevel,
    required this.isPublished,
    this.districtIds,
    this.mandalIds,
    this.assemblyConstituencyIds,
    this.parliamentaryConstituencyIds,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    // Handle file_url - check for null, "None", or empty string
    String? fileUrl = json['file_url'] ?? json['url'];
    if (fileUrl == null || fileUrl == 'None' || fileUrl == 'null' || fileUrl.toString().trim().isEmpty) {
      fileUrl = null;
    } else {
      fileUrl = fileUrl.toString().trim();
    }
    
    return Document(
      id: json['id']?.toString() ?? '',
      titleEn: json['title_en'] ?? '',
      titleTe: json['title_te'],
      category: json['category'] ?? '',
      date: json['created_at'] ?? json['date'] ?? '',
      url: fileUrl ?? '', // Will be empty string if null, but we'll validate before use
      fileType: json['file_type'] ?? 'pdf',
      fileSize: json['file_size'] ?? 0,
      accessLevel: (json['access_level'] as List<dynamic>?)
          ?.map((role) => role.toString())
          .toList() ?? [],
      isPublished: json['is_published'] ?? false,
      districtIds: json['districtIds'] != null ? List<int>.from(json['districtIds']) : null,
      mandalIds: json['mandalIds'] != null ? List<int>.from(json['mandalIds']) : null,
      assemblyConstituencyIds: json['assemblyConstituencyIds'] != null ? List<int>.from(json['assemblyConstituencyIds']) : null,
      parliamentaryConstituencyIds: json['parliamentaryConstituencyIds'] != null ? List<int>.from(json['parliamentaryConstituencyIds']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title_en': titleEn,
      'title_te': titleTe,
      'category': category,
      'created_at': date,
      'file_url': url,
      'file_type': fileType,
      'file_size': fileSize,
      'access_level': accessLevel,
      'is_published': isPublished,
    };
  }

  // Helper getter for title based on language
  String getTitle(Language lang) {
    if (lang == Language.te && titleTe != null && titleTe!.isNotEmpty) {
      return titleTe!;
    }
    return titleEn;
  }
}
