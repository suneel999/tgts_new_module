import api from './api';

export type VoterRecord = {
  id: number;
  uploadBatchId: string;
  serialNo: string;
  voterName: string;
  relativeType: string;
  relativeName: string;
  houseNumber: string;
  age: number;
  dateOfBirth: string;
  gender: string;
  voterIdNumber: string;
  partNumber: string;
  boothNumber: string;
  boothName: string;
  address: string;
  phone: string;
  caste: string;
  color: string;
  isBeneficiary: boolean;
  isDuplicate: boolean;
  hasVoted: boolean;
  isEffective: boolean;
  createdAt: string;
  updatedAt: string;
};

export type VoterStats = {
  success: boolean;
  total: number;
  duplicates: number;
  beneficiaries: number;
  voted: number;
  nonVoted: number;
  effective: number;
  withPhone: number;
  male: number;
  female: number;
  colors: Record<string, number>;
  topCastes: { caste: string; count: number }[];
};

export type VoterListFilters = {
  search?: string;
  sort_by?: 'name' | 'booth' | 'phone' | 'address' | 'age' | 'caste' | 'color' | 'serial';
  sort_order?: 'asc' | 'desc';
  is_duplicate?: boolean;
  is_beneficiary?: boolean;
  has_voted?: boolean;
  is_effective?: boolean;
  has_phone?: boolean;
  color?: string;
  caste?: string;
  booth_number?: string;
  gender?: string;
  age_min?: number;
  age_max?: number;
  page?: number;
  per_page?: number;
};

export type VoterListResponse = {
  success: boolean;
  data: VoterRecord[];
  total: number;
  page: number;
  per_page: number;
  total_pages: number;
};

export type UploadResult = {
  success: boolean;
  message: string;
  batchId: string;
  imported: number;
  skipped: number;
  errors: { row: number; error: string }[];
  replaceAll: boolean;
};

export type VoterUpdatePayload = {
  color?: string;
  caste?: string;
  phone?: string;
  isBeneficiary?: boolean;
  hasVoted?: boolean;
  isEffective?: boolean;
  isDuplicate?: boolean;
};

export type BatchInfo = {
  batchId: string;
  count: number;
  uploadedAt: string | null;
};

export type CompareResult = {
  success: boolean;
  oldBatch: string;
  newBatch: string;
  oldCount: number;
  newCount: number;
  addedCount: number;
  deletedCount: number;
  added: VoterRecord[];
  deleted: VoterRecord[];
};

export const voterListService = {
  async getVoters(filters: VoterListFilters = {}): Promise<VoterListResponse> {
    const response = await api.get('/voter-list/', { params: filters });
    return response.data;
  },

  async getStats(): Promise<VoterStats> {
    const response = await api.get('/voter-list/stats/');
    return response.data;
  },

  async getBooths(): Promise<{ data: { boothNumber: string; boothName: string; count: number }[] }> {
    const response = await api.get('/voter-list/booths/');
    return response.data;
  },

  async getCastes(): Promise<{ data: { caste: string; count: number }[] }> {
    const response = await api.get('/voter-list/castes/');
    return response.data;
  },

  async uploadFile(file: File, replaceAll = false): Promise<UploadResult> {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('replace_all', replaceAll ? 'true' : 'false');
    // const response = await api.post('/voter-list/upload/', formData);
     const response = await api.post('/voter-list/upload/', formData, {                                                                                                    
        timeout: 300000,                                                                                                                                                  
        headers: { 'Content-Type': 'multipart/form-data' }                                                                                                                
    });
    return response.data;
  },

  async updateVoter(id: number, payload: VoterUpdatePayload): Promise<VoterRecord> {
    const response = await api.put(`/voter-list/${id}/`, payload);
    return response.data.data;
  },

  async deleteBatch(batchId: string): Promise<{ deleted: number }> {
    const response = await api.delete(`/voter-list/batch/${batchId}/`);
    return response.data;
  },

  async clearAll(): Promise<{ deleted: number }> {
    const response = await api.delete('/voter-list/clear/');
    return response.data;
  },

  async getBatches(): Promise<{ success: boolean; data: BatchInfo[] }> {
    const response = await api.get('/voter-list/batches/');
    return response.data;
  },

  async compareBatches(batchOld: string, batchNew: string): Promise<CompareResult> {
    const response = await api.get('/voter-list/compare/', {
      params: { batch_old: batchOld, batch_new: batchNew },
    });
    return response.data;
  },
};
