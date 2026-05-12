import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../models/index.dart';
import '../../utils/lang_ext.dart';
import '../../services/language_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _fullNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _phoneController = TextEditingController();
  final _aadharController = TextEditingController();
  final _epicController = TextEditingController();
  final _villageController = TextEditingController();
  final _parliamentConstituencyController = TextEditingController();
  final _assemblyConstituencyController = TextEditingController();
  final _partyDesignationController = TextEditingController();
  final _occupationController = TextEditingController();
  final _insuranceNumberController = TextEditingController();
  final _fullAddressController = TextEditingController();
  
  String _selectedGender = '';
  int? _selectedConstituencyId;
  int? _selectedAssemblyConstituencyId;
  String _hasInsurance = '';
  bool _volunteerInterest = false;
  bool _isSubmitting = false;
  File? _epicFile;
  String _epicFileName = '';
  static bool _dateFormattingInitialized = false;
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _constituencies = [];
  List<Map<String, dynamic>> _assemblyConstituencies = [];
  bool _loadingConstituencies = false;
  bool _loadingAssemblyConstituencies = false;
  
  // District and Mandal dropdowns
  List<DistrictRef> _districts = <DistrictRef>[];
  List<MandalRef> _mandals = <MandalRef>[];
  DistrictRef? _selectedDistrict;
  MandalRef? _selectedMandal;
  bool _loadingDistricts = false;
  bool _loadingMandals = false;

  @override
  void initState() {
    super.initState();
    _loadDistricts();
    _fetchConstituencies();
    _fetchAssemblyConstituencies();
    _prefillPhoneNumber();
  }

  void _prefillPhoneNumber() {
    // Pre-fill phone number from authenticated user
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isAuthenticated && authService.currentUser != null) {
      final phone = authService.currentUser!.phone;
      if (phone.isNotEmpty) {
        _phoneController.text = phone;
      }
    }
  }

  Future<void> _loadDistricts() async {
    setState(() {
      _loadingDistricts = true;
    });

    try {
      var result = await _apiService.getDistricts(
        state: 'Telangana',
        isActive: true,
      );

      if (result['success'] != true || 
          result['data'] == null || 
          (result['data'] is List && (result['data'] as List).isEmpty)) {
        result = await _apiService.getDistricts();
      }

      if (result['success'] == true && result['data'] != null) {
        dynamic data = result['data'];
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
      setState(() {
        _districts = [];
        _loadingDistricts = false;
      });
    }
  }

  Future<void> _loadMandals(int? districtId) async {
    if (districtId == null) {
      setState(() {
        _mandals = [];
        _selectedMandal = null;
      });
      return;
    }

    setState(() {
      _loadingMandals = true;
      _selectedMandal = null;
    });

    try {
      final result = await _apiService.getMandals(
        districtId: districtId,
        isActive: true,
      );

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
      setState(() {
        _loadingMandals = false;
      });
    }
  }

  Future<void> _fetchConstituencies() async {
    setState(() {
      _loadingConstituencies = true;
    });

    try {
      final result = await _apiService.getConstituencies(
        state: 'Telangana',
        isActive: true,
      );

        if (result['success'] == true && result['data'] != null) {
        final List<dynamic> data = result['data'];
        setState(() {
          _constituencies = data.map<Map<String, dynamic>>((item) {
            // ID is now the constituency_number (integer)
            final id = item['id'] ?? item['constituencyNumber'];
            return {
              'id': id is int ? id : int.tryParse(id.toString()) ?? item['constituencyNumber'],
              'number': item['constituencyNumber'],
              'name_en': item['name_en'] ?? item['name']?['en'] ?? '',
              'name_te': item['name_te'] ?? item['name']?['te'] ?? item['name_en'] ?? '',
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
      setState(() {
        _loadingConstituencies = false;
      });
      // Silently fail - user can still enter manually if needed
    }
  }

  Future<void> _fetchAssemblyConstituencies({String? parliamentConstituencyId}) async {
    setState(() {
      _loadingAssemblyConstituencies = true;
    });

    try {
      final result = await _apiService.getAssemblyConstituencies(
        parliamentConstituencyId: parliamentConstituencyId,
        state: 'Telangana',
        isActive: true,
      );

      if (result['success'] == true && result['data'] != null) {
        final List<dynamic> data = result['data'];
        setState(() {
          _assemblyConstituencies = data.map<Map<String, dynamic>>((item) {
            // ID is now the constituency_number (integer)
            final id = item['id'] ?? item['constituencyNumber'];
            return {
              'id': id is int ? id : int.tryParse(id.toString()) ?? item['constituencyNumber'],
              'number': item['constituencyNumber'],
              'name_en': item['name_en'] ?? item['name']?['en'] ?? '',
              'name_te': item['name_te'] ?? item['name']?['te'] ?? item['name_en'] ?? '',
            };
          }).toList();
          _loadingAssemblyConstituencies = false;
        });
      } else {
        setState(() {
          _loadingAssemblyConstituencies = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadingAssemblyConstituencies = false;
      });
      // Silently fail - user can still enter manually if needed
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _fatherNameController.dispose();
    _dateOfBirthController.dispose();
    _phoneController.dispose();
    _aadharController.dispose();
    _epicController.dispose();
    _villageController.dispose();
    _parliamentConstituencyController.dispose();
    _assemblyConstituencyController.dispose();
    _partyDesignationController.dispose();
    _occupationController.dispose();
    _insuranceNumberController.dispose();
    _fullAddressController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.name.isNotEmpty) {
        // iOS doesn't provide file paths directly, handle both platforms
        if (Platform.isIOS) {
          // On iOS, files are copied to a temporary location or accessed via platform channels
          // FilePicker on iOS returns platformFile with bytes or path
          final platformFile = result.files.single;
          
          // Try to get the file path first (works if file was copied to temp)
          if (platformFile.path != null && platformFile.path!.isNotEmpty) {
            setState(() {
              _epicFile = File(platformFile.path!);
              _epicFileName = platformFile.name;
            });
          } else {
            // If no path, we'll just store the name (iOS handles file access differently)
            setState(() {
              _epicFileName = platformFile.name;
              // Note: On iOS, file access might need special handling via platform channels
              // For now, we'll store the name which is sufficient for display
            });
          }
        } else {
          // Android and other platforms
          if (result.files.single.path != null) {
            setState(() {
              _epicFile = File(result.files.single.path!);
              _epicFileName = result.files.single.name;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        // Get language for error message
        final languageService = Provider.of<LanguageService>(context, listen: false);
        final language = languageService.language;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language == Language.en
                  ? 'Error picking file: ${e.toString()}'
                  : 'ఫైల్ ఎంచుకునేటప్పుడు లోపం: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    // Initialize date formatting for locale support (needed for iOS)
    // Always use English for date picker to avoid issues
    if (!_dateFormattingInitialized) {
      await initializeDateFormatting('en', null);
      _dateFormattingInitialized = true;
    }
    
    // Always use English locale for date picker to avoid translation issues
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      locale: const Locale('en', 'IN'), // Always use English
      // iOS specific: Use builder to ensure proper display
      builder: (context, child) {
        // For iOS, ensure proper date picker styling
        if (Platform.isIOS) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme,
            ),
            child: child!,
          );
        }
        return child!;
      },
    );
    if (picked != null) {
      setState(() {
        _dateOfBirthController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitMembership() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final language = context.lang;
      
      // Convert hasInsurance string to boolean
      final hasInsurance = _hasInsurance == 'yes';
      
      // Call API to submit membership
      final result = await _apiService.submitMembership(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        fatherName: _fatherNameController.text.trim().isEmpty 
            ? null 
            : _fatherNameController.text.trim(),
        dateOfBirth: _dateOfBirthController.text.trim().isEmpty 
            ? null 
            : _dateOfBirthController.text.trim(),
        gender: _selectedGender.isEmpty ? null : _selectedGender,
        aadharNumber: _aadharController.text.trim().isEmpty 
            ? null 
            : _aadharController.text.trim(),
        epicNumber: _epicController.text.trim().isEmpty 
            ? null 
            : _epicController.text.trim(),
        epicFileUrl: null, // TODO: Implement file upload if needed
        village: _villageController.text.trim().isEmpty 
            ? null 
            : _villageController.text.trim(),
        districtId: _selectedDistrict?.id,
        mandalId: _selectedMandal?.id,
        parliamentConstituency: _parliamentConstituencyController.text.trim().isEmpty 
            ? null 
            : _parliamentConstituencyController.text.trim(),
        parliamentConstituencyId: _selectedConstituencyId?.toString(),
        assemblyConstituency: _assemblyConstituencyController.text.trim().isEmpty 
            ? null 
            : _assemblyConstituencyController.text.trim(),
        assemblyConstituencyId: _selectedAssemblyConstituencyId?.toString(),
        fullAddress: _fullAddressController.text.trim().isEmpty 
            ? null 
            : _fullAddressController.text.trim(),
        partyDesignation: _partyDesignationController.text.trim().isEmpty 
            ? null 
            : _partyDesignationController.text.trim(),
        occupation: _occupationController.text.trim().isEmpty 
            ? null 
            : _occupationController.text.trim(),
        volunteerInterest: _volunteerInterest,
        hasInsurance: hasInsurance,
        insuranceNumber: _insuranceNumberController.text.trim().isEmpty 
            ? null 
            : _insuranceNumberController.text.trim(),
      );

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _isSubmitting = false;
          });
          
          // Refresh profile to get updated membership status
          final authService = Provider.of<AuthService>(context, listen: false);
          await authService.refreshProfile();
          
          // Explicitly check and update membership status
          await authService.checkMembershipStatus();
          
          // Show success message
          final successMessage = language == Language.en
              ? 'Membership submitted successfully!'
              : 'సభ్యత్వం విజయవంతంగా సమర్పించబడింది!';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Wait for state to update, then navigate to home
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            context.go('/home');
          }
        } else {
          setState(() {
            _isSubmitting = false;
          });
          
          final errorMessage = result['message'] ?? 
              (language == Language.en 
                  ? 'Failed to submit membership. Please try again.' 
                  : 'సభ్యత్వం సమర్పించడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        
        final language = context.lang;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language == Language.en
                  ? 'An error occurred. Please try again.'
                  : 'ఒక లోపం సంభవించింది. దయచేసి మళ్లీ ప్రయత్నించండి.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Get language once to avoid Provider issues in validators
    final language = context.lang;

    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation - user must complete membership form
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: CustomScrollView(
        slivers: [
          // Header matching Home and Media pages
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.primary,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: colorScheme.onPrimary),
              onPressed: () async {
                final authService = Provider.of<AuthService>(context, listen: false);
                await authService.logout();
                if (mounted) {
                  context.go('/login');
                }
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 16),
              title: Text(
                language == Language.en ? 'Membership' : 'సభ్యత్వం',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorScheme.primary, colorScheme.primaryContainer],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.person_add,
                    size: 80,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
          // Form Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personal Details Section
                    _buildSectionHeader(
                      context,
                      language == Language.en
                          ? 'Personal Details'
                          : 'వ్యక్తిగత వివరాలు',
                    ),
                    _buildTextField(
                      controller: _fullNameController,
                      label: language == Language.en ? 'Full Name *' : 'పూర్తి పేరు *',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return language == Language.en
                              ? 'Please enter your full name'
                              : 'దయచేసి మీ పూర్తి పేరును నమోదు చేయండి';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _fatherNameController,
                      label: language == Language.en ? 'Father Name' : 'తండ్రి పేరు',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _dateOfBirthController,
                      label: language == Language.en ? 'Date of Birth *' : 'పుట్టిన తేదీ *',
                      icon: Icons.calendar_today,
                      readOnly: true, // Keep readOnly but allow tap to select date
                      onTap: () => _selectDate(context),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return language == Language.en
                              ? 'Please select your date of birth'
                              : 'దయచేసి మీ పుట్టిన తేదీని ఎంచుకోండి';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildGenderRadio(context),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: language == Language.en ? 'Phone Number *' : 'ఫోన్ నంబర్ *',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      readOnly: true, // Phone number is pre-filled from authenticated user and cannot be changed
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return language == Language.en
                              ? 'Please enter your phone number'
                              : 'దయచేసి మీ ఫోన్ నంబర్‌ను నమోదు చేయండి';
                        }
                        if (value.length != 10) {
                          return language == Language.en
                              ? 'Please enter a valid 10-digit phone number'
                              : 'దయచేసి చెల్లుబాటు అయ్యే 10 అంకెల ఫోన్ నంబర్‌ను నమోదు చేయండి';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Government IDs Section
                    _buildSectionHeader(
                      context,
                      language == Language.en
                          ? 'Government IDs'
                          : 'ప్రభుత్వ IDలు',
                    ),
                    _buildTextField(
                      controller: _aadharController,
                      label: language == Language.en ? 'Aadhar Number' : 'ఆధార్ నంబర్',
                      icon: Icons.credit_card,
                      keyboardType: TextInputType.number,
                      maxLength: 12,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _epicController,
                      label: language == Language.en
                          ? 'EPIC Number (Voter ID) *'
                          : 'EPIC నంబర్ (ఓటరు ID) *',
                      icon: Icons.how_to_vote,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return language == Language.en
                              ? 'Please enter your EPIC number'
                              : 'దయచేసి మీ EPIC నంబర్‌ను నమోదు చేయండి';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFilePicker(context),
                    const SizedBox(height: 24),

                    // Location Details Section
                    _buildSectionHeader(
                      context,
                      language == Language.en
                          ? 'Location Details'
                          : 'స్థాన వివరాలు',
                    ),
                    _buildDistrictDropdown(context),
                    const SizedBox(height: 16),
                    _buildMandalDropdown(context),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _villageController,
                      label: language == Language.en ? 'Village' : 'గ్రామం',
                      icon: Icons.location_city,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _fullAddressController,
                      label: language == Language.en ? 'Full Address' : 'పూర్తి చిరునామా',
                      icon: Icons.home,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Political Details Section
                    _buildSectionHeader(
                      context,
                      language == Language.en
                          ? 'Political Details'
                          : 'రాజకీయ వివరాలు',
                    ),
                    _buildConstituencyDropdown(context),
                    const SizedBox(height: 16),
                    _buildAssemblyConstituencyDropdown(context),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _partyDesignationController,
                      label: language == Language.en
                          ? 'Party Designation'
                          : 'పార్టీ హోదా',
                      icon: Icons.badge,
                    ),
                    const SizedBox(height: 24),

                    // Professional Details Section
                    _buildSectionHeader(
                      context,
                      language == Language.en
                          ? 'Professional Details'
                          : 'వృత్తిపరమైన వివరాలు',
                    ),
                    _buildTextField(
                      controller: _occupationController,
                      label: language == Language.en ? 'Occupation' : 'వృత్తి',
                      icon: Icons.work,
                    ),
                    const SizedBox(height: 24),

                    // Insurance Details Section
                    _buildSectionHeader(
                      context,
                      language == Language.en
                          ? 'Insurance Details'
                          : 'బీమా వివరాలు',
                    ),
                    _buildInsuranceRadio(context),
                    if (_hasInsurance == 'yes') ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _insuranceNumberController,
                        label: language == Language.en
                            ? 'Insurance Number'
                            : 'బీమా నంబర్',
                        icon: Icons.health_and_safety,
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Volunteer Interest
                    _buildVolunteerCheckbox(context),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitMembership,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9933),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          disabledBackgroundColor: Colors.grey,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                language == Language.en ? 'Submit' : 'సమర్పించు',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }


  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 1),
                ),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF9933),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
    int? maxLines,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    // For date fields with onTap, we want readOnly but still enabled so users can tap
    final bool isDateField = onTap != null;
    final bool shouldDisable = readOnly && !isDateField; // Don't disable if it has onTap (date picker)
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: maxLines ?? 1,
      readOnly: readOnly,
      enabled: !shouldDisable, // Only disable if readOnly AND not a date field
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: readOnly && !isDateField 
            ? const Icon(Icons.lock, size: 18, color: Colors.grey) 
            : null, // Don't show lock icon for date fields
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: shouldDisable ? Colors.grey[100] : Colors.white, // Only gray if truly disabled
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: shouldDisable ? Colors.grey[300]! : Colors.grey),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildGenderRadio(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.lang == Language.en ? 'Gender' : 'లింగం',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            RadioListTile<String>(
              title: Text(context.lang == Language.en ? 'Male' : 'పురుషుడు'),
              value: 'male',
              groupValue: _selectedGender,
              onChanged: (value) {
                setState(() {
                  _selectedGender = value!;
                });
              },
              dense: true,
            ),
            RadioListTile<String>(
              title: Text(context.lang == Language.en ? 'Female' : 'స్త్రీ'),
              value: 'female',
              groupValue: _selectedGender,
              onChanged: (value) {
                setState(() {
                  _selectedGender = value!;
                });
              },
              dense: true,
            ),
            RadioListTile<String>(
              title: Text(context.lang == Language.en ? 'Other' : 'ఇతర'),
              value: 'other',
              groupValue: _selectedGender,
              onChanged: (value) {
                setState(() {
                  _selectedGender = value!;
                });
              },
              dense: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDistrictDropdown(BuildContext context) {
    final language = context.lang;
    
    // Show loading state
    if (_loadingDistricts) {
      return DropdownButtonFormField<DistrictRef>(
        value: null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: language == Language.en ? 'District *' : 'జిల్లా *',
          prefixIcon: const Icon(Icons.map_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white,
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
              language == Language.en ? 'Loading districts...' : 'జిల్లాలు లోడ్ అవుతోంది...',
              overflow: TextOverflow.ellipsis,
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
        isExpanded: true,
        decoration: InputDecoration(
          labelText: language == Language.en ? 'District *' : 'జిల్లా *',
          prefixIcon: const Icon(Icons.map_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        items: [
          DropdownMenuItem<DistrictRef>(
            value: null,
            child: Text(
              language == Language.en ? 'No districts available' : 'జిల్లాలు అందుబాటులో లేవు',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: null,
      );
    }

    // Normal state with districts loaded
    return DropdownButtonFormField<DistrictRef>(
      value: _selectedDistrict,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: language == Language.en ? 'District *' : 'జిల్లా *',
        prefixIcon: const Icon(Icons.map_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _districts.map<DropdownMenuItem<DistrictRef>>((DistrictRef district) {
        return DropdownMenuItem<DistrictRef>(
          value: district,
          child: Text(
            district.getName(language),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (DistrictRef? newDistrict) {
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
          return language == Language.en
              ? 'Please select a district'
              : 'దయచేసి జిల్లాను ఎంచుకోండి';
        }
        return null;
      },
    );
  }

  Widget _buildMandalDropdown(BuildContext context) {
    final language = context.lang;
    
    // Only show mandal dropdown if a district is selected
    if (_selectedDistrict == null) {
      return DropdownButtonFormField<MandalRef>(
        value: null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: language == Language.en ? 'Mandal' : 'మండలం',
          prefixIcon: const Icon(Icons.map),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        items: [
          DropdownMenuItem<MandalRef>(
            value: null,
            child: Text(
              language == Language.en
                  ? 'Please select a district first'
                  : 'దయచేసి మొదట జిల్లాను ఎంచుకోండి',
              style: TextStyle(color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
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
        isExpanded: true,
        decoration: InputDecoration(
          labelText: language == Language.en ? 'Mandal' : 'మండలం',
          prefixIcon: const Icon(Icons.map),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white,
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
              language == Language.en ? 'Loading mandals...' : 'మండలాలు లోడ్ అవుతోంది...',
              overflow: TextOverflow.ellipsis,
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
        isExpanded: true,
        decoration: InputDecoration(
          labelText: language == Language.en ? 'Mandal' : 'మండలం',
          prefixIcon: const Icon(Icons.map),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        items: [
          DropdownMenuItem<MandalRef>(
            value: null,
            child: Text(
              language == Language.en ? 'No mandals available' : 'మండలాలు అందుబాటులో లేవు',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: null,
      );
    }

    // Normal state with mandals loaded
    return DropdownButtonFormField<MandalRef>(
      value: _selectedMandal,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: language == Language.en ? 'Mandal' : 'మండలం',
        prefixIcon: const Icon(Icons.map),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _mandals.map<DropdownMenuItem<MandalRef>>((MandalRef mandal) {
        return DropdownMenuItem<MandalRef>(
          value: mandal,
          child: Text(
            mandal.getName(language),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (MandalRef? newMandal) {
        setState(() {
          _selectedMandal = newMandal;
        });
      },
    );
  }

  Widget _buildConstituencyDropdown(BuildContext context) {
    final language = context.lang;
    
    if (_loadingConstituencies) {
      return DropdownButtonFormField<String>(
        value: null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: language == Language.en
              ? 'Parliament Constituency'
              : 'పార్లమెంట్ నియోజకవర్గం',
          prefixIcon: const Icon(Icons.account_balance),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              language == Language.en
                  ? 'Loading...'
                  : 'లోడ్ అవుతోంది...',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: null,
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedConstituencyId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: language == Language.en
            ? 'Parliament Constituency'
            : 'పార్లమెంట్ నియోజకవర్గం',
        prefixIcon: const Icon(Icons.account_balance),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        DropdownMenuItem<int>(
          value: null,
          child: Text(
            language == Language.en
                ? 'Select Constituency'
                : 'నియోజకవర్గం ఎంచుకోండి',
            style: TextStyle(color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ..._constituencies.map((constituency) {
          final name = language == Language.en
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
      onChanged: (value) {
        setState(() {
          _selectedConstituencyId = value;
          // Also update the text controller for backward compatibility
          if (value != null) {
            final selected = _constituencies.firstWhere(
              (c) => (c['id'] is int ? c['id'] : int.tryParse(c['id'].toString())) == value,
              orElse: () => {'name_en': '', 'name_te': ''},
            );
            _parliamentConstituencyController.text = 
                language == Language.en
                    ? selected['name_en']
                    : selected['name_te'];
            // Fetch assembly constituencies for selected parliamentary constituency
            _fetchAssemblyConstituencies(parliamentConstituencyId: value.toString());
            // Clear selected assembly constituency when parliamentary changes
            _selectedAssemblyConstituencyId = null;
            _assemblyConstituencyController.clear();
          } else {
            _parliamentConstituencyController.clear();
            // Clear assembly constituencies if no parliamentary selected
            _assemblyConstituencies = [];
            _selectedAssemblyConstituencyId = null;
            _assemblyConstituencyController.clear();
          }
        });
      },
    );
  }

  Widget _buildAssemblyConstituencyDropdown(BuildContext context) {
    final language = context.lang;
    
    if (_loadingAssemblyConstituencies) {
      return DropdownButtonFormField<String>(
        value: null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: language == Language.en
              ? 'Assembly Constituency'
              : 'అసెంబ్లీ నియోజకవర్గం',
          prefixIcon: const Icon(Icons.business),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              language == Language.en
                  ? 'Loading...'
                  : 'లోడ్ అవుతోంది...',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: null,
      );
    }

    // If no parliamentary constituency is selected, show disabled dropdown
    if (_selectedConstituencyId == null) {
      return DropdownButtonFormField<int>(
        value: null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: language == Language.en
              ? 'Assembly Constituency'
              : 'అసెంబ్లీ నియోజకవర్గం',
          prefixIcon: const Icon(Icons.business),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white,
          hintText: language == Language.en
              ? 'Select Parliament Constituency first'
              : 'మొదట పార్లమెంట్ నియోజకవర్గం ఎంచుకోండి',
        ),
        items: [
          DropdownMenuItem<int>(
            value: null,
            child: Text(
              language == Language.en
                  ? 'Select Parliament Constituency first'
                  : 'మొదట పార్లమెంట్ నియోజకవర్గం ఎంచుకోండి',
              style: TextStyle(color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: null,
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedAssemblyConstituencyId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: language == Language.en
            ? 'Assembly Constituency'
            : 'అసెంబ్లీ నియోజకవర్గం',
        prefixIcon: const Icon(Icons.business),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        DropdownMenuItem<int>(
          value: null,
          child: Text(
            language == Language.en
                ? 'Select Assembly Constituency'
                : 'అసెంబ్లీ నియోజకవర్గం ఎంచుకోండి',
            style: TextStyle(color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ..._assemblyConstituencies.map((constituency) {
          final name = language == Language.en
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
      onChanged: (value) {
        setState(() {
          _selectedAssemblyConstituencyId = value;
          // Also update the text controller for backward compatibility
          if (value != null) {
            final selected = _assemblyConstituencies.firstWhere(
              (c) => (c['id'] is int ? c['id'] : int.tryParse(c['id'].toString())) == value,
              orElse: () => {'name_en': '', 'name_te': ''},
            );
            _assemblyConstituencyController.text = 
                language == Language.en
                    ? selected['name_en']
                    : selected['name_te'];
          } else {
            _assemblyConstituencyController.clear();
          }
        });
      },
    );
  }

  Widget _buildFilePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.lang == Language.en
              ? 'Upload EPIC Card'
              : 'EPIC కార్డ్ అప్‌లోడ్ చేయండి',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickFile,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade300,
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(Icons.upload_file, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _epicFileName.isEmpty
                        ? (context.lang == Language.en
                            ? 'No file chosen'
                            : 'ఏ ఫైల్ ఎంచుకోబడలేదు')
                        : _epicFileName,
                    style: TextStyle(
                      color: _epicFileName.isEmpty
                          ? Colors.grey[600]
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsuranceRadio(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.lang == Language.en
              ? 'Do you have Insurance?'
              : 'మీకు బీమా ఉందా?',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            RadioListTile<String>(
              title: Text(context.lang == Language.en ? 'Yes' : 'అవును'),
              value: 'yes',
              groupValue: _hasInsurance,
              onChanged: (value) {
                setState(() {
                  _hasInsurance = value!;
                  if (value != 'yes') {
                    _insuranceNumberController.clear();
                  }
                });
              },
              dense: true,
            ),
            RadioListTile<String>(
              title: Text(context.lang == Language.en ? 'No' : 'కాదు'),
              value: 'no',
              groupValue: _hasInsurance,
              onChanged: (value) {
                setState(() {
                  _hasInsurance = value!;
                  if (value == 'no') {
                    _insuranceNumberController.clear();
                  }
                });
              },
              dense: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVolunteerCheckbox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _volunteerInterest,
            onChanged: (value) {
              setState(() {
                _volunteerInterest = value ?? false;
              });
            },
            activeColor: const Color(0xFFFF9933),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.lang == Language.en
                      ? 'Interested in Volunteering'
                      : 'స్వచ్ఛంద సేవలో ఆసక్తి',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.lang == Language.en
                      ? 'I am willing to volunteer for party activities and campaigns'
                      : 'నేను పార్టీ కార్యకలాపాలు మరియు ప్రచారాల కోసం స్వచ్ఛందంగా పనిచేయడానికి సిద్ధంగా ఉన్నాను',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
