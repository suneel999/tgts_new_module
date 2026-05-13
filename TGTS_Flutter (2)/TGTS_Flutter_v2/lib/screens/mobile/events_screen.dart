import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/index.dart';
import '../../utils/lang_ext.dart';
import '../../services/api_service.dart';
import '../../services/language_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/timezone.dart';
import '../../mixins/access_level_filter_mixin.dart';
import '../../widgets/access_level_filter_chips.dart';
import 'package:timezone/timezone.dart' as tz;

/// Helper function to combine event date and time into a single DateTime (IST)
DateTime? _combineEventDateTime(String dateStr, String timeStr) {
  try {
    // Parse the date part
    final eventDate = parseToIST(dateStr);
    
    // Parse the time string (format: "HH:MM" or "HH:MM AM/PM")
    int hours = 0;
    int minutes = 0;
    
    // Handle 12-hour format with AM/PM
    final timeLower = timeStr.toLowerCase().trim();
    final isPM = timeLower.contains('pm');
    final isAM = timeLower.contains('am');
    
    // Extract numeric part using regex
    final timeRegex = RegExp(r'(\d{1,2}):(\d{2})');
    final match = timeRegex.firstMatch(timeStr);
    if (match == null) return eventDate; // If time parsing fails, return date only
    
    hours = int.parse(match.group(1)!);
    minutes = int.parse(match.group(2)!);
    
    // Convert 12-hour to 24-hour format
    if (isPM && hours != 12) {
      hours += 12;
    } else if (isAM && hours == 12) {
      hours = 0;
    }
    
    // Create new date with the time in IST
    final combinedDate = tz.TZDateTime(
      istLocation,
      eventDate.year,
      eventDate.month,
      eventDate.day,
      hours,
      minutes,
      0,
      0,
      0,
    );
    
    return combinedDate;
  } catch (e) {
    // Fallback to date only
    try {
      return parseToIST(dateStr);
    } catch (_) {
      return null;
    }
  }
}

// Display event structure (converted from API Event model)
class DisplayEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String time;
  final String location;
  final String? image;
  final int rsvpCount;
  final bool isUpcoming;
  final List<String> accessLevel;
  final bool isPublished;

  DisplayEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    this.image,
    required this.rsvpCount,
    required this.isUpcoming,
    required this.accessLevel,
    this.isPublished = true,
  });

  // Convert API Event to DisplayEvent
  factory DisplayEvent.fromEvent(Event event, Language language) {
    final now = getISTNow();
    final eventDate = parseToIST(event.date);
    
    // Combine date and time for accurate comparison
    final eventDateTime = _combineEventDateTime(event.date, event.time) ?? eventDate;
    final isUpcoming = eventDateTime.isAfter(now) || eventDateTime.isAtSameMomentAs(now);

    return DisplayEvent(
      id: event.id,
      title: event.title[language == Language.en ? 'en' : 'te'] ?? event.title['en'] ?? 'Untitled Event',
      description: event.description[language == Language.en ? 'en' : 'te'] ?? event.description['en'] ?? '',
      date: eventDate,
      time: event.time,
      location: event.location[language == Language.en ? 'en' : 'te'] ?? event.location['en'] ?? '',
      image: event.image,
      rsvpCount: event.rsvpCount,
      isUpcoming: isUpcoming,
      accessLevel: event.accessLevel,
      isPublished: event.isPublished ?? true,
    );
  }
}

enum ViewMode { list, calendar }

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin, AccessLevelFilterMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  ViewMode _viewMode = ViewMode.list;
  DateTime _focusedDay = getISTNow();
  DateTime _selectedDay = getISTNow();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  
  List<DisplayEvent> _allEvents = [];
  List<DisplayEvent> _filteredEvents = [];
  bool _isLoading = true;
  String? _errorMessage;
  LanguageService? _languageService;
  Set<String> _rsvpEvents = {};
  Set<String> _rsvpingEvents = {};

  // My Events tab state
  List<DisplayEvent> _myEvents = [];
  bool _isLoadingMyEvents = false;
  bool _hasErrorMyEvents = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {
          if (_tabController.index == 0) _viewMode = ViewMode.list;
          if (_tabController.index == 1) _viewMode = ViewMode.calendar;
        });
        // Lazy-load My Events on first visit to that tab
        if (_tabController.index == 2 && _myEvents.isEmpty && !_isLoadingMyEvents) {
          _loadMyEvents();
        }
      }
    });
    
    // Initialize user role and filters
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializeFilters();
    });
    
    _fetchEvents();
    
    // Store reference to language service for safe disposal
    _languageService = Provider.of<LanguageService>(context, listen: false);
    _languageService?.addListener(_onLanguageChanged);
  }

  void _applyFilter() {
    setState(() {
      _filteredEvents = applyFilters(
        _allEvents,
        (event) => event.accessLevel,
      );
    });
  }

  void _onLanguageChanged() {
    // Re-fetch events with new language
    if (mounted) {
      _fetchEvents();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Safely remove listener using stored reference
    _languageService?.removeListener(_onLanguageChanged);
    super.dispose();
  }

  Future<void> _fetchEvents() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get auth token if user is authenticated
      final authService = Provider.of<AuthService>(context, listen: false);
      final authToken = authService.isAuthenticated ? authService.accessToken : null;
      
      final result = await _apiService.getEvents(
        page: 1, 
        perPage: 100,
        authToken: authToken,
      );
      
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        final eventsList = data['events'] as List<dynamic>? ?? [];
        
        // Get language from Provider (check mounted first)
        Language language = Language.en;
        if (mounted) {
          final languageService = Provider.of<LanguageService>(context, listen: false);
          language = languageService.language;
        }
        
        // Track RSVP'd events from API response
        final rsvpEventIds = <String>{};
        
        final displayEvents = eventsList.map((eventJson) {
          try {
            final event = Event.fromJson(eventJson);
            // If user has RSVP'd, add to the set
            if (event.userHasRsvpd == true) {
              rsvpEventIds.add(event.id);
            }
            return DisplayEvent.fromEvent(event, language);
          } catch (e) {
            debugPrint('Error parsing event: $e');
            return null;
          }
        }).whereType<DisplayEvent>().toList();

        if (mounted) {
          setState(() {
            _allEvents = displayEvents;
            _rsvpEvents = rsvpEventIds; // Populate RSVP events from API
            _isLoading = false;
          });
          _applyFilter();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = result['message'] ?? 'Failed to load events';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMyEvents() async {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.accessToken == null) return;

    setState(() { _isLoadingMyEvents = true; _hasErrorMyEvents = false; });

    try {
      final language = Provider.of<LanguageService>(context, listen: false).language;
      final result = await _apiService.getMyEvents(authService.accessToken!);

      if (!mounted) return;
      if (result['success'] == true) {
        final list = result['data']?['events'] as List<dynamic>? ?? [];
        final events = list.map((j) {
          try { return DisplayEvent.fromEvent(Event.fromJson(j), language); }
          catch (_) { return null; }
        }).whereType<DisplayEvent>().toList();
        setState(() { _myEvents = events; _isLoadingMyEvents = false; });
      } else {
        setState(() { _hasErrorMyEvents = true; _isLoadingMyEvents = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _hasErrorMyEvents = true; _isLoadingMyEvents = false; });
    }
  }

  void _showCreateEventSheet() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please login to create an event'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateEventSheet(
        authToken: authService.accessToken!,
        apiService: _apiService,
        onSuccess: () {
          // Refresh My Events tab after successful submission
          _loadMyEvents();
          // Switch to My Events tab
          _tabController.animateTo(2);
        },
      ),
    );
  }

  Future<void> _handleRSVP(String eventId) async {
    if (!mounted) return;
    
    // Get language service once for this method
    final languageService = Provider.of<LanguageService>(context, listen: false);
    final currentLang = languageService.language;
    
    // Check if user is authenticated
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.accessToken == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentLang == Language.en 
                  ? 'Please login to RSVP to events'
                  : 'కార్యక్రమాలకు RSVP చేయడానికి దయచేసి లాగిన్ చేయండి',
            ),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: currentLang == Language.en ? 'OK' : 'సరే',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      return;
    }
    
    // Check if already RSVP'd
    if (_rsvpEvents.contains(eventId)) {
      // Already RSVP'd - could implement un-RSVP if needed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentLang == Language.en 
                  ? 'You have already RSVP\'d to this event'
                  : 'మీరు ఇప్పటికే ఈ కార్యక్రమానికి RSVP చేసారు',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
      return;
    }
    
    // Set loading state
    if (mounted) {
      setState(() {
        _rsvpingEvents.add(eventId);
      });
    }
    
    try {
      final result = await _apiService.rsvpToEvent(eventId, authService.accessToken!);
      
      if (!mounted) return;
      
      if (result['success'] == true || result['statusCode'] == 200) {
        // RSVP successful
        final rsvpCount = result['rsvp_count'] ?? result['data']?['rsvp_count'];
        final alreadyRsvpd = result['already_rsvpd'] ?? false;
        
        if (alreadyRsvpd) {
          // User already RSVP'd (shouldn't happen, but handle it)
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  currentLang == Language.en 
                      ? 'You have already RSVP\'d to this event'
                      : 'మీరు ఇప్పటికే ఈ కార్యక్రమానికి RSVP చేసారు',
                ),
                backgroundColor: AppColors.primary,
              ),
            );
          }
        } else {
          // Update local state
          setState(() {
            _rsvpEvents.add(eventId);
            
            // Update RSVP count in the event
            final eventIndex = _allEvents.indexWhere((e) => e.id == eventId);
            if (eventIndex != -1 && rsvpCount != null) {
              final event = _allEvents[eventIndex];
              _allEvents[eventIndex] = DisplayEvent(
                id: event.id,
                title: event.title,
                description: event.description,
                date: event.date,
                time: event.time,
                location: event.location,
                image: event.image,
                rsvpCount: rsvpCount is int ? rsvpCount : int.tryParse(rsvpCount.toString()) ?? event.rsvpCount + 1,
                isUpcoming: event.isUpcoming,
                accessLevel: event.accessLevel,
              );
            }
          });
          
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  currentLang == Language.en 
                      ? '✓ RSVP successful!'
                      : '✓ RSVP విజయవంతమైంది!',
                ),
                backgroundColor: AppColors.secondary,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // RSVP failed
        final message = result['message'] ?? 
            (currentLang == Language.en 
                ? 'Failed to RSVP. Please try again.'
                : 'RSVP విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentLang == Language.en 
                  ? 'An error occurred. Please try again.'
                  : 'దోషం సంభవించింది. దయచేసి మళ్లీ ప్రయత్నించండి.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Remove loading state
      if (mounted) {
        setState(() {
          _rsvpingEvents.remove(eventId);
        });
      }
    }
  }

  List<DisplayEvent> _getEventsForDay(DateTime day) {
    return _filteredEvents.where((event) {
      return isSameDay(event.date, day);
    }).toList();
  }

  List<DisplayEvent> _getSelectedDayEvents() {
    return _getEventsForDay(_selectedDay);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateEventSheet,
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          context.lang == Language.en ? 'Create Event' : 'కార్యక్రమం సృష్టించు',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: colorScheme.primary,
              centerTitle: true,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: Text(
                  context.lang == Language.en ? 'Events' : 'కార్యక్రమాలు',
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
                      Icons.event,
                      size: 80,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.list, size: 18),
                          const SizedBox(width: 6),
                          Text(context.lang == Language.en ? 'List' : 'జాబితా'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 6),
                          Text(context.lang == Language.en ? 'Calendar' : 'క్యాలెండర్'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.event_available, size: 18),
                          const SizedBox(width: 6),
                          Text(context.lang == Language.en ? 'My Events' : 'నా కార్యక్రమాలు'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Filter chips
            if (availableAccessLevels.isNotEmpty)
              SliverToBoxAdapter(
                child: AccessLevelFilterChips(
                  availableAccessLevels: availableAccessLevels,
                  selectedAccessLevel: selectedAccessLevel,
                  onLevelSelected: (level) {
                    setSelectedAccessLevel(level);
                    _applyFilter();
                  },
                ),
              ),
          ];
        },
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.grey[700]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchEvents,
                          child: Text(
                            context.lang == Language.en ? 'Retry' : 'మళ్లీ ప్రయత్నించండి',
                          ),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListView(),
                      _buildCalendarView(),
                      _buildMyEventsTab(),
                    ],
                  ),
      ),
    );
  }



  Widget _buildListView() {
    // Show filtered events sorted by date (upcoming first)
    final sortedEvents = List<DisplayEvent>.from(_filteredEvents)
      ..sort((a, b) {
        if (a.isUpcoming && !b.isUpcoming) return -1;
        if (!a.isUpcoming && b.isUpcoming) return 1;
        return a.date.compareTo(b.date);
      });

    if (sortedEvents.isEmpty) {
      return Center(
        child: Text(
          context.lang == Language.en
              ? 'No events available'
              : 'కార్యక్రమాలు అందుబాటులో లేవు',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: sortedEvents.length,
      itemBuilder: (context, index) {
        return _buildEventCard(sortedEvents[index]);
      },
    );
  }

  Widget _buildCalendarView() {
    final selectedDayEvents = _getSelectedDayEvents();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        // Calendar
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TableCalendar<DisplayEvent>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: const TextStyle(color: AppColors.secondary),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                markerSize: 6,
                canMarkersOverflow: true,
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: const BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                formatButtonTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                leftChevronIcon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.secondary,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right,
                  color: AppColors.secondary,
                ),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                if (!mounted) return;
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                if (!mounted) return;
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Selected Day Events
        Text(
          context.lang == Language.en
              ? 'Events on ${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay)}'
              : '${DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay)} న కార్యక్రమాలు',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (selectedDayEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                context.lang == Language.en
                    ? 'No events scheduled for this date'
                    : 'ఈ తేదీకి కార్యక్రమాలు లేవు',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...selectedDayEvents.map((event) => _buildEventCard(event)),
      ],
    );
  }

  Widget _buildMyEventsTab() {
    final lang = context.lang;
    final authService = Provider.of<AuthService>(context, listen: false);

    if (!authService.isAuthenticated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              lang == Language.en ? 'Login to view your events' : 'మీ కార్యక్రమాలు చూడటానికి లాగిన్ చేయండి',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isLoadingMyEvents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasErrorMyEvents) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              lang == Language.en ? 'Failed to load your events' : 'మీ కార్యక్రమాలు లోడ్ కాలేదు',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadMyEvents,
              child: Text(lang == Language.en ? 'Retry' : 'మళ్లీ ప్రయత్నించండి'),
            ),
          ],
        ),
      );
    }

    if (_myEvents.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMyEvents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_busy, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    lang == Language.en
                        ? 'No events yet\nTap "Create Event" to submit one'
                        : 'ఇంకా కార్యక్రమాలు లేవు\n"కార్యక్రమం సృష్టించు" నొక్కండి',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyEvents,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _myEvents.length,
        itemBuilder: (context, index) => _buildEventCard(_myEvents[index]),
      ),
    );
  }

  Widget _buildMyEventCard(DisplayEvent event) {
    final lang = context.lang;
    final isPending = !event.isPublished;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
            child: Row(
              children: [
                Icon(
                  isPending ? Icons.hourglass_top : Icons.check_circle,
                  size: 16,
                  color: isPending ? Colors.orange : AppColors.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  isPending
                      ? (lang == Language.en ? 'Pending Review' : 'సమీక్ష పెండింగ్')
                      : (lang == Language.en ? 'Published' : 'ప్రచురితమైంది'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPending ? Colors.orange.shade800 : AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          // Event info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.calendar_today,
                  text: DateFormat('MMM d, yyyy').format(event.date),
                ),
                const SizedBox(height: 4),
                _buildInfoRow(
                  icon: Icons.access_time,
                  text: _formatTimeTo12Hour(event.time),
                ),
                const SizedBox(height: 4),
                _buildInfoRow(
                  icon: Icons.location_on,
                  text: event.location,
                ),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(DisplayEvent event) {
    final isRSVPd = _rsvpEvents.contains(event.id);
    final isRsvping = _rsvpingEvents.contains(event.id);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Boarding Pass Section with Image or Calendar Icon
          _buildBoardingPassSection(event),

          // Event Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  event.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                // RSVP Count
                _buildInfoRow(
                  icon: Icons.people,
                  text: '${NumberFormat('#,###').format(event.rsvpCount)} ${context.lang == Language.en ? 'attending' : 'హాజరవుతున్నారు'}',
                ),
                const SizedBox(height: 16),

                // RSVP Button - Show for all events
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (isRsvping || !event.isUpcoming) 
                        ? null 
                        : () => _handleRSVP(event.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRSVPd 
                          ? AppColors.secondary 
                          : Colors.transparent,
                      foregroundColor: isRSVPd 
                          ? Colors.white 
                          : AppColors.secondary,
                      side: BorderSide(
                        color: AppColors.secondary,
                        width: isRSVPd ? 0 : 1,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
                    ),
                    child: isRsvping
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isRSVPd ? Colors.white : AppColors.secondary,
                              ),
                            ),
                          )
                        : Text(
                            !event.isUpcoming
                                ? (context.lang == Language.en 
                                    ? 'Event Ended' 
                                    : 'కార్యక్రమం ముగిసింది')
                                : isRSVPd
                                    ? (context.lang == Language.en 
                                        ? '✓ You\'re Attending' 
                                        : '✓ మీరు హాజరవుతున్నారు')
                                    : (context.lang == Language.en 
                                        ? 'Attend' 
                                        : 'మీరు హాజరవుతున్నారు'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeTo12Hour(String timeStr) {
    try {
      // Check if already in 12-hour format
      final timeLower = timeStr.toLowerCase().trim();
      if (timeLower.contains('am') || timeLower.contains('pm')) {
        return timeStr; // Already in 12-hour format
      }
      
      // Parse 24-hour format (HH:MM)
      final timeRegex = RegExp(r'(\d{1,2}):(\d{2})');
      final match = timeRegex.firstMatch(timeStr);
      if (match == null) return timeStr; // Return as-is if parsing fails
      
      int hours = int.parse(match.group(1)!);
      int minutes = int.parse(match.group(2)!);
      
      String period = 'AM';
      if (hours >= 12) {
        period = 'PM';
        if (hours > 12) {
          hours -= 12;
        }
      } else if (hours == 0) {
        hours = 12;
      }
      
      return '$hours:${minutes.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return timeStr; // Return original if conversion fails
    }
  }

  Widget _buildBoardingPassSection(DisplayEvent event) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Image or Calendar Icon Placeholder
          Container(
            width: 80,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: (event.image != null && event.image!.isNotEmpty)
                ? Image.network(
                    event.image!,
                    width: 80,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.event, size: 40, color: Colors.grey),
                      );
                    },
                  )
                : const Center(
                    child: Icon(Icons.event, size: 40, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 20),
          // Date, Time, and Location Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date
                Text(
                  DateFormat('MMM d, yyyy', 
                    context.lang == Language.en ? 'en_US' : 'te_IN'
                  ).format(event.date),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                // Time
                Text(
                  _formatTimeTo12Hour(event.time),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                // Location
                Text(
                  event.location,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeLocationRow(DisplayEvent event) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              DateFormat('MMM d, yyyy', 
                context.lang == Language.en ? 'en_US' : 'te_IN'
              ).format(event.date),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              _formatTimeTo12Hour(event.time),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                event.location,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Create Event Bottom Sheet ─────────────────────────────────────────────────

class _CreateEventSheet extends StatefulWidget {
  final String authToken;
  final ApiService apiService;
  final VoidCallback onSuccess;

  const _CreateEventSheet({
    required this.authToken,
    required this.apiService,
    required this.onSuccess,
  });

  @override
  State<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<_CreateEventSheet> {
  final _titleEnController    = TextEditingController();
  final _descEnController     = TextEditingController();
  final _locationEnController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  XFile? _selectedImage;
  bool _isSubmitting = false;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _titleEnController.dispose();
    _descEnController.dispose();
    _locationEnController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null && mounted) setState(() => _selectedImage = image);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.secondary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.secondary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    // Validate
    if (_titleEnController.text.trim().isEmpty ||
        _descEnController.text.trim().isEmpty ||
        _locationEnController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill in all required fields'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    // Capture context-dependent values before any await
    final timeStr = _selectedTime.format(context);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    setState(() => _isSubmitting = true);

    try {
      // Upload image first if selected
      String? imageUrl;
      if (_selectedImage != null) {
        final uploadResult = await widget.apiService.uploadEventImage(
          authToken: widget.authToken,
          filePath: _selectedImage!.path,
        );
        if (uploadResult['success'] == true) {
          imageUrl = uploadResult['data']?['url'] as String?;
        }
        // Image upload failure is non-fatal — proceed without image
      }

      final result = await widget.apiService.createUserEvent(
        authToken: widget.authToken,
        titleEn: _titleEnController.text.trim(),
        titleTe: _titleEnController.text.trim(),
        descriptionEn: _descEnController.text.trim(),
        descriptionTe: _descEnController.text.trim(),
        eventDate: dateStr,
        eventTime: timeStr,
        locationEn: _locationEnController.text.trim(),
        locationTe: _locationEnController.text.trim(),
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      if (result['success'] == true || result['statusCode'] == 201) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Event submitted successfully!'),
          backgroundColor: AppColors.secondary,
          duration: Duration(seconds: 3),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Submission failed. Please try again.'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.event_available, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  const Text(
                    'Create Event',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Title ---
                    _sectionLabel('Event Title *'),
                    const SizedBox(height: 8),
                    _textField(_titleEnController, 'Event title', maxLines: 1),
                    const SizedBox(height: 20),

                    // --- Date & Time ---
                    _sectionLabel('Date & Time *'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _pickerTile(
                            icon: Icons.calendar_today,
                            label: DateFormat('MMM d, yyyy').format(_selectedDate),
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _pickerTile(
                            icon: Icons.access_time,
                            label: _selectedTime.format(context),
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- Location ---
                    _sectionLabel('Location *'),
                    const SizedBox(height: 8),
                    _textField(_locationEnController, 'Event location', maxLines: 1),
                    const SizedBox(height: 20),

                    // --- Description ---
                    _sectionLabel('Description *'),
                    const SizedBox(height: 8),
                    _textField(_descEnController, 'Event description', maxLines: 4),
                    const SizedBox(height: 20),

                    // --- Image (optional) ---
                    _sectionLabel('Event Image (optional)'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: _selectedImage == null ? 110 : 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _selectedImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      size: 36, color: Colors.grey[400]),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tap to add a photo',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                  ),
                                ],
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedImage = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Submit Event',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      );

  Widget _textField(TextEditingController ctrl, String hint, {int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
          ),
        ),
      );

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
