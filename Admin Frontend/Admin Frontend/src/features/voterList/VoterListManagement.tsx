import { useState, useEffect, useRef, useCallback } from 'react';
import {
  Upload, Search, Users, CheckCircle, XCircle, Copy,
  Gift, Phone, Filter, ChevronLeft, ChevronRight, X,
  Trash2, RefreshCw, Edit2, Save, AlertCircle,
  FileText, FileSpreadsheet, Eye, BarChart2, GitCompare,
  UserPlus, UserMinus, ArrowRight,
} from 'lucide-react';
import clsx from 'clsx';
import { voterListService, type VoterRecord, type VoterStats, type VoterListFilters, type BatchInfo, type CompareResult } from '../../services/voterListService';

// ─── TYPES ───────────────────────────────────────────────────────────────────

type FilterTab = {
  key: string;
  label: string;
  params: Partial<VoterListFilters>;
};

const FILTER_TABS: FilterTab[] = [
  { key: 'all',         label: 'All',            params: { sort_by: 'name' } },
  { key: 'booth',       label: 'Booth Wise',      params: { sort_by: 'booth' } },
  { key: 'alpha',       label: 'Alphabetic',      params: { sort_by: 'name' } },
  { key: 'phone',       label: 'Phone List',      params: { sort_by: 'name', has_phone: true } },
  { key: 'address',     label: 'Address Wise',    params: { sort_by: 'address' } },
  { key: 'age',         label: 'Age Wise',        params: { sort_by: 'age' } },
  { key: 'caste',       label: 'Caste Wise',      params: { sort_by: 'caste' } },
  { key: 'color',       label: 'Color Wise',      params: { sort_by: 'color' } },
  { key: 'effective',   label: 'Effective',       params: { is_effective: true } },
  { key: 'duplicates',  label: 'Duplicates',      params: { is_duplicate: true } },
  { key: 'beneficiary', label: 'Beneficiaries',   params: { is_beneficiary: true } },
  { key: 'voted',       label: 'Voted',           params: { has_voted: true } },
  { key: 'non_voted',   label: 'Not Voted',       params: { has_voted: false } },
];

const COLOR_OPTIONS = [
  { value: 'green',  label: 'Supporter',  bg: 'bg-green-100',  text: 'text-green-700',  dot: 'bg-green-500' },
  { value: 'yellow', label: 'Neutral',    bg: 'bg-yellow-100', text: 'text-yellow-700', dot: 'bg-yellow-400' },
  { value: 'red',    label: 'Opponent',   bg: 'bg-red-100',    text: 'text-red-700',    dot: 'bg-red-500' },
  { value: 'orange', label: 'Unknown',    bg: 'bg-orange-100', text: 'text-orange-700', dot: 'bg-orange-400' },
];

// ─── HELPERS ─────────────────────────────────────────────────────────────────

function colorStyle(color: string) {
  return COLOR_OPTIONS.find(c => c.value === color) ?? null;
}

function ColorDot({ color }: { color: string }) {
  const s = colorStyle(color);
  if (!s) return null;
  return (
    <span className="flex items-center gap-1.5">
      <span className={clsx('w-2.5 h-2.5 rounded-full inline-block', s.dot)} />
      <span className={clsx('text-xs font-medium', s.text)}>{s.label}</span>
    </span>
  );
}

function GenderBadge({ gender }: { gender: string }) {
  const g = gender.toLowerCase();
  return (
    <span className={clsx(
      'px-2 py-0.5 rounded-full text-xs font-medium',
      g === 'female' ? 'bg-pink-100 text-pink-700' : 'bg-blue-100 text-blue-700',
    )}>
      {g === 'female' ? 'F' : 'M'}
    </span>
  );
}

function FlagBadges({ voter }: { voter: VoterRecord }) {
  return (
    <div className="flex flex-wrap gap-1">
      {voter.isDuplicate   && <span className="px-1.5 py-0.5 text-xs rounded bg-amber-100 text-amber-700 font-medium">DUP</span>}
      {voter.isBeneficiary && <span className="px-1.5 py-0.5 text-xs rounded bg-purple-100 text-purple-700 font-medium">BEN</span>}
      {voter.hasVoted      && <span className="px-1.5 py-0.5 text-xs rounded bg-green-100 text-green-700 font-medium">VOTED</span>}
      {!voter.isEffective  && <span className="px-1.5 py-0.5 text-xs rounded bg-gray-100 text-gray-500 font-medium">NON-EFF</span>}
    </div>
  );
}

// ─── STAT CARD ────────────────────────────────────────────────────────────────

function StatCard({ icon: Icon, value, label, color }: {
  icon: React.ElementType; value: string | number; label: string; color: string;
}) {
  return (
    <div className="bg-white rounded-lg shadow-sm border p-4 flex items-center gap-3">
      <div className={clsx('p-2 rounded-lg', color)}>
        <Icon className="w-5 h-5" />
      </div>
      <div>
        <div className="text-xl font-bold text-gray-900">
          {typeof value === 'number' ? value.toLocaleString() : value}
        </div>
        <div className="text-xs text-gray-500">{label}</div>
      </div>
    </div>
  );
}

// ─── UPLOAD MODAL ─────────────────────────────────────────────────────────────

function UploadModal({ onClose, onDone }: { onClose: () => void; onDone: (batchId?: string) => void }) {
  const [file, setFile]             = useState<File | null>(null);
  const [replaceAll, setReplaceAll] = useState(false);
  const [uploading, setUploading]   = useState(false);
  const [result, setResult]         = useState<{ imported: number; skipped: number; batchId: string } | null>(null);
  const [error, setError]           = useState<string | null>(null);
  const [dragOver, setDragOver]     = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleFile = (f: File) => {
    const ext = f.name.split('.').pop()?.toLowerCase();
    if (!['csv', 'txt', 'pdf'].includes(ext ?? '')) {
      setError('Only CSV or PDF files are allowed.');
      return;
    }
    setFile(f);
    setError(null);
  };

  const onDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    const f = e.dataTransfer.files[0];
    if (f) handleFile(f);
  };

  const handleUpload = async () => {
    if (!file) return;
    setUploading(true);
    setError(null);
    try {
      const res = await voterListService.uploadFile(file, replaceAll);
      if (res.success) {
        setResult({ imported: res.imported, skipped: res.skipped, batchId: res.batchId });
        onDone(res.batchId);
      } else {
        setError(res.message || 'Upload failed.');
      }
    } catch (err: any) {
      setError(err.response?.data?.message || err.message || 'Upload failed.');
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-lg">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b">
          <h2 className="text-lg font-semibold text-gray-900">Upload Voter List</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded-md">
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        <div className="px-6 py-5 space-y-5">
          {/* Drag-and-drop zone */}
          {!result && (
            <>
              <div
                onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
                onDragLeave={() => setDragOver(false)}
                onDrop={onDrop}
                onClick={() => inputRef.current?.click()}
                className={clsx(
                  'border-2 border-dashed rounded-lg p-8 flex flex-col items-center gap-3 cursor-pointer transition-colors',
                  dragOver ? 'border-orange-400 bg-orange-50' : 'border-gray-300 hover:border-orange-300 hover:bg-orange-50/50',
                )}
              >
                <input
                  ref={inputRef}
                  type="file"
                  className="hidden"
                  accept=".csv,.txt,.pdf"
                  onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFile(f); }}
                />
                <div className="flex gap-3">
                  <FileSpreadsheet className="w-8 h-8 text-green-500" />
                  <FileText className="w-8 h-8 text-red-500" />
                </div>
                {file ? (
                  <div className="text-center">
                    <p className="font-medium text-gray-800">{file.name}</p>
                    <p className="text-xs text-gray-500 mt-0.5">{(file.size / 1024).toFixed(1)} KB</p>
                  </div>
                ) : (
                  <div className="text-center">
                    <p className="font-medium text-gray-700">Drag & drop CSV or PDF here</p>
                    <p className="text-xs text-gray-400 mt-0.5">or click to browse</p>
                  </div>
                )}
              </div>

              {/* Format hint */}
              <div className="bg-blue-50 border border-blue-100 rounded-lg px-4 py-3 text-xs text-blue-700 space-y-1">
                <p className="font-medium">Supported formats:</p>
                <p>• <strong>CSV</strong> — Any EC voter list CSV. Column names are auto-detected.</p>
                <p>• <strong>PDF</strong> — Election Commission voter list PDF with embedded tables.</p>
                <p className="mt-1 text-blue-500">Tip: Export from ERONET / CEO portal as PDF or CSV.</p>
              </div>

              {/* Replace all toggle */}
              <label className="flex items-start gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={replaceAll}
                  onChange={(e) => setReplaceAll(e.target.checked)}
                  className="mt-0.5 w-4 h-4 rounded text-orange-500 border-gray-300 focus:ring-orange-300"
                />
                <div>
                  <p className="text-sm font-medium text-gray-700">Replace all existing records</p>
                  <p className="text-xs text-gray-400">Deletes previous voter data before importing. Leave unchecked to append.</p>
                </div>
              </label>
            </>
          )}

          {/* Success result */}
          {result && (
            <div className="text-center space-y-4 py-4">
              <div className="w-14 h-14 rounded-full bg-green-100 flex items-center justify-center mx-auto">
                <CheckCircle className="w-8 h-8 text-green-500" />
              </div>
              <div>
                <p className="text-lg font-semibold text-gray-900">Upload Complete!</p>
                <p className="text-sm text-gray-500 mt-1">Batch ID: <span className="font-mono font-medium">{result.batchId}</span></p>
              </div>
              <div className="flex justify-center gap-6">
                <div className="text-center">
                  <p className="text-2xl font-bold text-green-600">{result.imported.toLocaleString()}</p>
                  <p className="text-xs text-gray-500">Imported</p>
                </div>
                <div className="text-center">
                  <p className="text-2xl font-bold text-amber-500">{result.skipped.toLocaleString()}</p>
                  <p className="text-xs text-gray-500">Skipped</p>
                </div>
              </div>
            </div>
          )}

          {/* Error */}
          {error && (
            <div className="flex items-start gap-2 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
              <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
              <span>{error}</span>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t flex gap-3">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-2 border rounded-lg text-sm font-medium hover:bg-gray-50 transition-colors"
          >
            {result ? 'Close' : 'Cancel'}
          </button>
          {!result && (
            <button
              onClick={handleUpload}
              disabled={!file || uploading}
              className="flex-1 flex items-center justify-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg text-sm font-medium hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {uploading ? (
                <>
                  <RefreshCw className="w-4 h-4 animate-spin" />
                  Uploading…
                </>
              ) : (
                <>
                  <Upload className="w-4 h-4" />
                  Upload
                </>
              )}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── VOTER DETAIL / EDIT MODAL ────────────────────────────────────────────────

function VoterModal({
  voter,
  onClose,
  onSave,
}: {
  voter: VoterRecord;
  onClose: () => void;
  onSave: (updated: VoterRecord) => void;
}) {
  const [editing, setEditing]     = useState(false);
  const [saving, setSaving]       = useState(false);
  const [error, setError]         = useState<string | null>(null);
  const [color, setColor]         = useState(voter.color);
  const [caste, setCaste]         = useState(voter.caste);
  const [phone, setPhone]         = useState(voter.phone);
  const [isBeneficiary, setIsBen] = useState(voter.isBeneficiary);
  const [hasVoted, setHasVoted]   = useState(voter.hasVoted);
  const [isEffective, setIsEff]   = useState(voter.isEffective);
  const [isDuplicate, setIsDup]   = useState(voter.isDuplicate);

  const handleSave = async () => {
    setSaving(true);
    setError(null);
    try {
      const updated = await voterListService.updateVoter(voter.id, {
        color, caste, phone, isBeneficiary, hasVoted, isEffective, isDuplicate,
      });
      onSave(updated);
      setEditing(false);
    } catch (err: any) {
      setError(err.response?.data?.message || err.message || 'Update failed.');
    } finally {
      setSaving(false);
    }
  };

  const Row = ({ label, value }: { label: string; value: string }) => (
    value ? (
      <div className="flex gap-2 py-1.5 border-b border-gray-50 last:border-0">
        <span className="text-xs text-gray-400 w-28 flex-shrink-0 pt-0.5">{label}</span>
        <span className="text-sm text-gray-800 font-medium">{value}</span>
      </div>
    ) : null
  );

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-xl max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b bg-orange-500 rounded-t-xl">
          <div>
            <h2 className="text-lg font-bold text-white">{voter.voterName}</h2>
            {voter.voterIdNumber && (
              <p className="text-xs text-orange-100 mt-0.5 font-mono">
                EPIC: <span className="font-bold tracking-wide">{voter.voterIdNumber}</span>
              </p>
            )}
          </div>
          <button onClick={onClose} className="p-1 hover:bg-white/20 rounded-md">
            <X className="w-5 h-5 text-white" />
          </button>
        </div>

        {/* Body */}
        <div className="overflow-y-auto flex-1 px-6 py-4 space-y-4">
          {/* Read-only info */}
          <div>
            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-2">Voter Details</p>
            <Row label="Serial No."    value={voter.serialNo} />
            <Row label="Relative"      value={[voter.relativeType, voter.relativeName].filter(Boolean).join(' ')} />
            <Row label="Gender"        value={voter.gender} />
            <Row label="Age"           value={voter.age > 0 ? `${voter.age} yrs` : ''} />
            <Row label="Date of Birth" value={voter.dateOfBirth} />
            <Row label="House No."     value={voter.houseNumber} />
            <Row label="Part No."      value={voter.partNumber} />
            <Row label="Booth"         value={[voter.boothNumber, voter.boothName].filter(Boolean).join(' – ')} />
            <Row label="Address"       value={voter.address} />
          </div>

          {/* Editable section */}
          <div className="border-t pt-4">
            <div className="flex items-center justify-between mb-3">
              <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide">Party Data</p>
              {!editing && (
                <button
                  onClick={() => setEditing(true)}
                  className="flex items-center gap-1 text-xs text-orange-600 hover:text-orange-700 font-medium"
                >
                  <Edit2 className="w-3.5 h-3.5" /> Edit
                </button>
              )}
            </div>

            {editing ? (
              <div className="space-y-3">
                {/* Color */}
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1.5">Political Color</label>
                  <div className="flex gap-2 flex-wrap">
                    {COLOR_OPTIONS.map(opt => (
                      <button
                        key={opt.value}
                        onClick={() => setColor(color === opt.value ? '' : opt.value)}
                        className={clsx(
                          'flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium border transition-colors',
                          color === opt.value
                            ? `${opt.bg} ${opt.text} border-current`
                            : 'bg-white text-gray-600 border-gray-200 hover:border-gray-300',
                        )}
                      >
                        <span className={clsx('w-2 h-2 rounded-full', opt.dot)} />
                        {opt.label}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Caste */}
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">Caste</label>
                  <input
                    value={caste}
                    onChange={e => setCaste(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-orange-300"
                    placeholder="Enter caste"
                  />
                </div>

                {/* Phone */}
                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">Phone</label>
                  <input
                    value={phone}
                    onChange={e => setPhone(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-orange-300"
                    placeholder="Enter phone number"
                  />
                </div>

                {/* Flag toggles */}
                <div className="grid grid-cols-2 gap-2">
                  {[
                    { label: 'Beneficiary', value: isBeneficiary, set: setIsBen },
                    { label: 'Has Voted',   value: hasVoted,      set: setHasVoted },
                    { label: 'Effective',   value: isEffective,   set: setIsEff },
                    { label: 'Duplicate',   value: isDuplicate,   set: setIsDup },
                  ].map(({ label, value, set }) => (
                    <label key={label} className="flex items-center gap-2 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={value}
                        onChange={e => set(e.target.checked)}
                        className="w-4 h-4 rounded text-orange-500 border-gray-300 focus:ring-orange-300"
                      />
                      <span className="text-sm text-gray-700">{label}</span>
                    </label>
                  ))}
                </div>

                {error && (
                  <div className="flex items-center gap-2 text-red-600 text-sm bg-red-50 px-3 py-2 rounded-lg">
                    <AlertCircle className="w-4 h-4 flex-shrink-0" />
                    {error}
                  </div>
                )}
              </div>
            ) : (
              <div className="space-y-1">
                {color && <Row label="Color" value={colorStyle(color)?.label ?? color} />}
                {caste && <Row label="Caste" value={caste} />}
                {phone && <Row label="Phone" value={phone} />}
                <div className="flex gap-1 flex-wrap pt-1">
                  {isBeneficiary && <span className="px-2 py-0.5 rounded bg-purple-100 text-purple-700 text-xs font-medium">Beneficiary</span>}
                  {hasVoted      && <span className="px-2 py-0.5 rounded bg-green-100 text-green-700 text-xs font-medium">Voted</span>}
                  {!isEffective  && <span className="px-2 py-0.5 rounded bg-gray-100 text-gray-500 text-xs font-medium">Non-Effective</span>}
                  {isDuplicate   && <span className="px-2 py-0.5 rounded bg-amber-100 text-amber-700 text-xs font-medium">Duplicate</span>}
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Footer */}
        {editing && (
          <div className="px-6 py-4 border-t flex gap-3">
            <button
              onClick={() => { setEditing(false); setError(null); }}
              disabled={saving}
              className="flex-1 px-4 py-2 border rounded-lg text-sm font-medium hover:bg-gray-50 transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={saving}
              className="flex-1 flex items-center justify-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg text-sm font-medium hover:bg-orange-600 disabled:opacity-50 transition-colors"
            >
              {saving ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
              {saving ? 'Saving…' : 'Save Changes'}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

// ─── COMPARISON MODAL ─────────────────────────────────────────────────────────

function ComparisonModal({
  onClose,
  initialOld,
  initialNew,
}: {
  onClose: () => void;
  initialOld?: string;
  initialNew?: string;
}) {
  const [batches, setBatches]     = useState<BatchInfo[]>([]);
  const [batchOld, setBatchOld]   = useState(initialOld ?? '');
  const [batchNew, setBatchNew]   = useState(initialNew ?? '');
  const [result, setResult]       = useState<CompareResult | null>(null);
  const [loading, setLoading]     = useState(false);
  const [error, setError]         = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'added' | 'deleted'>('added');

  useEffect(() => {
    voterListService.getBatches().then(res => {
      if (res.success) {
        setBatches(res.data);
        if (!initialOld && !initialNew && res.data.length >= 2) {
          setBatchNew(res.data[0].batchId);
          setBatchOld(res.data[1].batchId);
        }
      }
    });
  }, []);

  // Auto-compare when both are set
  useEffect(() => {
    if (batchOld && batchNew && batchOld !== batchNew) {
      handleCompare(batchOld, batchNew);
    }
  }, [batchOld, batchNew]);

  const handleCompare = async (old_: string, new_: string) => {
    setLoading(true);
    setError(null);
    setResult(null);
    try {
      const res = await voterListService.compareBatches(old_, new_);
      if (res.success) {
        setResult(res);
        setActiveTab('added');
      } else {
        setError('Comparison failed.');
      }
    } catch (err: any) {
      setError(err.response?.data?.message || err.message || 'Comparison failed.');
    } finally {
      setLoading(false);
    }
  };

  const fmtDate = (iso: string | null) => {
    if (!iso) return '';
    try { return new Date(iso).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }); }
    catch { return iso; }
  };

  const listData = result
    ? (activeTab === 'added' ? result.added : result.deleted)
    : [];

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">

        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b">
          <div className="flex items-center gap-2">
            <GitCompare className="w-5 h-5 text-orange-500" />
            <h2 className="text-lg font-semibold text-gray-900">Upload Comparison</h2>
          </div>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded-md">
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-6 py-5 space-y-5">

          {/* Batch selectors */}
          <div className="flex flex-col sm:flex-row items-center gap-3">
            <div className="flex-1 w-full">
              <label className="block text-xs font-medium text-gray-500 mb-1">Old Upload (base)</label>
              <select
                value={batchOld}
                onChange={e => setBatchOld(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-orange-300"
              >
                <option value="">Select batch…</option>
                {batches.map(b => (
                  <option key={b.batchId} value={b.batchId}>
                    {b.batchId} ({b.count.toLocaleString()} voters){b.uploadedAt ? ` · ${fmtDate(b.uploadedAt)}` : ''}
                  </option>
                ))}
              </select>
            </div>

            <ArrowRight className="w-5 h-5 text-gray-400 flex-shrink-0 hidden sm:block mt-4" />

            <div className="flex-1 w-full">
              <label className="block text-xs font-medium text-gray-500 mb-1">New Upload (compare to)</label>
              <select
                value={batchNew}
                onChange={e => setBatchNew(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-orange-300"
              >
                <option value="">Select batch…</option>
                {batches.map(b => (
                  <option key={b.batchId} value={b.batchId}>
                    {b.batchId} ({b.count.toLocaleString()} voters){b.uploadedAt ? ` · ${fmtDate(b.uploadedAt)}` : ''}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Summary cards */}
          {result && (
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
              <div className="bg-blue-50 border border-blue-100 rounded-lg p-4 text-center">
                <div className="text-2xl font-bold text-blue-700">{result.oldCount.toLocaleString()}</div>
                <div className="text-xs text-blue-500 mt-0.5">Old Upload</div>
              </div>
              <div className="bg-indigo-50 border border-indigo-100 rounded-lg p-4 text-center">
                <div className="text-2xl font-bold text-indigo-700">{result.newCount.toLocaleString()}</div>
                <div className="text-xs text-indigo-500 mt-0.5">New Upload</div>
              </div>
              <div className="bg-green-50 border border-green-100 rounded-lg p-4 text-center">
                <div className="text-2xl font-bold text-green-700">+{result.addedCount.toLocaleString()}</div>
                <div className="text-xs text-green-600 mt-0.5">Members Added</div>
              </div>
              <div className="bg-red-50 border border-red-100 rounded-lg p-4 text-center">
                <div className="text-2xl font-bold text-red-600">-{result.deletedCount.toLocaleString()}</div>
                <div className="text-xs text-red-500 mt-0.5">Members Removed</div>
              </div>
            </div>
          )}

          {/* Loading / error */}
          {loading && (
            <div className="py-10 text-center text-gray-400">
              <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-2" />
              Comparing uploads…
            </div>
          )}
          {error && (
            <div className="flex items-center gap-2 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              {error}
            </div>
          )}

          {/* Tabs + table */}
          {result && !loading && (
            <div className="border rounded-lg overflow-hidden">
              {/* Tab bar */}
              <div className="flex border-b bg-gray-50">
                <button
                  onClick={() => setActiveTab('added')}
                  className={clsx(
                    'flex items-center gap-2 px-5 py-3 text-sm font-medium border-b-2 transition-colors',
                    activeTab === 'added'
                      ? 'border-green-500 text-green-700 bg-white'
                      : 'border-transparent text-gray-500 hover:text-gray-700',
                  )}
                >
                  <UserPlus className="w-4 h-4" />
                  Added Members
                  <span className={clsx(
                    'px-2 py-0.5 rounded-full text-xs font-bold',
                    activeTab === 'added' ? 'bg-green-100 text-green-700' : 'bg-gray-200 text-gray-500',
                  )}>
                    {result.addedCount.toLocaleString()}
                  </span>
                </button>
                <button
                  onClick={() => setActiveTab('deleted')}
                  className={clsx(
                    'flex items-center gap-2 px-5 py-3 text-sm font-medium border-b-2 transition-colors',
                    activeTab === 'deleted'
                      ? 'border-red-500 text-red-700 bg-white'
                      : 'border-transparent text-gray-500 hover:text-gray-700',
                  )}
                >
                  <UserMinus className="w-4 h-4" />
                  Removed Members
                  <span className={clsx(
                    'px-2 py-0.5 rounded-full text-xs font-bold',
                    activeTab === 'deleted' ? 'bg-red-100 text-red-700' : 'bg-gray-200 text-gray-500',
                  )}>
                    {result.deletedCount.toLocaleString()}
                  </span>
                </button>
              </div>

              {/* Table */}
              {listData.length === 0 ? (
                <div className="py-12 text-center text-gray-400 text-sm">
                  {activeTab === 'added' ? 'No new members were added.' : 'No members were removed.'}
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[600px] text-sm">
                    <thead className="bg-gray-50 text-xs text-gray-500 uppercase tracking-wide">
                      <tr>
                        <th className="px-4 py-3 text-left font-medium">#</th>
                        <th className="px-4 py-3 text-left font-medium">Voter Name</th>
                        <th className="px-4 py-3 text-left font-medium">Voter ID</th>
                        <th className="px-4 py-3 text-left font-medium">Age / Gender</th>
                        <th className="px-4 py-3 text-left font-medium">Booth</th>
                        <th className="px-4 py-3 text-left font-medium">Address</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100">
                      {listData.map((voter, idx) => (
                        <tr
                          key={voter.id}
                          className={clsx(
                            'transition-colors',
                            activeTab === 'added' ? 'hover:bg-green-50/40' : 'hover:bg-red-50/40',
                          )}
                        >
                          <td className="px-4 py-2.5 text-gray-400 font-mono text-xs">
                            {voter.serialNo || idx + 1}
                          </td>
                          <td className="px-4 py-2.5">
                            <div className="font-medium text-gray-900">{voter.voterName}</div>
                            {(voter.relativeType || voter.relativeName) && (
                              <div className="text-xs text-gray-400">
                                {[voter.relativeType, voter.relativeName].filter(Boolean).join(' ')}
                              </div>
                            )}
                          </td>
                          <td className="px-4 py-2.5 font-mono text-xs text-gray-600">
                            {voter.voterIdNumber || <span className="text-gray-300">—</span>}
                          </td>
                          <td className="px-4 py-2.5 whitespace-nowrap">
                            <div className="flex items-center gap-1.5">
                              {voter.age > 0 && <span className="text-gray-700">{voter.age}</span>}
                              {voter.gender && <GenderBadge gender={voter.gender} />}
                            </div>
                          </td>
                          <td className="px-4 py-2.5 text-xs text-gray-600">
                            {voter.boothNumber ? `B-${voter.boothNumber}` : <span className="text-gray-300">—</span>}
                          </td>
                          <td className="px-4 py-2.5 text-xs text-gray-500 max-w-[180px] truncate">
                            {voter.address || <span className="text-gray-300">—</span>}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t flex justify-end">
          <button
            onClick={onClose}
            className="px-5 py-2 border rounded-lg text-sm font-medium hover:bg-gray-50 transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── MAIN PAGE ────────────────────────────────────────────────────────────────

export default function VoterListManagement() {
  // Data
  const [voters, setVoters]       = useState<VoterRecord[]>([]);
  const [stats, setStats]         = useState<VoterStats | null>(null);
  const [loading, setLoading]     = useState(false);
  const [_statsLoading, setStatsLoading] = useState(false);
  const [error, setError]         = useState<string | null>(null);

  // Pagination
  const [page, setPage]           = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal]         = useState(0);
  const PER_PAGE = 25;

  // Filters
  const [activeTab, setActiveTab] = useState('all');
  const [search, setSearch]       = useState('');
  const [colorFilter, setColorFilter] = useState('');

  // UI
  const [showUpload, setShowUpload]   = useState(false);
  const [selectedVoter, setSelectedVoter] = useState<VoterRecord | null>(null);
  const [showStats, setShowStats]     = useState(false);
  const [confirmClear, setConfirmClear] = useState(false);
  const [clearing, setClearing]       = useState(false);
  const [showCompare, setShowCompare] = useState(false);
  const [compareOld, setCompareOld]   = useState<string | undefined>();
  const [compareNew, setCompareNew]   = useState<string | undefined>();

  const searchTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  // ── Load ────────────────────────────────────────────────────────────────────

  const loadVoters = useCallback(async (pg = 1) => {
    setLoading(true);
    setError(null);
    try {
      const tab    = FILTER_TABS.find(t => t.key === activeTab) ?? FILTER_TABS[0];
      const params: VoterListFilters = {
        ...tab.params,
        page:     pg,
        per_page: PER_PAGE,
      };
      if (search)      params.search = search;
      if (colorFilter) params.color  = colorFilter;

      const res = await voterListService.getVoters(params);
      setVoters(res.data);
      setTotal(res.total);
      setTotalPages(res.total_pages);
      setPage(pg);
    } catch (err: any) {
      setError(err.response?.data?.message || err.message || 'Failed to load voter list.');
    } finally {
      setLoading(false);
    }
  }, [activeTab, search, colorFilter]);

  const loadStats = useCallback(async () => {
    setStatsLoading(true);
    try {
      const s = await voterListService.getStats();
      setStats(s);
    } catch {
      // silently fail stats
    } finally {
      setStatsLoading(false);
    }
  }, []);

  useEffect(() => { loadVoters(1); }, [activeTab, colorFilter]);
  useEffect(() => { loadStats(); }, []);

  // Debounced search
  useEffect(() => {
    clearTimeout(searchTimer.current);
    searchTimer.current = setTimeout(() => loadVoters(1), 500);
    return () => clearTimeout(searchTimer.current);
  }, [search]);

  // ── Handlers ────────────────────────────────────────────────────────────────

  const handleTabChange = (key: string) => {
    setActiveTab(key);
    setPage(1);
  };

  const handleVoterSaved = (updated: VoterRecord) => {
    setVoters(vs => vs.map(v => v.id === updated.id ? updated : v));
    setSelectedVoter(updated);
    loadStats();
  };

  const handleClearAll = async () => {
    setClearing(true);
    try {
      await voterListService.clearAll();
      setConfirmClear(false);
      loadVoters(1);
      loadStats();
    } catch (err: any) {
      setError(err.response?.data?.message || 'Clear failed.');
    } finally {
      setClearing(false);
    }
  };

  const handleUploadDone = async (newBatchId?: string) => {
    loadVoters(1);
    loadStats();
    if (newBatchId) {
      try {
        const res = await voterListService.getBatches();
        if (res.success && res.data.length >= 2) {
          const sorted = res.data.slice().sort(
            (a, b) => (b.uploadedAt ?? '').localeCompare(a.uploadedAt ?? '')
          );
          setCompareNew(sorted[0].batchId);
          setCompareOld(sorted[1].batchId);
          setShowCompare(true);
        }
      } catch {
        // silently skip auto-compare
      }
    }
  };

  // ── Render ──────────────────────────────────────────────────────────────────

  return (
    <div className="space-y-5">

      {/* ── Page Header ── */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div>
          <h1 className="text-xl sm:text-2xl font-semibold text-gray-900">Voter List Management</h1>
          <p className="text-xs sm:text-sm text-gray-500">Upload, browse and update voter data</p>
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <button
            onClick={() => setShowStats(s => !s)}
            className="flex items-center gap-1.5 px-3 py-2 border rounded-lg text-sm font-medium hover:bg-gray-50 transition-colors"
          >
            <BarChart2 className="w-4 h-4 text-gray-500" />
            Stats
          </button>
          <button
            onClick={() => { setCompareOld(undefined); setCompareNew(undefined); setShowCompare(true); }}
            className="flex items-center gap-1.5 px-3 py-2 border border-orange-200 text-orange-600 rounded-lg text-sm font-medium hover:bg-orange-50 transition-colors"
          >
            <GitCompare className="w-4 h-4" />
            Compare Uploads
          </button>
          <button
            onClick={() => { loadVoters(page); loadStats(); }}
            className="flex items-center gap-1.5 px-3 py-2 border rounded-lg text-sm font-medium hover:bg-gray-50 transition-colors"
            title="Refresh"
          >
            <RefreshCw className="w-4 h-4 text-gray-500" />
          </button>
          <button
            onClick={() => setConfirmClear(true)}
            className="flex items-center gap-1.5 px-3 py-2 border border-red-200 text-red-600 rounded-lg text-sm font-medium hover:bg-red-50 transition-colors"
          >
            <Trash2 className="w-4 h-4" />
            Clear All
          </button>
          <button
            onClick={() => setShowUpload(true)}
            className="flex items-center gap-1.5 px-4 py-2 bg-orange-500 text-white rounded-lg text-sm font-medium hover:bg-orange-600 transition-colors"
          >
            <Upload className="w-4 h-4" />
            Upload CSV / PDF
          </button>
        </div>
      </div>

      {/* ── Stats Panel ── */}
      {showStats && stats && (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
          <StatCard icon={Users}       value={stats.total}         label="Total Voters"   color="bg-blue-100 text-blue-600" />
          <StatCard icon={CheckCircle} value={stats.voted}         label="Voted"          color="bg-green-100 text-green-600" />
          <StatCard icon={XCircle}     value={stats.nonVoted}      label="Not Voted"      color="bg-red-100 text-red-500" />
          <StatCard icon={Copy}        value={stats.duplicates}    label="Duplicates"     color="bg-amber-100 text-amber-600" />
          <StatCard icon={Gift}        value={stats.beneficiaries} label="Beneficiaries"  color="bg-purple-100 text-purple-600" />
          <StatCard icon={Phone}       value={stats.withPhone}     label="With Phone"     color="bg-teal-100 text-teal-600" />
        </div>
      )}

      {/* ── Error ── */}
      {error && (
        <div className="flex items-center gap-2 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          {error}
          <button onClick={() => setError(null)} className="ml-auto"><X className="w-4 h-4" /></button>
        </div>
      )}

      {/* ── Filter Tabs ── */}
      <div className="bg-white rounded-lg border shadow-sm">
        <div className="border-b px-4 pt-3 overflow-x-auto">
          <div className="flex gap-1 min-w-max">
            {FILTER_TABS.map(tab => (
              <button
                key={tab.key}
                onClick={() => handleTabChange(tab.key)}
                className={clsx(
                  'px-3 py-2 text-sm font-medium rounded-t-md border-b-2 transition-colors whitespace-nowrap',
                  activeTab === tab.key
                    ? 'border-orange-500 text-orange-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700',
                )}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>

        {/* ── Search + Color Filter ── */}
        <div className="p-4 flex flex-col sm:flex-row gap-3">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Search by name, voter ID, phone, address…"
              className="w-full pl-9 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-orange-300"
            />
          </div>

          {/* Color filter */}
          <div className="flex items-center gap-2 flex-wrap">
            <Filter className="w-4 h-4 text-gray-400 flex-shrink-0" />
            {COLOR_OPTIONS.map(opt => (
              <button
                key={opt.value}
                onClick={() => setColorFilter(colorFilter === opt.value ? '' : opt.value)}
                className={clsx(
                  'flex items-center gap-1.5 px-2.5 py-1.5 rounded-full text-xs font-medium border transition-colors',
                  colorFilter === opt.value
                    ? `${opt.bg} ${opt.text} border-current`
                    : 'bg-white text-gray-500 border-gray-200 hover:border-gray-300',
                )}
              >
                <span className={clsx('w-2 h-2 rounded-full', opt.dot)} />
                {opt.label}
              </button>
            ))}
            {colorFilter && (
              <button onClick={() => setColorFilter('')} className="text-xs text-gray-400 hover:text-gray-600 underline">
                Clear
              </button>
            )}
          </div>
        </div>

        {/* ── Table ── */}
        <div className="overflow-x-auto">
          {loading ? (
            <div className="py-16 text-center text-gray-400">
              <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-2" />
              Loading voters…
            </div>
          ) : voters.length === 0 ? (
            <div className="py-16 text-center text-gray-400 space-y-2">
              <Users className="w-10 h-10 mx-auto opacity-30" />
              <p className="text-sm">No voter records found.</p>
              {total === 0 && (
                <p className="text-xs">Upload a CSV or PDF file to get started.</p>
              )}
            </div>
          ) : (
            <table className="w-full min-w-[700px] text-sm">
              <thead className="bg-gray-50 text-xs text-gray-500 uppercase tracking-wide">
                <tr>
                  <th className="px-4 py-3 text-left font-medium">#</th>
                  <th className="px-4 py-3 text-left font-medium">Voter</th>
                  <th className="px-4 py-3 text-left font-medium">EPIC No.</th>
                  <th className="px-4 py-3 text-left font-medium">Age / Gender</th>
                  <th className="px-4 py-3 text-left font-medium">Booth</th>
                  <th className="px-4 py-3 text-left font-medium">Phone</th>
                  <th className="px-4 py-3 text-left font-medium">Caste</th>
                  <th className="px-4 py-3 text-left font-medium">Color</th>
                  <th className="px-4 py-3 text-left font-medium">Flags</th>
                  <th className="px-4 py-3 text-left font-medium">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {voters.map(voter => (
                  <tr key={voter.id} className="hover:bg-orange-50/40 transition-colors">
                    <td className="px-4 py-3 text-gray-400 font-mono text-xs">
                      {voter.serialNo || voter.id}
                    </td>
                    <td className="px-4 py-3">
                      <div className="font-medium text-gray-900">{voter.voterName}</div>
                      {(voter.relativeType || voter.relativeName) && (
                        <div className="text-xs text-gray-400 mt-0.5">
                          {[voter.relativeType, voter.relativeName].filter(Boolean).join(' ')}
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      {voter.voterIdNumber
                        ? <span className="font-mono text-xs bg-blue-50 text-blue-700 border border-blue-200 px-2 py-0.5 rounded">{voter.voterIdNumber}</span>
                        : <span className="text-gray-300 text-xs">—</span>
                      }
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap">
                      <div className="flex items-center gap-1.5">
                        {voter.age > 0 && <span className="text-gray-700">{voter.age}</span>}
                        {voter.gender && <GenderBadge gender={voter.gender} />}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-gray-600 text-xs">
                      {voter.boothNumber && <div className="font-medium">B-{voter.boothNumber}</div>}
                      {voter.boothName && <div className="text-gray-400 truncate max-w-[100px]">{voter.boothName}</div>}
                    </td>
                    <td className="px-4 py-3 text-gray-600 font-mono text-xs">
                      {voter.phone || <span className="text-gray-300">—</span>}
                    </td>
                    <td className="px-4 py-3 text-gray-600 text-xs">
                      {voter.caste || <span className="text-gray-300">—</span>}
                    </td>
                    <td className="px-4 py-3">
                      {voter.color ? <ColorDot color={voter.color} /> : <span className="text-gray-300 text-xs">—</span>}
                    </td>
                    <td className="px-4 py-3">
                      <FlagBadges voter={voter} />
                    </td>
                    <td className="px-4 py-3">
                      <button
                        onClick={() => setSelectedVoter(voter)}
                        className="flex items-center gap-1 text-xs text-orange-600 hover:text-orange-700 font-medium px-2 py-1 rounded hover:bg-orange-50 transition-colors"
                      >
                        <Eye className="w-3.5 h-3.5" /> View
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {/* ── Pagination ── */}
        {totalPages > 1 && (
          <div className="px-4 py-3 border-t flex items-center justify-between text-sm text-gray-500">
            <span>{total.toLocaleString()} voters · Page {page} of {totalPages}</span>
            <div className="flex items-center gap-1">
              <button
                onClick={() => loadVoters(page - 1)}
                disabled={page <= 1 || loading}
                className="p-1.5 rounded border disabled:opacity-40 hover:bg-gray-50 transition-colors"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                const pg = Math.max(1, Math.min(totalPages - 4, page - 2)) + i;
                return (
                  <button
                    key={pg}
                    onClick={() => loadVoters(pg)}
                    className={clsx(
                      'w-8 h-8 rounded border text-xs font-medium transition-colors',
                      pg === page ? 'bg-orange-500 text-white border-orange-500' : 'hover:bg-gray-50',
                    )}
                  >
                    {pg}
                  </button>
                );
              })}
              <button
                onClick={() => loadVoters(page + 1)}
                disabled={page >= totalPages || loading}
                className="p-1.5 rounded border disabled:opacity-40 hover:bg-gray-50 transition-colors"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* ── Modals ── */}
      {showUpload && (
        <UploadModal
          onClose={() => setShowUpload(false)}
          onDone={(batchId) => handleUploadDone(batchId)}
        />
      )}

      {showCompare && (
        <ComparisonModal
          onClose={() => setShowCompare(false)}
          initialOld={compareOld}
          initialNew={compareNew}
        />
      )}

      {selectedVoter && (
        <VoterModal
          voter={selectedVoter}
          onClose={() => setSelectedVoter(null)}
          onSave={handleVoterSaved}
        />
      )}

      {confirmClear && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-sm p-6 space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
                <Trash2 className="w-5 h-5 text-red-500" />
              </div>
              <div>
                <h3 className="font-semibold text-gray-900">Clear All Voter Records?</h3>
                <p className="text-sm text-gray-500 mt-0.5">This will permanently delete all {total.toLocaleString()} voter records. This cannot be undone.</p>
              </div>
            </div>
            <div className="flex gap-3 pt-2">
              <button
                onClick={() => setConfirmClear(false)}
                disabled={clearing}
                className="flex-1 px-4 py-2 border rounded-lg text-sm font-medium hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={handleClearAll}
                disabled={clearing}
                className="flex-1 flex items-center justify-center gap-2 px-4 py-2 bg-red-500 text-white rounded-lg text-sm font-medium hover:bg-red-600 disabled:opacity-50"
              >
                {clearing ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Trash2 className="w-4 h-4" />}
                {clearing ? 'Clearing…' : 'Yes, Clear All'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
