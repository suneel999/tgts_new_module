import api from './api';

export type Document = {
  id: string | number; // Document IDs are UUID strings
  title_en: string;
  title_te?: string;
  description_en?: string;
  description_te?: string;
  category: string;
  file_url: string | null;
  file_type: string;
  file_size: number;
  access_level: string[];
  is_published: boolean;
  districtIds?: number[];
  mandalIds?: number[];
  assemblyConstituencyIds?: number[];
  parliamentaryConstituencyIds?: number[];
  uploaded_by: number;
  created_at: string;
  updated_at: string;
};

export type DocumentFilters = {
  page?: number;
  per_page?: number;
  category?: string;
  all?: boolean; // For admins to see all documents including unpublished
};

export type CreateDocumentRequest = {
  title_en: string;
  title_te?: string;
  description_en?: string;
  description_te?: string;
  category: string;
  file_url: string;
  file_type: string;
  file_size: number;
  access_level?: string[];
  is_published?: boolean;
  districtIds?: number[];
  mandalIds?: number[];
  assemblyConstituencyIds?: number[];
  parliamentaryConstituencyIds?: number[];
};

export const documentService = {
  // Get all documents
  async getDocuments(filters: DocumentFilters = {}) {
    const response = await api.get('/documents/', { params: filters });
    return response.data;
  },

  // Get document by ID
  async getDocumentById(documentId: string | number): Promise<Document> {
    const response = await api.get(`/documents/${documentId}`);
    return response.data;
  },

  // Create document (admin only)
  async createDocument(data: CreateDocumentRequest): Promise<Document> {
    const response = await api.post('/documents/', data);
    return response.data;
  },

  // Update document (admin only)
  async updateDocument(documentId: string | number, data: Partial<CreateDocumentRequest>): Promise<Document> {
    const response = await api.put(`/documents/${documentId}`, data);
    return response.data;
  },

  // Delete document (admin only)
  async deleteDocument(documentId: string | number) {
    const response = await api.delete(`/documents/${documentId}`);
    return response.data;
  },

  // Upload file
  async uploadFile(file: File) {
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
    const response = await api.post('/documents/upload', formData, {
      headers,
    });
    return response.data;
  },
};

