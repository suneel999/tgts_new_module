import { useState, useEffect, useRef, useCallback } from 'react';
import {
  Upload, Search, Users, Trash2, RefreshCw, X,
  ChevronLeft, ChevronRight, AlertCircle, CheckCircle,
  FileSpreadsheet, FileText, Gift, Filter,
} from 'lucide-react';
import clsx from 'clsx';
import {
  schemeBeneficiaryService,
  VALID_SCHEMES, SCHEME_DISPLAY,
  type SchemeName, type SchemeBeneficiaryRecord,
  type SchemeBatchInfo,
} from '../../services/schemeBeneficiaryService';

// ─── SCHEME CONFIG ────────────────────────────────────────────────────────────

const SCHEME_COLORS: Record<SchemeName, { bg: string; text: string; border: string; icon: string }> = {
  maha_lakshmi:    { bg: 'bg-pink-50',   text: 'text-pink-700',   border: 'border-pink-300',  icon: 'bg-pink-100' },
  cheyutha:        { bg: 'bg-blue-50',   text: 'text-blue-700',   border: 'border-blue-300',  icon: 'bg-blue-100' },
  rythu_bharosa:   { bg: 'bg-green-50',  text: 'text-green-700',  border: 'border-green-300', icon: 'bg-green-100' },
  indiramma_indlu: { bg: 'bg-amber-50',  text: 'text-amber-700',  border: 'border-amber-300', icon: 'bg-amber-100' },
};

// ─── UPLOAD MODAL ─────────────────────────────────────────────────────────────

function UploadModal({
  scheme,
  onClose,
  onDone,
}: {
  scheme: SchemeName;
  onClose: () => void;
  onDone: () => void;
}) {
  const [file, setFile]           = useState<File | null>(null);
  const [replaceAll, setReplaceAll] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [result, setResult]       = useState<{ success: boolean; message: string; imported?: number } | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const handleUpload = async () => {
    if (!file) return;
    setUploading(true);
    setResult(null);
    try {
      const res = await schemeBeneficiaryService.uploadFile(file, scheme, replaceAll);
      setResult({ success: res.success, message: res.message, imported: res.imported });
      if (res.success) onDone();
    } catch (e: unknown) {
      // Extract the actual error message from the server response if available
      const axiosErr = e as { response?: { data?: { message?: string } }; message?: string };
      const msg =
        axiosErr?.response?.data?.message ||
        (e instanceof Error ? e.message : 'Upload failed');
      setResult({ success: false, message: msg });
    } finally {
      setUploading(false);
    }
  };

  const ext = file?.name.split('.').pop()?.toLowerCase();
  const FileIcon = ext === 'xlsx' || ext === 'xls' ? FileSpreadsheet : FileText;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b">
          <div>
            <h2 className="text-lg font-bold text-gray-900">Upload Beneficiaries</h2>
            <p className="text-sm text-gray-500">{SCHEME_DISPLAY[scheme]}</p>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-lg transition">
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        <div className="px-6 py-5 space-y-4">
          {/* File picker */}
          <div
            className="border-2 border-dashed border-gray-300 rounded-xl p-6 text-center cursor-pointer hover:border-blue-400 hover:bg-blue-50/30 transition"
            onClick={() => fileRef.current?.click()}
          >
            <input
              ref={fileRef}
              type="file"
              accept=".csv,.xlsx,.xls"
              className="hidden"
              onChange={e => setFile(e.target.files?.[0] ?? null)}
            />
            {file ? (
              <div className="flex items-center gap-3 justify-center">
                <FileIcon className="w-8 h-8 text-blue-600" />
                <div className="text-left">
                  <p className="font-medium text-gray-800 text-sm">{file.name}</p>
                  <p className="text-xs text-gray-400">{(file.size / 1024).toFixed(1)} KB</p>
                </div>
                <button
                  onClick={e => { e.stopPropagation(); setFile(null); }}
                  className="ml-2 p-1 hover:bg-gray-200 rounded-full"
                >
                  <X className="w-4 h-4 text-gray-500" />
                </button>
              </div>
            ) : (
              <>
                <Upload className="w-8 h-8 text-gray-400 mx-auto mb-2" />
                <p className="text-sm text-gray-600 font-medium">Click to select CSV or Excel file</p>
                <p className="text-xs text-gray-400 mt-1">Columns: name, phone, address, village, mandal, district, aadhar_no, account_no, amount</p>
              </>
            )}
          </div>

          {/* Replace toggle */}
          <label className="flex items-center gap-3 cursor-pointer select-none">
            <input
              type="checkbox"
              checked={replaceAll}
              onChange={e => setReplaceAll(e.target.checked)}
              className="w-4 h-4 accent-red-500"
            />
            <span className="text-sm text-gray-700">Replace all existing data for this scheme</span>
          </label>

          {/* Result */}
          {result && (
            <div className={clsx(
              'flex items-start gap-2 p-3 rounded-lg text-sm',
              result.success ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700',
            )}>
              {result.success
                ? <CheckCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
                : <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />}
              <span>{result.message}{result.imported != null ? ` (${result.imported} imported)` : ''}</span>
            </div>
          )}

          {/* Actions */}
          <div className="flex gap-3 pt-1">
            <button
              onClick={onClose}
              className="flex-1 px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50 transition"
            >
              Cancel
            </button>
            <button
              onClick={handleUpload}
              disabled={!file || uploading}
              className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition flex items-center justify-center gap-2"
            >
              {uploading ? (
                <><RefreshCw className="w-4 h-4 animate-spin" /> Uploading…</>
              ) : (
                <><Upload className="w-4 h-4" /> Upload</>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── BATCH MANAGER ────────────────────────────────────────────────────────────

function BatchManager({ scheme, onRefresh }: { scheme: SchemeName; onRefresh: () => void }) {
  const [batches, setBatches]   = useState<SchemeBatchInfo[]>([]);
  const [loading, setLoading]   = useState(true);
  const [deleting, setDeleting] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await schemeBeneficiaryService.getBatches(scheme);
      setBatches(res.data);
    } finally {
      setLoading(false);
    }
  }, [scheme]);

  useEffect(() => { load(); }, [load]);

  const handleDelete = async (batchId: string) => {
    if (!window.confirm(`Delete batch "${batchId}"?`)) return;
    setDeleting(batchId);
    try {
      await schemeBeneficiaryService.deleteBatch(batchId);
      onRefresh();
      load();
    } finally {
      setDeleting(null);
    }
  };

  if (loading) return <p className="text-sm text-gray-400 px-1">Loading batches…</p>;
  if (!batches.length) return <p className="text-sm text-gray-400 px-1">No batches uploaded yet.</p>;

  return (
    <div className="space-y-2">
      {batches.map(b => (
        <div key={b.batchId} className="flex items-center justify-between bg-gray-50 border rounded-lg px-3 py-2">
          <div>
            <p className="text-sm font-medium text-gray-800">{b.batchId}</p>
            <p className="text-xs text-gray-400">
              {b.count.toLocaleString()} records
              {b.uploadedAt ? ` · ${new Date(b.uploadedAt).toLocaleDateString()}` : ''}
            </p>
          </div>
          <button
            onClick={() => handleDelete(b.batchId)}
            disabled={deleting === b.batchId}
            className="p-1.5 text-red-500 hover:bg-red-50 rounded-lg transition disabled:opacity-50"
          >
            {deleting === b.batchId
              ? <RefreshCw className="w-4 h-4 animate-spin" />
              : <Trash2 className="w-4 h-4" />}
          </button>
        </div>
      ))}
    </div>
  );
}

// ─── BENEFICIARY TABLE ────────────────────────────────────────────────────────

function BeneficiaryTable({
  scheme,
  refreshKey,
}: {
  scheme: SchemeName;
  refreshKey: number;
}) {
  const [items, setItems]     = useState<SchemeBeneficiaryRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch]   = useState('');
  const [page, setPage]       = useState(1);
  const [total, setTotal]     = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const perPage = 50;
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const load = useCallback(async (p: number, q: string) => {
    setLoading(true);
    try {
      const res = await schemeBeneficiaryService.getBeneficiaries({
        scheme_name: scheme,
        search: q || undefined,
        page: p,
        per_page: perPage,
      });
      setItems(res.data);
      setTotal(res.total);
      setTotalPages(res.total_pages);
    } finally {
      setLoading(false);
    }
  }, [scheme]);

  useEffect(() => {
    setPage(1);
    load(1, search);
  }, [scheme, refreshKey, load]);

  const handleSearchChange = (val: string) => {
    setSearch(val);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      setPage(1);
      load(1, val);
    }, 400);
  };

  const handlePage = (p: number) => {
    setPage(p);
    load(p, search);
  };

  const colors = SCHEME_COLORS[scheme];

  return (
    <div className="space-y-4">
      {/* Search + count */}
      <div className="flex items-center gap-3">
        <div className="relative flex-1 max-w-xs">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            value={search}
            onChange={e => handleSearchChange(e.target.value)}
            placeholder="Search by name, phone, mandal…"
            className="w-full pl-9 pr-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
          />
          {search && (
            <button onClick={() => handleSearchChange('')} className="absolute right-2 top-1/2 -translate-y-1/2">
              <X className="w-3.5 h-3.5 text-gray-400" />
            </button>
          )}
        </div>
        <span className="text-sm text-gray-500">{total.toLocaleString()} beneficiaries</span>
      </div>

      {/* Table */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <RefreshCw className="w-6 h-6 animate-spin text-gray-400" />
        </div>
      ) : items.length === 0 ? (
        <div className="text-center py-12 text-gray-400">
          <Gift className="w-12 h-12 mx-auto mb-3 opacity-30" />
          <p className="text-sm">No beneficiaries found.</p>
          {!search && <p className="text-xs mt-1">Upload a CSV or Excel file to get started.</p>}
        </div>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-gray-200">
          <table className="w-full text-sm">
            <thead className={clsx('text-xs font-semibold uppercase tracking-wide', colors.bg, colors.text)}>
              <tr>
                {['#', 'Name', 'Phone', 'Village / Mandal', 'District', 'Aadhar No', 'Account No', 'Amount'].map(h => (
                  <th key={h} className="px-4 py-3 text-left whitespace-nowrap">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {items.map((b, i) => (
                <tr key={b.id} className="hover:bg-gray-50 transition">
                  <td className="px-4 py-2.5 text-gray-400 text-xs">{(page - 1) * perPage + i + 1}</td>
                  <td className="px-4 py-2.5 font-medium text-gray-900 whitespace-nowrap">{b.name}</td>
                  <td className="px-4 py-2.5 text-gray-600">{b.phone || '—'}</td>
                  <td className="px-4 py-2.5 text-gray-600 max-w-[160px] truncate">
                    {[b.village, b.mandal].filter(Boolean).join(', ') || '—'}
                  </td>
                  <td className="px-4 py-2.5 text-gray-600">{b.district || '—'}</td>
                  <td className="px-4 py-2.5 text-gray-600 font-mono text-xs">{b.aadharNo || '—'}</td>
                  <td className="px-4 py-2.5 text-gray-600 font-mono text-xs">{b.accountNo || '—'}</td>
                  <td className="px-4 py-2.5 font-medium text-green-700">{b.amount || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between">
          <button
            onClick={() => handlePage(page - 1)}
            disabled={page <= 1}
            className="flex items-center gap-1 px-3 py-1.5 text-sm border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition"
          >
            <ChevronLeft className="w-4 h-4" /> Prev
          </button>
          <span className="text-sm text-gray-500">Page {page} of {totalPages}</span>
          <button
            onClick={() => handlePage(page + 1)}
            disabled={page >= totalPages}
            className="flex items-center gap-1 px-3 py-1.5 text-sm border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed transition"
          >
            Next <ChevronRight className="w-4 h-4" />
          </button>
        </div>
      )}
    </div>
  );
}

// ─── MAIN COMPONENT ───────────────────────────────────────────────────────────

export default function SchemeBeneficiaryManagement() {
  const [schemeCounts, setSchemeCounts] = useState<Record<SchemeName, number>>({
    maha_lakshmi: 0, cheyutha: 0, rythu_bharosa: 0, indiramma_indlu: 0,
  });
  const [activeScheme, setActiveScheme] = useState<SchemeName>('maha_lakshmi');
  const [showUpload, setShowUpload]     = useState(false);
  const [showBatches, setShowBatches]   = useState(false);
  const [refreshKey, setRefreshKey]     = useState(0);
  const [clearingScheme, setClearingScheme] = useState(false);

  const loadCounts = useCallback(async () => {
    try {
      const res = await schemeBeneficiaryService.getSchemes();
      const counts: Record<SchemeName, number> = {
        maha_lakshmi: 0, cheyutha: 0, rythu_bharosa: 0, indiramma_indlu: 0,
      };
      res.data.forEach(s => { counts[s.schemeName] = s.count; });
      setSchemeCounts(counts);
    } catch { /* silent */ }
  }, []);

  useEffect(() => { loadCounts(); }, [loadCounts, refreshKey]);

  const handleUploadDone = () => {
    setRefreshKey(k => k + 1);
  };

  const handleClearScheme = async () => {
    if (!window.confirm(`Delete ALL data for ${SCHEME_DISPLAY[activeScheme]}? This cannot be undone.`)) return;
    setClearingScheme(true);
    try {
      await schemeBeneficiaryService.clearScheme(activeScheme);
      setRefreshKey(k => k + 1);
    } finally {
      setClearingScheme(false);
    }
  };

  const colors = SCHEME_COLORS[activeScheme];

  return (
    <div className="p-6 space-y-6">
      {/* Page header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Scheme Beneficiaries</h1>
          <p className="text-sm text-gray-500 mt-0.5">Upload and manage government scheme beneficiary data</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowBatches(v => !v)}
            className="flex items-center gap-2 px-3 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50 transition"
          >
            <Filter className="w-4 h-4" />
            {showBatches ? 'Hide Batches' : 'Manage Batches'}
          </button>
          <button
            onClick={() => setShowUpload(true)}
            className="flex items-center gap-2 px-5 py-2.5 bg-blue-600 text-white rounded-lg text-sm font-semibold hover:bg-blue-700 transition shadow-sm"
          >
            <Upload className="w-4 h-4" /> Upload Beneficiaries
          </button>
        </div>
      </div>

      {/* Upload call-to-action banner (shown when no data yet) */}
      {Object.values(schemeCounts).every(c => c === 0) && (
        <div
          className="flex items-center justify-between bg-blue-50 border border-blue-200 rounded-xl px-5 py-4 cursor-pointer hover:bg-blue-100 transition"
          onClick={() => setShowUpload(true)}
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-blue-600 flex items-center justify-center flex-shrink-0">
              <Upload className="w-5 h-5 text-white" />
            </div>
            <div>
              <p className="font-semibold text-blue-900">No beneficiary data yet</p>
              <p className="text-sm text-blue-600">Click here to upload a CSV or Excel file and get started</p>
            </div>
          </div>
          <Upload className="w-5 h-5 text-blue-400 flex-shrink-0" />
        </div>
      )}

      {/* Scheme tabs */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        {VALID_SCHEMES.map(s => {
          const c   = SCHEME_COLORS[s];
          const isA = s === activeScheme;
          return (
            <button
              key={s}
              onClick={() => setActiveScheme(s)}
              className={clsx(
                'rounded-xl border-2 p-4 text-left transition',
                isA ? `${c.bg} ${c.border} shadow-sm` : 'bg-white border-gray-200 hover:border-gray-300',
              )}
            >
              <div className={clsx('w-8 h-8 rounded-lg flex items-center justify-center mb-2', isA ? c.icon : 'bg-gray-100')}>
                <Gift className={clsx('w-4 h-4', isA ? c.text : 'text-gray-400')} />
              </div>
              <p className={clsx('text-sm font-semibold', isA ? c.text : 'text-gray-700')}>{SCHEME_DISPLAY[s]}</p>
              <p className={clsx('text-xs mt-0.5', isA ? c.text : 'text-gray-400')}>
                {schemeCounts[s].toLocaleString()} beneficiaries
              </p>
            </button>
          );
        })}
      </div>

      {/* Batch manager (collapsible) */}
      {showBatches && (
        <div className="bg-white rounded-xl border border-gray-200 p-5 space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="font-semibold text-gray-800">
              Upload Batches — {SCHEME_DISPLAY[activeScheme]}
            </h2>
            <button
              onClick={handleClearScheme}
              disabled={clearingScheme}
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm text-red-600 border border-red-300 rounded-lg hover:bg-red-50 disabled:opacity-50 transition"
            >
              {clearingScheme
                ? <><RefreshCw className="w-3.5 h-3.5 animate-spin" /> Clearing…</>
                : <><Trash2 className="w-3.5 h-3.5" /> Clear All</>}
            </button>
          </div>
          <BatchManager scheme={activeScheme} onRefresh={() => setRefreshKey(k => k + 1)} />
        </div>
      )}

      {/* Beneficiary table */}
      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <div className="flex items-center justify-between gap-3 mb-4">
          <div className="flex items-center gap-3">
            <div className={clsx('w-9 h-9 rounded-lg flex items-center justify-center', colors.icon)}>
              <Users className={clsx('w-5 h-5', colors.text)} />
            </div>
            <div>
              <h2 className="font-semibold text-gray-800">{SCHEME_DISPLAY[activeScheme]}</h2>
              <p className="text-xs text-gray-400">Scheme beneficiaries</p>
            </div>
          </div>
          {schemeCounts[activeScheme] > 0 && (
            <button
              onClick={handleClearScheme}
              disabled={clearingScheme}
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm text-red-600 border border-red-300 rounded-lg hover:bg-red-50 disabled:opacity-50 transition"
            >
              {clearingScheme
                ? <><RefreshCw className="w-3.5 h-3.5 animate-spin" /> Deleting…</>
                : <><Trash2 className="w-3.5 h-3.5" /> Delete All Data</>}
            </button>
          )}
        </div>
        <BeneficiaryTable scheme={activeScheme} refreshKey={refreshKey} />
      </div>

      {/* Upload modal */}
      {showUpload && (
        <UploadModal
          scheme={activeScheme}
          onClose={() => setShowUpload(false)}
          onDone={() => { setShowUpload(false); handleUploadDone(); }}
        />
      )}
    </div>
  );
}
