import api from './api';

// Dashboard statistics type definition
export type DashboardStats = {
  total_users: number;
  active_users: number;
  total_events: number;
  upcoming_events: number;
  total_news: number;
  published_news: number;
  total_media: number;
  total_documents: number;
  user_growth?: {
    date: string;
    count: number;
  }[];
  user_by_role?: {
    role: string;
    count: number;
  }[];
  recent_activity?: {
    type: string;
    title: string;
    timestamp: string;
  }[];
};

export type ContentPushRequest = {
  title: string;
  title_te?: string;
  message: string;
  description_te?: string;
  target_roles?: string[];
  target_regions?: string[];
  content_type?: string;
  content_id?: number;
  image_url?: string;
  category?: string;
  districtIds?: number[];
  mandalIds?: number[];
  assemblyConstituencyIds?: number[];
  parliamentaryConstituencyIds?: number[];
  links?: Array<{ platform: string; url: string }>;
};

export type SystemHealth = {
  status: string;
  database: string;
  uptime: number;
  memory_usage: number;
  timestamp: string;
};

export type NewsItem = {
  id: string;
  title: {
    en: string;
    te: string;
  };
  description: {
    en: string;
    te: string;
  };
  image?: string;
  category: string;
  date: string;
  isPublished: boolean;
  districtIds?: number[];
  mandalIds?: number[];
  assemblyConstituencyIds?: number[];
  parliamentaryConstituencyIds?: number[];
  links?: Array<{ platform: string; url: string }>;
};

export type NewsListResponse = {
  news: NewsItem[];
  total: number;
  pages: number;
  current_page: number;
};

export type NewsUpdateRequest = {
  title_en?: string;
  title_te?: string;
  description_en?: string;
  description_te?: string;
  image_url?: string;
  category?: string;
  is_published?: boolean;
  districtIds?: number[];
  mandalIds?: number[];
  assemblyConstituencyIds?: number[];
  parliamentaryConstituencyIds?: number[];
  links?: Array<{ platform: string; url: string }>;
};

export const adminService = {
  // Get dashboard statistics
  async getDashboardStats(): Promise<DashboardStats> {
    const response = await api.get('/admin/dashboard');
    return response.data;
  },

  // Get analytics data
  async getAnalytics(filters?: { start_date?: string; end_date?: string }) {
    const response = await api.get('/admin/analytics', { params: filters });
    return response.data;
  },

  // Push content to users
  async pushContent(data: ContentPushRequest) {
    const response = await api.post('/admin/content-push', data);
    return response.data;
  },

  // Get system health
  async getSystemHealth(): Promise<SystemHealth> {
    const response = await api.get('/admin/system-health');
    return response.data;
  },

  // Get all news items (admin only)
  async getAllNews(params?: { page?: number; per_page?: number; category?: string; published_only?: boolean }): Promise<NewsListResponse> {
    const response = await api.get('/news/admin/all', { params });
    return response.data;
  },

  // Get single news item
  async getNewsItem(newsId: string): Promise<NewsItem> {
    const response = await api.get(`/news/${newsId}`);
    return response.data;
  },

  // Update news item
  async updateNewsItem(newsId: string, data: NewsUpdateRequest): Promise<NewsItem> {
    const response = await api.put(`/news/${newsId}`, data);
    return response.data;
  },

  // Delete news item
  async deleteNewsItem(newsId: string): Promise<void> {
    await api.delete(`/news/${newsId}`);
  },
};

