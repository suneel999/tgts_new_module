import { useState, useRef } from 'react';
import {
  Upload, FileSpreadsheet, FileText, X, CheckCircle,
  AlertCircle, RefreshCw, ChevronDown,
} from 'lucide-react';
import clsx from 'clsx';
import {
  schemeBeneficiaryService,
  VALID_SCHEMES, SCHEME_DISPLAY,
  type SchemeName,
} from '../../services/schemeBeneficiaryService';

const SCHEME_COLORS: Record<SchemeName, string> = {
  maha_lakshmi:    'bg-pink-50 border-pink-300 text-pink-700',
  cheyutha:        'bg-blue-50 border-blue-300 text-blue-700',
  rythu_bharosa:   'bg-green-50 border-green-300 text-green-700',
  indiramma_indlu: 'bg-amber-50 border-amber-300 text-amber-700',
};

type UploadResult = {
  success: boolean;
  message: string;
  imported?: number;
  skipped?: number;
};

export default function UploadBeneficiaries() {
  const [scheme, setScheme]         = useState<SchemeName>('maha_lakshmi');
  const [file, setFile]             = useState<File | null>(null);
  const [replaceAll, setReplaceAll] = useState(false);
  const [uploading, setUploading]   = useState(false);
  const [result, setResult]         = useState<UploadResult | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const ext  = file?.name.split('.').pop()?.toLowerCase();
  const Icon = ext === 'xlsx' || ext === 'xls' ? FileSpreadsheet : FileText;

  const handleUpload = async () => {
    if (!file) return;
    setUploading(true);
    setResult(null);
    try {
      const res = await schemeBeneficiaryService.uploadFile(file, scheme, replaceAll);
      setResult({ success: res.success, message: res.message, imported: res.imported, skipped: res.skipped });
      if (res.success) {
        setFile(null);
        if (fileRef.current) fileRef.current.value = '';
      }
    } catch (e: unknown) {
      setResult({ success: false, message: e instanceof Error ? e.message : 'Upload failed' });
    } finally {
      setUploading(false);
    }
  };

  const reset = () => {
    setFile(null);
    setResult(null);
    if (fileRef.current) fileRef.current.value = '';
  };

  return (
    <div className="p-6 max-w-2xl mx-auto space-y-6">
      {/* Page header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Upload Beneficiaries</h1>
        <p className="text-sm text-gray-500 mt-0.5">
          Upload a CSV or Excel file to import beneficiary data for a government scheme.
        </p>
      </div>

      {/* Card */}
      <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">

        {/* Step 1 — Select scheme */}
        <div className="px-6 py-5 border-b border-gray-100">
          <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">Step 1 — Select Scheme</p>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            {VALID_SCHEMES.map(s => (
              <button
                key={s}
                onClick={() => { setScheme(s); setResult(null); }}
                className={clsx(
                  'rounded-xl border-2 px-3 py-3 text-center text-sm font-semibold transition',
                  scheme === s
                    ? SCHEME_COLORS[s]
                    : 'bg-white border-gray-200 text-gray-600 hover:border-gray-300',
                )}
              >
                {SCHEME_DISPLAY[s]}
              </button>
            ))}
          </div>
        </div>

        {/* Step 2 — Pick file */}
        <div className="px-6 py-5 border-b border-gray-100">
          <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">Step 2 — Choose File</p>

          <div
            className={clsx(
              'border-2 border-dashed rounded-xl p-8 text-center cursor-pointer transition',
              file
                ? 'border-blue-300 bg-blue-50/30'
                : 'border-gray-300 hover:border-blue-400 hover:bg-blue-50/20',
            )}
            onClick={() => !file && fileRef.current?.click()}
          >
            <input
              ref={fileRef}
              type="file"
              accept=".csv,.xlsx,.xls"
              className="hidden"
              onChange={e => { setResult(null); setFile(e.target.files?.[0] ?? null); }}
            />

            {file ? (
              <div className="flex items-center justify-center gap-4">
                <Icon className="w-10 h-10 text-blue-500 flex-shrink-0" />
                <div className="text-left">
                  <p className="font-semibold text-gray-800">{file.name}</p>
                  <p className="text-sm text-gray-400">{(file.size / 1024).toFixed(1)} KB</p>
                </div>
                <button
                  onClick={e => { e.stopPropagation(); reset(); }}
                  className="ml-auto p-1.5 hover:bg-gray-200 rounded-full transition"
                >
                  <X className="w-4 h-4 text-gray-500" />
                </button>
              </div>
            ) : (
              <>
                <Upload className="w-10 h-10 text-gray-300 mx-auto mb-3" />
                <p className="font-medium text-gray-600">Click to select a file</p>
                <p className="text-sm text-gray-400 mt-1">Supports CSV, XLS, XLSX</p>
                <p className="text-xs text-gray-400 mt-2 max-w-sm mx-auto">
                  Expected columns: <span className="font-mono">name, phone, address, village, mandal, district, aadhar_no, account_no, amount</span>
                </p>
              </>
            )}
          </div>
        </div>

        {/* Step 3 — Options */}
        <div className="px-6 py-5 border-b border-gray-100">
          <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">Step 3 — Options</p>
          <label className="flex items-start gap-3 cursor-pointer select-none">
            <input
              type="checkbox"
              checked={replaceAll}
              onChange={e => setReplaceAll(e.target.checked)}
              className="mt-0.5 w-4 h-4 accent-red-500 flex-shrink-0"
            />
            <div>
              <p className="text-sm font-medium text-gray-800">Replace all existing data for this scheme</p>
              <p className="text-xs text-gray-400 mt-0.5">
                When checked, all current records for <strong>{SCHEME_DISPLAY[scheme]}</strong> will be deleted before importing. Leave unchecked to append.
              </p>
            </div>
          </label>
        </div>

        {/* Result */}
        {result && (
          <div
            className={clsx(
              'flex items-start gap-3 px-6 py-4 text-sm',
              result.success ? 'bg-green-50 text-green-800' : 'bg-red-50 text-red-800',
            )}
          >
            {result.success
              ? <CheckCircle className="w-5 h-5 flex-shrink-0 mt-0.5" />
              : <AlertCircle className="w-5 h-5 flex-shrink-0 mt-0.5" />}
            <div>
              <p className="font-medium">{result.message}</p>
              {result.success && result.imported != null && (
                <p className="text-xs mt-0.5 opacity-80">
                  {result.imported.toLocaleString()} imported
                  {result.skipped ? `, ${result.skipped} skipped` : ''}
                </p>
              )}
            </div>
          </div>
        )}

        {/* Upload button */}
        <div className="px-6 py-5">
          <button
            onClick={handleUpload}
            disabled={!file || uploading}
            className="w-full flex items-center justify-center gap-2 py-3 bg-blue-600 text-white rounded-xl font-semibold text-sm hover:bg-blue-700 disabled:opacity-40 disabled:cursor-not-allowed transition"
          >
            {uploading
              ? <><RefreshCw className="w-4 h-4 animate-spin" /> Uploading…</>
              : <><Upload className="w-4 h-4" /> Upload to {SCHEME_DISPLAY[scheme]}</>}
          </button>
        </div>
      </div>

      {/* Format guide */}
      <details className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <summary className="flex items-center justify-between px-5 py-4 cursor-pointer text-sm font-semibold text-gray-700 select-none">
          File format guide
          <ChevronDown className="w-4 h-4 text-gray-400" />
        </summary>
        <div className="px-5 pb-5 text-sm text-gray-600 space-y-3">
          <p>The first row must be a header. Column names are flexible — common aliases are recognised automatically.</p>
          <table className="w-full text-xs border border-gray-200 rounded-lg overflow-hidden">
            <thead className="bg-gray-50 text-gray-500 font-semibold">
              <tr>
                <th className="px-3 py-2 text-left">Column</th>
                <th className="px-3 py-2 text-left">Required</th>
                <th className="px-3 py-2 text-left">Accepted names</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {[
                ['name',       'Yes', 'name, beneficiary name, full name'],
                ['phone',      'No',  'phone, mobile, contact'],
                ['address',    'No',  'address, addr'],
                ['village',    'No',  'village, gram'],
                ['mandal',     'No',  'mandal, mandal name'],
                ['district',   'No',  'district, dist'],
                ['aadhar_no',  'No',  'aadhar_no, aadhar, aadhaar, uid'],
                ['account_no', 'No',  'account_no, account, bank account'],
                ['amount',     'No',  'amount, benefit amount, amt'],
              ].map(([col, req, aliases]) => (
                <tr key={col} className="hover:bg-gray-50">
                  <td className="px-3 py-2 font-mono text-blue-700">{col}</td>
                  <td className="px-3 py-2">{req}</td>
                  <td className="px-3 py-2 text-gray-400">{aliases}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </details>
    </div>
  );
}
