import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/index.dart';
import '../../config/api_config.dart';
import '../../utils/app_colors.dart';
import '../../utils/lang_ext.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for all editable fields
  late TextEditingController _nameController;
  late TextEditingController _fullNameController;
  late TextEditingController _fatherNameController;
  late TextEditingController _dateOfBirthController;
  late TextEditingController _regionController;
  late TextEditingController _villageController;
  late TextEditingController _assemblyConstituencyController;
  late TextEditingController _parliamentConstituencyController;
  late TextEditingController _fullAddressController;
  late TextEditingController _partyDesignationController;
  late TextEditingController _occupationController;
  late TextEditingController _aadharNumberController;
  late TextEditingController _epicNumberController;
  late TextEditingController _insuranceNumberController;
  
  String? _gender;
  bool _volunteerInterest = false;
  bool _hasInsurance = false;
  
  // Profile image
  File? _profileImage;
  String? _profilePictureUrl; // URL from server
  final ImagePicker _imagePicker = ImagePicker();
  
  // District and Mandal dropdowns
  final ApiService _apiService = ApiService();
  List<DistrictRef> _districts = [];
  List<MandalRef> _mandals = [];
  DistrictRef? _selectedDistrict;
  MandalRef? _selectedMandal;
  bool _loadingDistricts = false;
  bool _loadingMandals = false;
  
  // Constituency dropdowns
  List<Map<String, dynamic>> _constituencies = [];
  List<Map<String, dynamic>> _assemblyConstituencies = [];
  int? _selectedParliamentConstituencyId;
  int? _selectedAssemblyConstituencyId;
  bool _loadingConstituencies = false;
  bool _loadingAssemblyConstituencies = false;
  int? _lastLoadedParliamentConstituencyId; // Track which parliament constituency was loaded
  bool _controllersInitialized = false; // Track if controllers have been initialized

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Load districts and constituencies first, then load user profile
    await Future.wait([
      _loadDistricts(),
      _loadConstituencies(),
    ]);
    await _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final authService = context.read<AuthService>();
    // Refresh profile to get latest data including constituency refs
    await authService.refreshProfile();
    final user = authService.currentUser;
    if (user != null) {
      await _initializeControllers(user);
    }
  }

  Future<void> _loadDistricts() async {
    if (!mounted) return;
    setState(() {
      _loadingDistricts = true;
    });

    try {
      // Try with filters first
      var result = await _apiService.getDistricts(
        state: 'Telangana',
        isActive: true,
      );

      // If that fails or returns empty, try without filters
      if (result['success'] != true || 
          result['data'] == null || 
          (result['data'] is List && (result['data'] as List).isEmpty)) {
        result = await _apiService.getDistricts();
      }

      if (!mounted) return;
      if (result['success'] == true && result['data'] != null) {
        dynamic data = result['data'];
        
        // The API returns a list directly
        if (data is List && data.isNotEmpty) {
          setState(() {
            _districts = data.map<DistrictRef>((item) {
              return DistrictRef.fromJson(item);
            }).toList();
            _loadingDistricts = false;
          });
        } else {
          setState(() {
            _districts = [];
            _loadingDistricts = false;
          });
        }
      } else {
        setState(() {
          _districts = [];
          _loadingDistricts = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _districts = [];
        _loadingDistricts = false;
      });
    }
  }

  Future<void> _loadConstituencies() async {
    if (!mounted) return;
    setState(() {
      _loadingConstituencies = true;
    });

    try {
      final result = await _apiService.getConstituencies(
        state: 'Telangana',
        isActive: true,
      );

      if (!mounted) return;
      if (result['success'] == true && result['data'] != null) {
        final List<dynamic> data = result['data'];
        setState(() {
          _constituencies = data.map<Map<String, dynamic>>((item) {
            // ID is now the constituency_number (integer) - same as membership screen
            final id = item['id'] ?? item['constituencyNumber'];
            return {
              'id': id is int ? id : int.tryParse(id.toString()) ?? item['constituencyNumber'],
              'name_en': item['name_en'] ?? item['nameEn'] ?? item['name']?['en'] ?? '',
              'name_te': item['name_te'] ?? item['nameTe'] ?? item['name']?['te'] ?? item['name_en'] ?? '',
            };
          }).toList();
          _loadingConstituencies = false;
        });
      } else {
        setState(() {
          _loadingConstituencies = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingConstituencies = false;
      });
      // Silently fail - user can still use the form
    }
  }

  Future<void> _loadAssemblyConstituencies({int? parliamentConstituencyId}) async {
    if (parliamentConstituencyId == null) {
      if (!mounted) return;
      setState(() {
        _assemblyConstituencies = [];
        _selectedAssemblyConstituencyId = null;
        _lastLoadedParliamentConstituencyId = null;
      });
      return;
    }

    // Don't reload if we already have the data for this parliament constituency
    if (_lastLoadedParliamentConstituencyId == parliamentConstituencyId && _assemblyConstituencies.isNotEmpty) {
      return;
    }

    // Don't reload if already loading
    if (_loadingAssemblyConstituencies) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _loadingAssemblyConstituencies = true;
      _selectedAssemblyConstituencyId = null;
    });

    try {
      final result = await _apiService.getAssemblyConstituencies(
        parliamentConstituencyId: parliamentConstituencyId.toString(),
        state: 'Telangana',
        isActive: true,
      );

      if (!mounted) return;
      if (result['success'] == true && result['data'] != null) {
        final List<dynamic> data = result['data'];
        if (!mounted) return;
        setState(() {
          _assemblyConstituencies = data.map<Map<String, dynamic>>((item) {
            final id = item['id'] ?? item['constituencyNumber'];
            return {
              'id': id is int ? id : int.tryParse(id.toString()) ?? item['constituencyNumber'],
              'name_en': item['name_en'] ?? item['name']?['en'] ?? '',
              'name_te': item['name_te'] ?? item['name']?['te'] ?? item['name_en'] ?? '',
            };
          }).toList();
          _loadingAssemblyConstituencies = false;
          _lastLoadedParliamentConstituencyId = parliamentConstituencyId; // Track what we loaded
        });
      } else {
        setState(() {
          _loadingAssemblyConstituencies = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAssemblyConstituencies = false;
      });
    }
  }

  Future<void> _loadMandals(int? districtId) async {
    if (districtId == null) {
      if (!mounted) return;
      setState(() {
        _mandals = [];
        _selectedMandal = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _loadingMandals = true;
      _selectedMandal = null; // Reset mandal when district changes
    });

    try {
      final result = await _apiService.getMandals(
        districtId: districtId,
        isActive: true,
      );

      if (!mounted) return;
      if (result['success'] == true && result['data'] != null) {
        final List<dynamic> data = result['data'];
        setState(() {
          _mandals = data.map<MandalRef>((item) {
            return MandalRef.fromJson(item);
          }).toList();
          _loadingMandals = false;
        });
      } else {
        setState(() {
          _loadingMandals = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMandals = false;
      });
    }
  }

  Future<void> _initializeControllers(User user) async {
    _nameController = TextEditingController(text: user.name);
    _fullNameController = TextEditingController(text: user.fullName ?? '');
    _fatherNameController = TextEditingController(text: user.fatherName ?? '');
    _dateOfBirthController = TextEditingController(text: user.dateOfBirth ?? '');
    _regionController = TextEditingController(text: user.region ?? '');
    _villageController = TextEditingController(text: user.village ?? '');
    _profilePictureUrl = user.profilePictureUrl; // Load profile picture URL
    
    // Ensure districts are loaded before trying to set selected district
    if (_districts.isEmpty && !_loadingDistricts) {
      await _loadDistricts();
    }
    
    // Wait for districts to load if they're currently loading (with timeout)
    int waitCount = 0;
    while (_loadingDistricts && waitCount < 50) { // Max 5 seconds wait
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }
    
    // Initialize district and mandal from user data
    if (user.districtId != null) {
      // First try to use districtRef if available
      if (user.districtRef != null) {
        _selectedDistrict = user.districtRef;
      } else if (_districts.isNotEmpty) {
        // Try to find district from loaded list
        try {
          _selectedDistrict = _districts.firstWhere(
            (d) => d.id == user.districtId,
          );
        } catch (e) {
          // District not found in list, leave as null
          _selectedDistrict = null;
        }
      }
      
      // Load mandals for the selected district
      if (_selectedDistrict != null && user.districtId != null) {
        await _loadMandals(user.districtId);
        
        // Wait for mandals to load if they're currently loading (with timeout)
        int mandalWaitCount = 0;
        while (_loadingMandals && mandalWaitCount < 50) { // Max 5 seconds wait
          await Future.delayed(const Duration(milliseconds: 100));
          mandalWaitCount++;
        }
        
        // After mandals are loaded, set the selected mandal
        if (user.mandalRef != null) {
          _selectedMandal = user.mandalRef;
        } else if (user.mandalId != null && _mandals.isNotEmpty) {
          try {
            _selectedMandal = _mandals.firstWhere(
              (m) => m.id == user.mandalId,
            );
          } catch (e) {
            // Mandal not found in list, leave as null
            _selectedMandal = null;
          }
        }
      }
    }
    
    // Update state to reflect the selected district and mandal
    if (mounted) {
      setState(() {
        // State is already updated in the setters above, but we call setState to trigger rebuild
      });
    }
    // Initialize constituency IDs
    if (user.parliamentConstituencyId != null) {
      _selectedParliamentConstituencyId = user.parliamentConstituencyId;
      await _loadAssemblyConstituencies(parliamentConstituencyId: user.parliamentConstituencyId);
    }
    if (user.assemblyConstituencyId != null) {
      _selectedAssemblyConstituencyId = user.assemblyConstituencyId;
    }
    
    // Initialize text controllers for display (read-only)
    _assemblyConstituencyController = TextEditingController(
      text: user.assemblyConstituencyRef != null 
          ? user.assemblyConstituencyRef!.nameEn
          : (user.assemblyConstituency ?? '')
    );
    _parliamentConstituencyController = TextEditingController(
      text: user.parliamentConstituencyRef != null 
          ? user.parliamentConstituencyRef!.nameEn
          : (user.parliamentConstituency ?? '')
    );
    _fullAddressController = TextEditingController(text: user.fullAddress ?? '');
    _partyDesignationController = TextEditingController(text: user.partyDesignation ?? '');
    _occupationController = TextEditingController(text: user.occupation ?? '');
    _aadharNumberController = TextEditingController(text: user.aadharNumber ?? '');
    _epicNumberController = TextEditingController(text: user.epicNumber ?? '');
    _insuranceNumberController = TextEditingController(text: user.insuranceNumber ?? '');
    
    _gender = user.gender;
    _volunteerInterest = user.volunteerInterest ?? false;
    _hasInsurance = user.hasInsurance ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fullNameController.dispose();
    _fatherNameController.dispose();
    _dateOfBirthController.dispose();
    _regionController.dispose();
    _villageController.dispose();
    _assemblyConstituencyController.dispose();
    _parliamentConstituencyController.dispose();
    _fullAddressController.dispose();
    _partyDesignationController.dispose();
    _occupationController.dispose();
    _aadharNumberController.dispose();
    _epicNumberController.dispose();
    _insuranceNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirthController.text.isNotEmpty
          ? DateTime.tryParse(_dateOfBirthController.text) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _dateOfBirthController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null && mounted) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.lang == Language.en
                  ? 'Failed to pick image: ${e.toString()}'
                  : 'చిత్రాన్ని ఎంచుకోవడంలో విఫలమైంది: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takeProfilePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null && mounted) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.lang == Language.en
                  ? 'Failed to take photo: ${e.toString()}'
                  : 'ఫోటో తీయడంలో విఫలమైంది: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    final lang = context.lang;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            lang == Language.en ? 'Select Image Source' : 'చిత్ర మూలాన్ని ఎంచుకోండి',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(lang == Language.en ? 'Gallery' : 'గ్యాలరీ'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickProfileImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(lang == Language.en ? 'Camera' : 'కెమెరా'),
                onTap: () {
                  Navigator.of(context).pop();
                  _takeProfilePhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSaving = true;
    });

    final authService = context.read<AuthService>();
    String? profilePictureUrl;
    
    // Upload profile picture if one is selected
    if (_profileImage != null && authService.accessToken != null) {
      try {
        final uploadResult = await _apiService.uploadProfilePicture(
          authService.accessToken!,
          _profileImage!,
        );
        
        if (uploadResult['success'] && uploadResult['data'] != null) {
          profilePictureUrl = uploadResult['data']['url'];
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  uploadResult['message'] ?? (context.lang == Language.en
                      ? 'Failed to upload profile picture'
                      : 'ప్రొఫైల్ ఫోటో అప్‌లోడ్ చేయడంలో విఫలమైంది'),
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.lang == Language.en
                    ? 'Failed to upload profile picture: ${e.toString()}'
                    : 'ప్రొఫైల్ ఫోటో అప్‌లోడ్ చేయడంలో విఫలమైంది: ${e.toString()}',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
    
    final profileData = <String, dynamic>{
      'name': _nameController.text.trim(),
      if (_fullNameController.text.trim().isNotEmpty) 'fullName': _fullNameController.text.trim(),
      if (_fatherNameController.text.trim().isNotEmpty) 'fatherName': _fatherNameController.text.trim(),
      if (_dateOfBirthController.text.trim().isNotEmpty) 'dateOfBirth': _dateOfBirthController.text.trim(),
      if (_gender != null && _gender!.isNotEmpty) 'gender': _gender,
      if (_regionController.text.trim().isNotEmpty) 'region': _regionController.text.trim(),
      if (_villageController.text.trim().isNotEmpty) 'village': _villageController.text.trim(),
      if (_selectedDistrict != null) 'districtId': _selectedDistrict!.id,
      if (_selectedMandal != null) 'mandalId': _selectedMandal!.id,
      if (_selectedParliamentConstituencyId != null) 'parliamentConstituencyId': _selectedParliamentConstituencyId,
      if (_selectedAssemblyConstituencyId != null) 'assemblyConstituencyId': _selectedAssemblyConstituencyId,
      if (_fullAddressController.text.trim().isNotEmpty) 'fullAddress': _fullAddressController.text.trim(),
      if (_partyDesignationController.text.trim().isNotEmpty) 'partyDesignation': _partyDesignationController.text.trim(),
      if (_occupationController.text.trim().isNotEmpty) 'occupation': _occupationController.text.trim(),
      if (_aadharNumberController.text.trim().isNotEmpty) 'aadharNumber': _aadharNumberController.text.trim(),
      if (_epicNumberController.text.trim().isNotEmpty) 'epicNumber': _epicNumberController.text.trim(),
      'volunteerInterest': _volunteerInterest,
      'hasInsurance': _hasInsurance,
      if (_hasInsurance && _insuranceNumberController.text.trim().isNotEmpty) 'insuranceNumber': _insuranceNumberController.text.trim(),
      if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
    };

    final result = await authService.updateProfile(profileData);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      if (result['success']) {
        // Refresh profile to get updated profile picture URL
        await authService.refreshProfile();
        final updatedUser = authService.currentUser;
        if (updatedUser != null) {
          setState(() {
            _profilePictureUrl = updatedUser.profilePictureUrl;
            _profileImage = null; // Clear local image after successful upload
          });
        }
        setState(() {
          _isEditing = false;
          _controllersInitialized = false; // Reset to allow re-initialization after update
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.lang == Language.en
                  ? 'Profile updated successfully'
                  : 'ప్రొఫైల్ విజయవంతంగా నవీకరించబడింది',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? (context.lang == Language.en
                  ? 'Failed to update profile'
                  : 'ప్రొఫైల్ నవీకరించడంలో విఫలమైంది'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getFullImageUrl(String url) {
    // If URL is already a full URL (starts with http/https), return as is
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    // If URL starts with /uploads, prepend base URL
    if (url.startsWith('/uploads/')) {
      return '${ApiConfig.baseUrl.replaceAll('/api', '')}$url';
    }
    // Otherwise, assume it's an S3 URL or full URL already
    return url;
  }

  Future<void> _cancelEdit() async {
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      _controllersInitialized = false; // Reset flag to allow re-initialization
      await _initializeControllers(user);
      _controllersInitialized = true;
    }
    if (!mounted) return;
    setState(() {
      _isEditing = false;
      _profileImage = null; // Reset profile image on cancel
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Reinitialize controllers if user data changes (only once, not on every rebuild)
    if (!_isEditing && !_controllersInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted && !_controllersInitialized) {
          _controllersInitialized = true;
          await _initializeControllers(user);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lang == Language.en ? 'My Profile' : 'నా ప్రొఫైల్',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                // Re-initialize controllers with current user data when entering edit mode
                final currentUser = authService.currentUser;
                if (currentUser != null) {
                  await _initializeControllers(currentUser);
                }
                if (!mounted) return;
                setState(() {
                  _isEditing = true;
                  // Ensure state is updated with selected district and mandal
                });
              },
              tooltip: lang == Language.en ? 'Edit Profile' : 'ప్రొఫైల్ సవరించు',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => authService.refreshProfile(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIdentityCard(user, lang),
                const SizedBox(height: 24),
                if (_isEditing) ...[
                  _buildEditForm(lang),
                  const SizedBox(height: 16),
                  _buildActionButtons(lang),
                ] else
                  _buildInfoSection(context, user, lang),
                const SizedBox(height: 32),
                if (!_isEditing)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      icon: const Icon(Icons.logout),
                      label: Text(
                        lang == Language.en ? 'Logout' : 'లాగ్అవుట్',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityCard(User user, Language lang) {
    // Get constituency names
    String? parliamentConstituency;
    String? assemblyConstituency;
    
    if (user.parliamentConstituencyRef != null) {
      parliamentConstituency = user.parliamentConstituencyRef!.getName(lang);
    } else if (user.parliamentConstituency != null && user.parliamentConstituency!.isNotEmpty) {
      parliamentConstituency = user.parliamentConstituency;
    }
    
    if (user.assemblyConstituencyRef != null) {
      assemblyConstituency = user.assemblyConstituencyRef!.getName(lang);
    } else if (user.assemblyConstituency != null && user.assemblyConstituency!.isNotEmpty) {
      assemblyConstituency = user.assemblyConstituency;
    }

    return Card(
      elevation: 12,
      shadowColor: AppColors.primary.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.primary.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          children: [
            // ID Card Header
            Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.verified_user,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        lang == Language.en ? 'MyCongress ID' : 'MyCongress ID',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      user.role.toString().split('.').last.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ID Card Body
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
                  colors: [
                    const Color(0xFFFF9933).withOpacity(0.1), // Orange
                    Colors.white, // White
                    const Color(0xFF138808).withOpacity(0.1), // Green
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Watermark Logo
                  Positioned.fill(
                    child: Center(
                      child: Opacity(
                        opacity: 0.08,
                        child: Image.asset(
                          'assets/images/INC_Logo_SplashScreen.jpg',
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Photo and Name Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Photo Section
                      Container(
                        width: 120,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _profileImage != null
                              ? Image.file(
                                  _profileImage!,
                                  fit: BoxFit.cover,
                                  width: 116,
                                  height: 146,
                                )
                              : _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                                  ? Image.network(
                                      _getFullImageUrl(_profilePictureUrl!),
                                      fit: BoxFit.cover,
                                      width: 116,
                                      height: 146,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[200],
                                          child: Icon(
                                            Icons.person,
                                            size: 60,
                                            color: AppColors.primary.withOpacity(0.5),
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: Colors.grey[200],
                                      child: Icon(
                                        Icons.person,
                                        size: 60,
                                        color: AppColors.primary.withOpacity(0.5),
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Member Name below photo
                      SizedBox(
                        width: 120,
                        child: _buildIdCardField(
                          label: lang == Language.en ? 'Member Name' : 'సభ్యుని పేరు',
                          value: user.fullName ?? user.name,
                          isBold: true,
                          isCentered: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Details Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Designation
                        if (user.partyDesignation != null && user.partyDesignation!.isNotEmpty) ...[
                          _buildIdCardField(
                            label: lang == Language.en ? 'Designation' : 'హోదా',
                            value: user.partyDesignation!,
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Parliament Constituency
                        if (parliamentConstituency != null && parliamentConstituency.isNotEmpty) ...[
                          _buildIdCardField(
                            label: lang == Language.en ? 'Parliament Constituency' : 'పార్లమెంటు నియోజకవర్గం',
                            value: parliamentConstituency,
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Assembly Constituency
                        if (assemblyConstituency != null && assemblyConstituency.isNotEmpty)
                          _buildIdCardField(
                            label: lang == Language.en ? 'Assembly Constituency' : 'అసెంబ్లీ నియోజకవర్గం',
                            value: assemblyConstituency,
                          ),
                      ],
                    ),
                  ),
                    ],
                  ),
                ],
              ),
            ),
            // ID Card Footer
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.shield,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${lang == Language.en ? 'Member ID' : 'సభ్యుని ID'}: ${user.id}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdCardField({
    required String label,
    required String value,
    bool isBold = false,
    Color? valueColor,
    bool isCentered = false,
  }) {
    return Column(
      crossAxisAlignment: isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
          textAlign: isCentered ? TextAlign.center : TextAlign.left,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? AppColors.textPrimary,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: isCentered ? TextAlign.center : TextAlign.left,
        ),
      ],
    );
  }

  Widget _buildEditForm(Language lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          lang == Language.en ? 'Basic Information' : 'వ్యక్తిగత సమాచారం',
          Icons.person,
        ),
        const SizedBox(height: 12),
        _buildProfileImagePicker(lang),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _nameController,
          label: lang == Language.en ? 'Name *' : 'పేరు *',
          icon: Icons.person,
          required: true,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _fullNameController,
          label: lang == Language.en ? 'Full Name' : 'పూర్తి పేరు',
          icon: Icons.badge,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _fatherNameController,
          label: lang == Language.en ? 'Father\'s Name' : 'తండ్రి పేరు',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        _buildDateField(lang),
        const SizedBox(height: 12),
        _buildGenderDropdown(lang),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _regionController,
          label: lang == Language.en ? 'Region' : 'ప్రాంతం',
          icon: Icons.location_on,
        ),
        const SizedBox(height: 24),
        _buildSectionTitle(
          lang == Language.en ? 'Address Information' : 'చిరునామా సమాచారం',
          Icons.home,
        ),
        const SizedBox(height: 12),
        _buildDistrictDropdown(lang),
        const SizedBox(height: 12),
        _buildMandalDropdown(lang),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _villageController,
          label: lang == Language.en ? 'Village' : 'గ్రామం',
          icon: Icons.location_city,
        ),
        const SizedBox(height: 12),
        _buildParliamentConstituencyDropdown(lang),
        const SizedBox(height: 12),
        _buildAssemblyConstituencyDropdown(lang),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _fullAddressController,
          label: lang == Language.en ? 'Full Address' : 'పూర్తి చిరునామా',
          icon: Icons.home,
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        _buildSectionTitle(
          lang == Language.en ? 'Party & Professional' : 'పార్టీ & వృత్తి',
          Icons.work,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _partyDesignationController,
          label: lang == Language.en ? 'Party Designation' : 'పార్టీ హోదా',
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _occupationController,
          label: lang == Language.en ? 'Occupation' : 'వృత్తి',
          icon: Icons.business_center,
        ),
        const SizedBox(height: 12),
        _buildCheckbox(
          value: _volunteerInterest,
          label: lang == Language.en ? 'Volunteer Interest' : 'స్వచ్ఛంద ఆసక్తి',
          onChanged: (value) {
            if (!mounted) return;
            setState(() {
              _volunteerInterest = value ?? false;
            });
          },
        ),
        const SizedBox(height: 24),
        _buildSectionTitle(
          lang == Language.en ? 'Identification & Insurance' : 'గుర్తింపు & బీమా',
          Icons.verified_user,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _aadharNumberController,
          label: lang == Language.en ? 'Aadhar Number' : 'ఆధార్ నంబర్',
          icon: Icons.credit_card,
          maxLength: 12,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _epicNumberController,
          label: lang == Language.en ? 'Voter ID (EPIC)' : 'ఓటర్ ID (EPIC)',
          icon: Icons.ballot,
        ),
        const SizedBox(height: 12),
        _buildCheckbox(
          value: _hasInsurance,
          label: lang == Language.en ? 'Has Insurance' : 'బీమా ఉంది',
          onChanged: (value) {
            if (!mounted) return;
            setState(() {
              _hasInsurance = value ?? false;
              if (!_hasInsurance) {
                _insuranceNumberController.clear();
              }
            });
          },
        ),
        if (_hasInsurance) ...[
          const SizedBox(height: 12),
          _buildTextField(
            controller: _insuranceNumberController,
            label: lang == Language.en ? 'Insurance Number' : 'బీమా నంబర్',
            icon: Icons.health_and_safety,
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImagePicker(Language lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang == Language.en ? 'Profile Photo' : 'ప్రొఫైల్ ఫోటో',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
                child: _profileImage != null
                    ? ClipOval(
                        child: Image.file(
                          _profileImage!,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        ),
                      )
                    : _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              _getFullImageUrl(_profilePictureUrl!),
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  size: 70,
                                  color: AppColors.primary,
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 70,
                            color: AppColors.primary,
                          ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    onPressed: _showImageSourceDialog,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _showImageSourceDialog,
            icon: const Icon(Icons.edit, size: 18),
            label: Text(
              lang == Language.en ? 'Change Photo' : 'ఫోటో మార్చు',
              style: const TextStyle(fontSize: 14),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ),
        if (_profileImage != null) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () {
                if (!mounted) return;
                setState(() {
                  _profileImage = null;
                });
              },
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              label: Text(
                lang == Language.en ? 'Remove Photo' : 'ఫోటో తీసివేయి',
                style: const TextStyle(fontSize: 14, color: Colors.red),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool required = false,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: AppColors.primary) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      readOnly: readOnly,
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return context.lang == Language.en
                    ? 'This field is required'
                    : 'ఈ ఫీల్డ్ అవసరం';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildDateField(Language lang) {
    return TextFormField(
      controller: _dateOfBirthController,
      decoration: InputDecoration(
        labelText: lang == Language.en ? 'Date of Birth' : 'పుట్టిన తేది',
        prefixIcon: const Icon(Icons.calendar_today, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.date_range),
          onPressed: () => _selectDate(context),
        ),
      ),
      readOnly: true,
      onTap: () => _selectDate(context),
    );
  }

  Widget _buildGenderDropdown(Language lang) {
    return DropdownButtonFormField<String>(
      value: _gender,
      decoration: InputDecoration(
        labelText: lang == Language.en ? 'Gender' : 'లింగం',
        prefixIcon: const Icon(Icons.people, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      items: [
        DropdownMenuItem(
          value: 'male',
          child: Text(lang == Language.en ? 'Male' : 'పురుషుడు'),
        ),
        DropdownMenuItem(
          value: 'female',
          child: Text(lang == Language.en ? 'Female' : 'స్త్రీ'),
        ),
        DropdownMenuItem(
          value: 'other',
          child: Text(lang == Language.en ? 'Other' : 'ఇతర'),
        ),
      ],
      onChanged: (value) {
        if (!mounted) return;
        setState(() {
          _gender = value;
        });
      },
    );
  }

  Widget _buildDistrictDropdown(Language lang) {
    // Show loading state
    if (_loadingDistricts) {
      return DropdownButtonFormField<DistrictRef>(
        value: null,
        decoration: InputDecoration(
          labelText: lang == Language.en ? 'District *' : 'జిల్లా *',
          prefixIcon: const Icon(Icons.map_outlined, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          suffixIcon: const Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        items: [
          DropdownMenuItem<DistrictRef>(
            value: null,
            child: Text(
              lang == Language.en ? 'Loading districts...' : 'జిల్లాలు లోడ్ అవుతోంది...',
            ),
          ),
        ],
        onChanged: null,
      );
    }

    // Show empty state if no districts
    if (_districts.isEmpty) {
      return DropdownButtonFormField<DistrictRef>(
        value: null,
        decoration: InputDecoration(
          labelText: lang == Language.en ? 'District *' : 'జిల్లా *',
          prefixIcon: const Icon(Icons.map_outlined, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        items: [
          DropdownMenuItem<DistrictRef>(
            value: null,
            child: Text(
              lang == Language.en ? 'No districts available' : 'జిల్లాలు అందుబాటులో లేవు',
            ),
          ),
        ],
        onChanged: null,
      );
    }

    // Normal state with districts loaded
    return DropdownButtonFormField<DistrictRef>(
      value: _selectedDistrict,
      decoration: InputDecoration(
        labelText: lang == Language.en ? 'District *' : 'జిల్లా *',
        prefixIcon: const Icon(Icons.map_outlined, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      items: _districts.map<DropdownMenuItem<DistrictRef>>((DistrictRef district) {
        return DropdownMenuItem<DistrictRef>(
          value: district,
          child: Text(district.getName(lang)),
        );
      }).toList(),
      onChanged: (DistrictRef? newDistrict) {
        if (!mounted) return;
        setState(() {
          _selectedDistrict = newDistrict;
          _selectedMandal = null; // Reset mandal when district changes
          _mandals = []; // Clear mandals list
        });
        if (newDistrict != null) {
          _loadMandals(newDistrict.id);
        }
      },
      validator: (value) {
        if (value == null) {
          return lang == Language.en
              ? 'Please select a district'
              : 'దయచేసి జిల్లాను ఎంచుకోండి';
        }
        return null;
      },
    );
  }

  Widget _buildMandalDropdown(Language lang) {
    // Only show mandal dropdown if a district is selected
    if (_selectedDistrict == null) {
      return DropdownButtonFormField<MandalRef>(
        value: null,
        decoration: InputDecoration(
          labelText: lang == Language.en ? 'Mandal' : 'మండలం',
          prefixIcon: const Icon(Icons.map, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        items: [
          DropdownMenuItem<MandalRef>(
            value: null,
            child: Text(
              lang == Language.en
                  ? 'Please select a district first'
                  : 'దయచేసి మొదట జిల్లాను ఎంచుకోండి',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
        onChanged: null,
      );
    }

    // Show loading state
    if (_loadingMandals) {
      return DropdownButtonFormField<MandalRef>(
        value: null,
        decoration: InputDecoration(
          labelText: lang == Language.en ? 'Mandal' : 'మండలం',
          prefixIcon: const Icon(Icons.map, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          suffixIcon: const Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        items: [
          DropdownMenuItem<MandalRef>(
            value: null,
            child: Text(
              lang == Language.en ? 'Loading mandals...' : 'మండలాలు లోడ్ అవుతోంది...',
            ),
          ),
        ],
        onChanged: null,
      );
    }

    // Show empty state if no mandals
    if (_mandals.isEmpty) {
      return DropdownButtonFormField<MandalRef>(
        value: null,
        decoration: InputDecoration(
          labelText: lang == Language.en ? 'Mandal' : 'మండలం',
          prefixIcon: const Icon(Icons.map, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        items: [
          DropdownMenuItem<MandalRef>(
            value: null,
            child: Text(
              lang == Language.en ? 'No mandals available' : 'మండలాలు అందుబాటులో లేవు',
            ),
          ),
        ],
        onChanged: null,
      );
    }

    // Normal state with mandals loaded
    return DropdownButtonFormField<MandalRef>(
      value: _selectedMandal,
      decoration: InputDecoration(
        labelText: lang == Language.en ? 'Mandal' : 'మండలం',
        prefixIcon: const Icon(Icons.map, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      items: _mandals.map<DropdownMenuItem<MandalRef>>((MandalRef mandal) {
        return DropdownMenuItem<MandalRef>(
          value: mandal,
          child: Text(mandal.getName(lang)),
        );
      }).toList(),
      onChanged: (MandalRef? newMandal) {
        if (!mounted) return;
        setState(() {
          _selectedMandal = newMandal;
        });
      },
    );
  }

  Widget _buildParliamentConstituencyDropdown(Language lang) {
    // Show loading state
    if (_loadingConstituencies) {
      return DropdownButtonFormField<int>(
        value: null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: lang == Language.en ? 'Parliament Constituency' : 'పార్లమెంటు నియోజకవర్గం',
          prefixIcon: const Icon(Icons.account_balance, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          suffixIcon: const Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        items: [
          DropdownMenuItem<int>(
            value: null,
            child: Text(
              lang == Language.en ? 'Loading constituencies...' : 'నియోజకవర్గాలు లోడ్ అవుతోంది...',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: null,
      );
    }

    // Show empty state if no constituencies
    if (_constituencies.isEmpty) {
      return DropdownButtonFormField<int>(
        value: null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: lang == Language.en ? 'Parliament Constituency' : 'పార్లమెంటు నియోజకవర్గం',
          prefixIcon: const Icon(Icons.account_balance, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        items: [
          DropdownMenuItem<int>(
            value: null,
            child: Text(
              lang == Language.en ? 'No constituencies available' : 'నియోజకవర్గాలు అందుబాటులో లేవు',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: null,
      );
    }

    // Normal state with constituencies loaded
    return DropdownButtonFormField<int>(
      value: _selectedParliamentConstituencyId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: lang == Language.en ? 'Parliament Constituency' : 'పార్లమెంటు నియోజకవర్గం',
        prefixIcon: const Icon(Icons.account_balance, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      items: [
        DropdownMenuItem<int>(
          value: null,
          child: Text(
            lang == Language.en ? 'Select Constituency' : 'నియోజకవర్గం ఎంచుకోండి',
            style: TextStyle(color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ..._constituencies.map((constituency) {
          final name = lang == Language.en
              ? constituency['name_en']
              : constituency['name_te'];
          final id = constituency['id'] is int ? constituency['id'] : int.tryParse(constituency['id'].toString());
          return DropdownMenuItem<int>(
            value: id,
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: (int? newConstituencyId) {
        if (!mounted) return;
        setState(() {
          _selectedParliamentConstituencyId = newConstituencyId;
          _selectedAssemblyConstituencyId = null; // Reset assembly constituency
          _assemblyConstituencies = []; // Clear assembly constituencies list
          _lastLoadedParliamentConstituencyId = null; // Reset tracking
        });
        if (newConstituencyId != null) {
          _loadAssemblyConstituencies(parliamentConstituencyId: newConstituencyId);
        }
      },
    );
  }

  Widget _buildAssemblyConstituencyDropdown(Language lang) {
    // Only show assembly constituency dropdown if a parliament constituency is selected
    if (_selectedParliamentConstituencyId == null) {
      return DropdownButtonFormField<int>(
        value: null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: lang == Language.en ? 'Assembly Constituency' : 'అసెంబ్లీ నియోజకవర్గం',
          prefixIcon: const Icon(Icons.business, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        items: [
          DropdownMenuItem<int>(
            value: null,
            child: Text(
              lang == Language.en
                  ? 'Please select a parliament constituency first'
                  : 'దయచేసి మొదట పార్లమెంటు నియోజకవర్గాన్ని ఎంచుకోండి',
              style: TextStyle(color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: null,
      );
    }

    // Show loading state
    if (_loadingAssemblyConstituencies) {
      return DropdownButtonFormField<int>(
        value: null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: lang == Language.en ? 'Assembly Constituency' : 'అసెంబ్లీ నియోజకవర్గం',
          prefixIcon: const Icon(Icons.business, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          suffixIcon: const Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        items: [
          DropdownMenuItem<int>(
            value: null,
            child: Text(
              lang == Language.en ? 'Loading assembly constituencies...' : 'అసెంబ్లీ నియోజకవర్గాలు లోడ్ అవుతోంది...',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: null,
      );
    }

    // Show empty state if no assembly constituencies
    if (_assemblyConstituencies.isEmpty) {
      return DropdownButtonFormField<int>(
        value: null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: lang == Language.en ? 'Assembly Constituency' : 'అసెంబ్లీ నియోజకవర్గం',
          prefixIcon: const Icon(Icons.business, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        items: [
          DropdownMenuItem<int>(
            value: null,
            child: Text(
              lang == Language.en ? 'No assembly constituencies available' : 'అసెంబ్లీ నియోజకవర్గాలు అందుబాటులో లేవు',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: null,
      );
    }

    // Normal state with assembly constituencies loaded
    return DropdownButtonFormField<int>(
      value: _selectedAssemblyConstituencyId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: lang == Language.en ? 'Assembly Constituency' : 'అసెంబ్లీ నియోజకవర్గం',
        prefixIcon: const Icon(Icons.business, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      items: [
        DropdownMenuItem<int>(
          value: null,
          child: Text(
            lang == Language.en ? 'Select Assembly Constituency' : 'అసెంబ్లీ నియోజకవర్గం ఎంచుకోండి',
            style: TextStyle(color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ..._assemblyConstituencies.map((constituency) {
          final name = lang == Language.en
              ? constituency['name_en']
              : constituency['name_te'];
          final id = constituency['id'] is int ? constituency['id'] : int.tryParse(constituency['id'].toString());
          return DropdownMenuItem<int>(
            value: id,
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: (int? newAssemblyConstituencyId) {
        if (!mounted) return;
        setState(() {
          _selectedAssemblyConstituencyId = newAssemblyConstituencyId;
        });
      },
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label),
      activeColor: AppColors.primary,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildActionButtons(Language lang) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : _cancelEdit,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              lang == Language.en ? 'Cancel' : 'రద్దు చేయి',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    lang == Language.en ? 'Save' : 'సేవ్ చేయి',
                    style: const TextStyle(fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context, User user, Language lang) {
    return _buildInfoSectionWidget(
      context,
      title: lang == Language.en ? 'Personal Information' : 'వ్యక్తిగత సమాచారం',
      items: [
        _InfoItem(
          icon: Icons.phone,
          label: lang == Language.en ? 'Phone Number' : 'ఫోన్ నంబర్',
          value: user.phone,
        ),
        _InfoItem(
          icon: Icons.badge,
          label: lang == Language.en ? 'Role' : 'పాత్ర',
          value: user.role.toString().split('.').last.toUpperCase(),
        ),
        if (user.fatherName != null)
          _InfoItem(
            icon: Icons.person_outline,
            label: lang == Language.en ? 'Father\'s Name' : 'తండ్రి పేరు',
            value: user.fatherName!,
          ),
        if (user.dateOfBirth != null)
          _InfoItem(
            icon: Icons.cake,
            label: lang == Language.en ? 'Date of Birth' : 'పుట్టిన తేది',
            value: user.dateOfBirth!,
          ),
        if (user.gender != null)
          _InfoItem(
            icon: Icons.people,
            label: lang == Language.en ? 'Gender' : 'లింగం',
            value: user.gender!,
          ),
        if (user.fullAddress != null)
          _InfoItem(
            icon: Icons.home,
            label: lang == Language.en ? 'Address' : 'చిరునామా',
            value: user.fullAddress!,
          ),
        if (user.village != null)
          _InfoItem(
            icon: Icons.location_city,
            label: lang == Language.en ? 'Village' : 'గ్రామం',
            value: user.village!,
          ),
        // Display Mandal from ref if available, otherwise show string or ID
        if (user.mandalRef != null)
          _InfoItem(
            icon: Icons.map,
            label: lang == Language.en ? 'Mandal' : 'మండలం',
            value: user.mandalRef!.getName(lang),
          )
        else if (user.mandal != null)
          _InfoItem(
            icon: Icons.map,
            label: lang == Language.en ? 'Mandal' : 'మండలం',
            value: user.mandal!,
          )
        else if (user.mandalId != null)
          _InfoItem(
            icon: Icons.map,
            label: lang == Language.en ? 'Mandal' : 'మండలం',
            value: 'ID: ${user.mandalId}',
          ),
        // Display District from ref if available, otherwise show string or ID
        if (user.districtRef != null)
          _InfoItem(
            icon: Icons.map_outlined,
            label: lang == Language.en ? 'District' : 'జిల్లా',
            value: user.districtRef!.getName(lang),
          )
        else if (user.district != null)
          _InfoItem(
            icon: Icons.map_outlined,
            label: lang == Language.en ? 'District' : 'జిల్లా',
            value: user.district!,
          )
        else if (user.districtId != null)
          _InfoItem(
            icon: Icons.map_outlined,
            label: lang == Language.en ? 'District' : 'జిల్లా',
            value: 'ID: ${user.districtId}',
          ),
        // Display Assembly Constituency from ref if available, otherwise show ID
        if (user.assemblyConstituencyRef != null)
          _InfoItem(
            icon: Icons.map,
            label: lang == Language.en ? 'Assembly Constituency' : 'అసెంబ్లీ నియోజకవర్గం',
            value: user.assemblyConstituencyRef!.getName(lang),
          )
        else if (user.assemblyConstituencyId != null)
          _InfoItem(
            icon: Icons.map,
            label: lang == Language.en ? 'Assembly Constituency' : 'అసెంబ్లీ నియోజకవర్గం',
            value: 'ID: ${user.assemblyConstituencyId}',
          ),
        // Display Parliament Constituency from ref if available, otherwise show ID
        if (user.parliamentConstituencyRef != null)
          _InfoItem(
            icon: Icons.location_city,
            label: lang == Language.en ? 'Parliament Constituency' : 'పార్లమెంటు నియోజకవర్గం',
            value: user.parliamentConstituencyRef!.getName(lang),
          )
        else if (user.parliamentConstituencyId != null)
          _InfoItem(
            icon: Icons.location_city,
            label: lang == Language.en ? 'Parliament Constituency' : 'పార్లమెంటు నియోజకవర్గం',
            value: 'ID: ${user.parliamentConstituencyId}',
          ),
        if (user.partyDesignation != null)
          _InfoItem(
            icon: Icons.work,
            label: lang == Language.en ? 'Party Designation' : 'పార్టీ హోదా',
            value: user.partyDesignation!,
          ),
        if (user.region != null)
          _InfoItem(
            icon: Icons.location_on,
            label: lang == Language.en ? 'Region' : 'ప్రాంతం',
            value: user.region!,
          ),
        if (user.enrollmentDate != null)
          _InfoItem(
            icon: Icons.calendar_today,
            label: lang == Language.en ? 'Joined Date' : 'చేరిన తేదీ',
            value: user.enrollmentDate!,
          ),
      ],
    );
  }

  Widget _buildInfoSectionWidget(BuildContext context, {required String title, required List<_InfoItem> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: Icon(item.icon, color: AppColors.primary),
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                subtitle: Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            context.lang == Language.en ? 'Logout' : 'లాగ్అవుట్',
          ),
          content: Text(
            context.lang == Language.en
                ? 'Are you sure you want to logout?'
                : 'మీరు లాగ్అవుట్ చేయాలనుకుంటున్నారా?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                context.lang == Language.en ? 'Cancel' : 'రద్దు చేయి',
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Call logout from AuthService
                await context.read<AuthService>().logout();
                // Navigate to login screen
                context.go('/login');
              },
              child: Text(
                context.lang == Language.en ? 'Logout' : 'లాగ్అవుట్',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}
