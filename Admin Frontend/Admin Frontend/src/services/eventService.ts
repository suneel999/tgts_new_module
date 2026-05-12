import api from './api';

// Backend API response format (from event.to_dict())
export type Event = {
  id: string;
  title: {
    en: string;
    te: string;
  };
  description: {
    en: string;
    te: string;
  };
  date: string; // ISO format: "2025-10-25T00:00:00"
  time: string;
  location: {
    en: string;
    te: string;
  };
  image?: string;
  rsvpCount: number;
  isPublished: boolean;
  accessLevel?: string;  // 'public', 'cadre', or 'admin'
  creatorCadreLevel?: number;
  districtIds?: number[];
  mandalIds?: number[];
  assemblyConstituencyIds?: number[];
  parliamentaryConstituencyIds?: number[];
};

export type EventsResponse = {
  events: Event[];
  total: number;
  pages: number;
  current_page: number;
};

export type EventFilters = {
  page?: number;
  per_page?: number;
  upcoming_only?: boolean;
  published_only?: boolean;
};

// Request format for creating/updating events (backend expects snake_case)
export type CreateEventRequest = {
  title_en: string;
  title_te: string;
  description_en: string;
  description_te: string;
  event_date: string; // ISO format: "2025-10-25" or "2025-10-25T00:00:00"
  event_time: string;
  location_en: string;
  location_te: string;
  image_url?: string | null; // null to clear image, undefined to omit
  is_published?: boolean;
  access_level?: string;  // 'public', 'cadre', or 'admin'
  districtIds?: number[];
  mandalIds?: number[];
  assemblyConstituencyIds?: number[];
  parliamentaryConstituencyIds?: number[];
};

// RSVP/Attendee type
export type RSVP = {
  id: string;
  event_id: string;
  phone_number: string;
  created_at: string; // ISO format
};

// Response format for getting attendees
export type AttendeesResponse = {
  event_id: string;
  event_title: {
    en: string;
    te: string;
  };
  rsvp_count: number;
  rsvps: RSVP[];
};

export const eventService = {
  // Get all events
  async getEvents(filters: EventFilters = {}): Promise<EventsResponse> {
    const response = await api.get('/events/', { params: filters });
    return response.data;
  },

  // Get event by ID
  async getEventById(eventId: string): Promise<Event> {
    const response = await api.get(`/events/${eventId}`);
    return response.data;
  },

  // Create event (admin only)
  async createEvent(data: CreateEventRequest): Promise<Event> {
    const response = await api.post('/events/', data);
    return response.data;
  },

  // Update event (admin only)
  async updateEvent(eventId: string, data: Partial<CreateEventRequest>): Promise<Event> {
    const response = await api.put(`/events/${eventId}`, data);
    return response.data;
  },

  // Delete event (admin only)
  async deleteEvent(eventId: string) {
    const response = await api.delete(`/events/${eventId}`);
    return response.data;
  },

  // RSVP to event
  async rsvpToEvent(eventId: string) {
    const response = await api.post(`/events/${eventId}/rsvp`);
    return response.data;
  },

  // Get attendees/RSVPs for an event (admin only)
  async getEventAttendees(eventId: string): Promise<AttendeesResponse> {
    const response = await api.get(`/events/${eventId}/rsvp`);
    return response.data;
  },

  // Upload event image (admin/cadre only)
  async uploadEventImage(file: File): Promise<{ url: string; filename: string; message: string }> {
    const formData = new FormData();
    formData.append('file', file);
    
    // Get token from localStorage to ensure it's included
    const token = localStorage.getItem('token');
    const headers: Record<string, string> = {};
    
    // Add Authorization header if token exists
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    
    // Don't set Content-Type manually - let axios set it with boundary for FormData
    const response = await api.post('/events/upload-image', formData, {
      headers,
    });
    return response.data;
  },
};

