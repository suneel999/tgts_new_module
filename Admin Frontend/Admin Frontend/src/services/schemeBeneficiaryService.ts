import api from './api';

export const VALID_SCHEMES = ['maha_lakshmi', 'cheyutha', 'rythu_bharosa', 'indiramma_indlu'] as const;
export type SchemeName = typeof VALID_SCHEMES[number];

export const SCHEME_DISPLAY: Record<SchemeName, string> = {
  maha_lakshmi:    'Maha Lakshmi',
  cheyutha:        'Cheyutha',
  rythu_bharosa:   'Rythu Bharosa',
  indiramma_indlu: 'Indiramma Indlu',
};

export type SchemeBeneficiaryRecord = {
  id: number;
  schemeName: SchemeName;
  schemeDisplay: string;
  uploadBatchId: string;
  name: string;
  phone: string;
  address: string;
  village: string;
  mandal: string;
  district: string;
  aadharNo: string;
  accountNo: string;
  amount: string;
  createdAt: string;
  updatedAt: string;
};

export type SchemeInfo = {
  schemeName: SchemeName;
  displayName: string;
  count: number;
};

export type SchemeBatchInfo = {
  batchId: string;
  schemeName: SchemeName;
  displayName: string;
  count: number;
  uploadedAt: string | null;
};

export type SchemeBeneficiaryFilters = {
  scheme_name?: SchemeName;
  search?: string;
  mandal?: string;
  district?: string;
  sort_by?: 'name' | 'mandal' | 'district' | 'amount' | 'created';
  page?: number;
  per_page?: number;
};

export type SchemeBeneficiaryResponse = {
  success: boolean;
  data: SchemeBeneficiaryRecord[];
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
};

export const schemeBeneficiaryService = {
  async getBeneficiaries(filters: SchemeBeneficiaryFilters = {}): Promise<SchemeBeneficiaryResponse> {
    const response = await api.get('/scheme-beneficiaries/', { params: filters });
    return response.data;
  },

  async getSchemes(): Promise<{ success: boolean; data: SchemeInfo[] }> {
    const response = await api.get('/scheme-beneficiaries/schemes/');
    return response.data;
  },

  async getBatches(scheme?: SchemeName): Promise<{ success: boolean; data: SchemeBatchInfo[] }> {
    const response = await api.get('/scheme-beneficiaries/batches/', {
      params: scheme ? { scheme_name: scheme } : {},
    });
    return response.data;
  },

  async uploadFile(file: File, schemeName: SchemeName, replaceAll = false): Promise<UploadResult> {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('scheme_name', schemeName);
    formData.append('replace_all', replaceAll ? 'true' : 'false');
    const response = await api.post('/scheme-beneficiaries/upload/', formData, {
      timeout: 300000,
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    return response.data;
  },

  async deleteBatch(batchId: string): Promise<{ success: boolean; deleted: number }> {
    const response = await api.delete(`/scheme-beneficiaries/batch/${batchId}/`);
    return response.data;
  },

  async clearScheme(schemeName: SchemeName): Promise<{ success: boolean; deleted: number }> {
    const response = await api.delete(`/scheme-beneficiaries/scheme/${schemeName}/clear/`);
    return response.data;
  },
};
