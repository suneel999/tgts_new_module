import api from './api';

export type MediaItem = {
  id: string;
  type: 'photo' | 'video';
  url: string;
  thumbnail?: string;
  title: {
    en: string;
    te: string;
  };
  date: string;
  isPublished: boolean;
  access_level?: Array<"public" | "cadre" | "admin">;
  creatorCadreLevel?: number;
  districtIds?: number[];
  mandalIds?: number[];
  assemblyConstituencyIds?: number[];
  parliamentaryConstituencyIds?: number[];
};

export type MediaListResponse = {
  media: MediaItem[];
  total: number;
  pages: number;
  current_page: number;
};

export type CreateMediaRequest = {
  type: 'photo' | 'video';
  url: string;
  thumbnail_url?: string;
  title_en: string;
  title_te: string;
  is_published?: boolean;
  access_level?: Array<"public" | "cadre" | "admin">;
  districtIds?: number[];
  mandalIds?: number[];
  assemblyConstituencyIds?: number[];
  parliamentaryConstituencyIds?: number[];
};

export type MediaFilters = {
  page?: number;
  per_page?: number;
  type?: 'photo' | 'video';
};

export type MediaStats = {
  photo_count: number;
  video_count: number;
  total_count: number;
  updated_at?: string;
};

export const mediaService = {
  // Get all media items (admin can see all, including unpublished)
  async getMedia(filters: MediaFilters = {}): Promise<MediaListResponse> {
    // Add 'all=true' parameter to get all items including unpublished (for admin panel)
    const params = { ...filters, all: 'true' };
    const response = await api.get('/media/', { params });
    return response.data;
  },

  // Get media item by ID
  async getMediaById(mediaId: string): Promise<MediaItem> {
    const response = await api.get(`/media/${mediaId}`);
    return response.data;
  },

  // Create media item (admin/cadre only)
  async createMedia(data: CreateMediaRequest): Promise<MediaItem> {
    console.log('Creating media with data:', data);
    const response = await api.post('/media/', data);
    console.log('Create media response:', response.data);
    return response.data;
  },

  // Upload file and get URL
  async uploadFile(file: File, type: 'photo' | 'video', folder?: string): Promise<{ url: string; thumbnail_url?: string }> {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('type', type);
    
    // Add folder if specified
    if (folder) {
      formData.append('folder', folder);
    }
    
    // Get token from localStorage to ensure it's included
    const token = localStorage.getItem('token');
    const headers: Record<string, string> = {};
    
    // Add Authorization header if token exists
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    
    // Don't set Content-Type manually - let axios set it with boundary for FormData
    const response = await api.post('/media/upload', formData, {
      headers,
    });
    return response.data;
  },

  // Upload media with file (combines upload + create)
  async uploadMedia(file: File, data: Omit<CreateMediaRequest, 'url' | 'thumbnail_url'>, folder?: string): Promise<MediaItem> {
    console.log('Upload media called with data:', data);
    // First upload the file
    const uploadResult = await this.uploadFile(file, data.type, folder);
    console.log('File upload result:', uploadResult);
    
    // Then create the media item with the uploaded URL
    const createData = {
      ...data,
      url: uploadResult.url,
      thumbnail_url: uploadResult.thumbnail_url,
    };
    console.log('About to create media with:', createData);
    return this.createMedia(createData);
  },

  // Update media item
  async updateMedia(mediaId: string, data: Partial<CreateMediaRequest>): Promise<MediaItem> {
    const response = await api.put(`/media/${mediaId}`, data);
    return response.data;
  },

  // Delete media item permanently
  async deleteMedia(mediaId: string): Promise<void> {
    await api.delete(`/media/${mediaId}`);
  },

  // Publish media item
  async publishMedia(mediaId: string): Promise<MediaItem> {
    return this.updateMedia(mediaId, { is_published: true });
  },

  // Unpublish media item
  async unpublishMedia(mediaId: string): Promise<MediaItem> {
    return this.updateMedia(mediaId, { is_published: false });
  },

  // Get media statistics (photo and video counts)
  async getMediaStats(): Promise<MediaStats> {
    const response = await api.get('/media/stats');
    return response.data;
  },
};

