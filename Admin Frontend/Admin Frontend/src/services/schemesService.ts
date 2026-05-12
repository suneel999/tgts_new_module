import api from './api';

export const SCHEME_CATEGORIES = [
  'welfare', 'agriculture', 'housing', 'women',
  'youth', 'education', 'health', 'other',
] as const;

export type SchemeCategory = typeof SCHEME_CATEGORIES[number];

export const CATEGORY_LABELS: Record<SchemeCategory, string> = {
  welfare:     'Welfare',
  agriculture: 'Agriculture',
  housing:     'Housing',
  women:       'Women',
  youth:       'Youth',
  education:   'Education',
  health:      'Health',
  other:       'Other',
};

export const CATEGORY_COLORS: Record<SchemeCategory, { bg: string; text: string }> = {
  welfare:     { bg: 'bg-purple-100', text: 'text-purple-700' },
  agriculture: { bg: 'bg-green-100',  text: 'text-green-700'  },
  housing:     { bg: 'bg-amber-100',  text: 'text-amber-700'  },
  women:       { bg: 'bg-pink-100',   text: 'text-pink-700'   },
  youth:       { bg: 'bg-blue-100',   text: 'text-blue-700'   },
  education:   { bg: 'bg-indigo-100', text: 'text-indigo-700' },
  health:      { bg: 'bg-red-100',    text: 'text-red-700'    },
  other:       { bg: 'bg-gray-100',   text: 'text-gray-700'   },
};

export type BilingualText = { en: string; te: string };

export type SchemeRecord = {
  id: string;
  title: BilingualText;
  description: BilingualText;
  category: SchemeCategory;
  imageUrl: string;
  eligibility: BilingualText;
  benefits: BilingualText;
  applyLink: string;
  isPublished: boolean;
  createdAt: string | null;
  updatedAt: string | null;
};

export type SchemeFormData = {
  title_en: string;
  title_te: string;
  description_en: string;
  description_te: string;
  category: SchemeCategory;
  image_url: string;
  eligibility_en: string;
  eligibility_te: string;
  benefits_en: string;
  benefits_te: string;
  apply_link: string;
  is_published: boolean;
};

export const EMPTY_FORM: SchemeFormData = {
  title_en: '', title_te: '',
  description_en: '', description_te: '',
  category: 'welfare',
  image_url: '',
  eligibility_en: '', eligibility_te: '',
  benefits_en: '', benefits_te: '',
  apply_link: '',
  is_published: false,
};

export const schemesService = {
  async getSchemes(): Promise<{ success: boolean; data: SchemeRecord[]; total: number }> {
    const response = await api.get('/schemes/', { params: { all: 'true' } });
    return response.data;
  },

  async createScheme(data: SchemeFormData): Promise<{ success: boolean; data: SchemeRecord }> {
    const response = await api.post('/schemes/', data);
    return response.data;
  },

  async updateScheme(id: string, data: Partial<SchemeFormData>): Promise<{ success: boolean; data: SchemeRecord }> {
    const response = await api.put(`/schemes/${id}/`, data);
    return response.data;
  },

  async deleteScheme(id: string): Promise<{ success: boolean; message: string }> {
    const response = await api.delete(`/schemes/${id}/`);
    return response.data;
  },

  async uploadImage(file: File): Promise<{ success: boolean; url: string }> {
    const formData = new FormData();
    formData.append('file', file);
    const response = await api.post('/schemes/upload-image/', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    return response.data;
  },
};
