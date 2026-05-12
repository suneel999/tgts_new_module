import { useState, useEffect, useRef, useCallback } from 'react';
import {
  Plus, Pencil, Trash2, Eye, EyeOff, RefreshCw,
  X, Upload, Image, ExternalLink, AlertCircle, CheckCircle,
  BookOpen, Filter,
} from 'lucide-react';
import clsx from 'clsx';
import {
  schemesService,
  SCHEME_CATEGORIES, CATEGORY_LABELS, CATEGORY_COLORS, EMPTY_FORM,
  type SchemeRecord, type SchemeFormData, type SchemeCategory,
} from '../../services/schemesService';

// ─── HELPERS ─────────────────────────────────────────────────────────────────

function CategoryBadge({ category }: { category: SchemeCategory }) {
  const c = CATEGORY_COLORS[category] ?? CATEGORY_COLORS.other;
  return (
    <span className={clsx('text-xs font-semibold px-2 py-0.5 rounded-full', c.bg, c.text)}>
      {CATEGORY_LABELS[category] ?? category}
    </span>
  );
}

// ─── IMAGE UPLOAD WIDGET ──────────────────────────────────────────────────────

function ImageUploader({
  value,
  onChange,
}: {
  value: string;
  onChange: (url: string) => void;
}) {
  const [uploading, setUploading] = useState(false);
  const [error, setError]         = useState('');
  const fileRef = useRef<HTMLInputElement>(null);

  const handleFile = async (file: File) => {
    setUploading(true);
    setError('');
    try {
      const res = await schemesService.uploadImage(file);
      if (res.success) onChange(res.url);
      else setError(res.url || 'Upload failed');
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Upload failed');
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="space-y-2">
      <div
        className={clsx(
          'border-2 border-dashed rounded-xl overflow-hidden cursor-pointer transition',
          uploading ? 'opacity-60 pointer-events-none' : 'hover:border-blue-400 hover:bg-blue-50/30',
          value ? 'border-gray-200' : 'border-gray-300',
        )}
        style={{ height: 140 }}
        onClick={() => fileRef.current?.click()}
      >
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={e => { const f = e.target.files?.[0]; if (f) handleFile(f); }}
        />
        {value ? (
          <img src={value} alt="scheme" className="w-full h-full object-cover" />
        ) : (
          <div className="flex flex-col items-center justify-center h-full text-gray-400 gap-2">
            {uploading ? (
              <RefreshCw className="w-6 h-6 animate-spin" />
            ) : (
              <Image className="w-8 h-8" />
            )}
            <span className="text-xs">{uploading ? 'Uploading…' : 'Click to upload image'}</span>
          </div>
        )}
      </div>

      {value && (
        <div className="flex gap-2">
          <button
            type="button"
            onClick={() => fileRef.current?.click()}
            className="flex items-center gap-1 text-xs text-blue-600 hover:underline"
          >
            <Upload className="w-3 h-3" /> Change
          </button>
          <button
            type="button"
            onClick={() => onChange('')}
            className="flex items-center gap-1 text-xs text-red-500 hover:underline"
          >
            <X className="w-3 h-3" /> Remove
          </button>
        </div>
      )}
      {error && <p className="text-xs text-red-600">{error}</p>}
    </div>
  );
}

// ─── SCHEME FORM MODAL ────────────────────────────────────────────────────────

const BLANK = EMPTY_FORM;

function SchemeModal({
  initial,
  onClose,
  onSaved,
}: {
  initial: SchemeRecord | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const isEdit = !!initial;

  const [form, setForm] = useState<SchemeFormData>(() =>
    initial
      ? {
          title_en:       initial.title.en,
          title_te:       initial.title.te,
          description_en: initial.description.en,
          description_te: initial.description.te,
          category:       initial.category,
          image_url:      initial.imageUrl,
          eligibility_en: initial.eligibility.en,
          eligibility_te: initial.eligibility.te,
          benefits_en:    initial.benefits.en,
          benefits_te:    initial.benefits.te,
          apply_link:     initial.applyLink,
          is_published:   initial.isPublished,
        }
      : { ...BLANK },
  );

  const [saving, setSaving]   = useState(false);
  const [result, setResult]   = useState<{ ok: boolean; msg: string } | null>(null);
  const [activeTab, setTab]   = useState<'basic' | 'details'>('basic');

  const set = (key: keyof SchemeFormData, val: string | boolean) =>
    setForm(f => ({ ...f, [key]: val }));

  const handleSave = async () => {
    if (!form.title_en.trim() || !form.description_en.trim()) {
      setResult({ ok: false, msg: 'English title and description are required.' });
      return;
    }
    if (!form.title_te.trim() || !form.description_te.trim()) {
      setResult({ ok: false, msg: 'Telugu title and description are required.' });
      return;
    }
    setSaving(true);
    setResult(null);
    try {
      if (isEdit) {
        await schemesService.updateScheme(initial!.id, form);
      } else {
        await schemesService.createScheme(form);
      }
      onSaved();
      onClose();
    } catch (e: unknown) {
      setResult({ ok: false, msg: e instanceof Error ? e.message : 'Save failed' });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-3xl max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b flex-shrink-0">
          <h2 className="text-lg font-bold text-gray-900">
            {isEdit ? 'Edit Scheme' : 'Add New Scheme'}
          </h2>
          <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-lg transition">
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex border-b px-6 flex-shrink-0">
          {(['basic', 'details'] as const).map(tab => (
            <button
              key={tab}
              onClick={() => setTab(tab)}
              className={clsx(
                'px-4 py-3 text-sm font-medium border-b-2 -mb-px transition',
                activeTab === tab
                  ? 'border-blue-600 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700',
              )}
            >
              {tab === 'basic' ? 'Basic Info' : 'Details & Settings'}
            </button>
          ))}
        </div>

        {/* Body */}
        <div className="overflow-y-auto flex-1 px-6 py-5">
          {activeTab === 'basic' && (
            <div className="space-y-5">
              {/* Bilingual titles */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Title (English) *</label>
                  <input
                    value={form.title_en}
                    onChange={e => set('title_en', e.target.value)}
                    placeholder="e.g. Rythu Bharosa"
                    className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Title (Telugu) *</label>
                  <input
                    value={form.title_te}
                    onChange={e => set('title_te', e.target.value)}
                    placeholder="e.g. రైతు భరోసా"
                    className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
                  />
                </div>
              </div>

              {/* Bilingual descriptions */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Description (English) *</label>
                  <textarea
                    rows={4}
                    value={form.description_en}
                    onChange={e => set('description_en', e.target.value)}
                    placeholder="Brief description of the scheme in English"
                    className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400 resize-none"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Description (Telugu) *</label>
                  <textarea
                    rows={4}
                    value={form.description_te}
                    onChange={e => set('description_te', e.target.value)}
                    placeholder="తెలుగులో పథకం వివరణ"
                    className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400 resize-none"
                  />
                </div>
              </div>

              {/* Category + Image */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Category</label>
                  <select
                    value={form.category}
                    onChange={e => set('category', e.target.value as SchemeCategory)}
                    className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
                  >
                    {SCHEME_CATEGORIES.map(c => (
                      <option key={c} value={c}>{CATEGORY_LABELS[c]}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Banner Image</label>
                  <ImageUploader
                    value={form.image_url}
                    onChange={url => set('image_url', url)}
                  />
                </div>
              </div>
            </div>
          )}

          {activeTab === 'details' && (
            <div className="space-y-5">
              {/* Eligibility */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Eligibility (English)</label>
                  <textarea
                    rows={3}
                    value={form.eligibility_en}
                    onChange={e => set('eligibility_en', e.target.value)}
                    placeholder="Who can apply…"
                    className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400 resize-none"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Eligibility (Telugu)</label>
                  <textarea
                    rows={3}
                    value={form.eligibility_te}
                    onChange={e => set('eligibility_te', e.target.value)}
                    placeholder="దరఖాస్తు చేసుకోవడానికి అర్హత…"
                    className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400 resize-none"
                  />
                </div>
              </div>

              {/* Benefits */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Benefits (English)</label>
                  <textarea
                    rows={3}
                    value={form.benefits_en}
                    onChange={e => set('benefits_en', e.target.value)}
                    placeholder="Key benefits of this scheme…"
                    className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400 resize-none"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Benefits (Telugu)</label>
                  <textarea
                    rows={3}
                    value={form.benefits_te}
                    onChange={e => set('benefits_te', e.target.value)}
                    placeholder="పథకం ప్రధాన ప్రయోజనాలు…"
                    className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400 resize-none"
                  />
                </div>
              </div>

              {/* Apply link + published */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Apply Link (optional)</label>
                  <input
                    value={form.apply_link}
                    onChange={e => set('apply_link', e.target.value)}
                    placeholder="https://..."
                    className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
                  />
                </div>
                <div className="flex items-end pb-1">
                  <label className="flex items-center gap-3 cursor-pointer select-none">
                    <div
                      onClick={() => set('is_published', !form.is_published)}
                      className={clsx(
                        'w-11 h-6 rounded-full transition-colors relative cursor-pointer',
                        form.is_published ? 'bg-green-500' : 'bg-gray-300',
                      )}
                    >
                      <span
                        className={clsx(
                          'absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform',
                          form.is_published ? 'translate-x-5' : 'translate-x-0',
                        )}
                      />
                    </div>
                    <span className="text-sm font-medium text-gray-700">
                      {form.is_published ? 'Published' : 'Draft'}
                    </span>
                  </label>
                </div>
              </div>
            </div>
          )}

          {/* Result message */}
          {result && (
            <div
              className={clsx(
                'mt-4 flex items-start gap-2 p-3 rounded-lg text-sm',
                result.ok ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700',
              )}
            >
              {result.ok
                ? <CheckCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
                : <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />}
              <span>{result.msg}</span>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex gap-3 px-6 py-4 border-t flex-shrink-0">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50 transition"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition flex items-center justify-center gap-2"
          >
            {saving
              ? <><RefreshCw className="w-4 h-4 animate-spin" /> Saving…</>
              : isEdit ? 'Save Changes' : 'Create Scheme'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── SCHEME CARD ──────────────────────────────────────────────────────────────

function SchemeCard({
  scheme,
  onEdit,
  onDelete,
  onTogglePublish,
  toggling,
}: {
  scheme: SchemeRecord;
  onEdit: () => void;
  onDelete: () => void;
  onTogglePublish: () => void;
  toggling: boolean;
}) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 overflow-hidden flex flex-col hover:shadow-md transition">
      {/* Image */}
      <div className="h-36 bg-gray-100 relative flex-shrink-0">
        {scheme.imageUrl ? (
          <img src={scheme.imageUrl} alt={scheme.title.en} className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full flex items-center justify-center">
            <BookOpen className="w-10 h-10 text-gray-300" />
          </div>
        )}
        {/* Published badge */}
        <span
          className={clsx(
            'absolute top-2 right-2 text-xs font-semibold px-2 py-0.5 rounded-full',
            scheme.isPublished
              ? 'bg-green-100 text-green-700'
              : 'bg-yellow-100 text-yellow-700',
          )}
        >
          {scheme.isPublished ? 'Published' : 'Draft'}
        </span>
      </div>

      {/* Body */}
      <div className="p-4 flex-1 flex flex-col gap-2">
        <div className="flex items-start gap-2 flex-wrap">
          <CategoryBadge category={scheme.category} />
        </div>
        <h3 className="font-semibold text-gray-900 text-sm leading-snug line-clamp-2">{scheme.title.en}</h3>
        <p className="text-xs text-gray-500 line-clamp-1">{scheme.title.te}</p>
        <p className="text-xs text-gray-500 line-clamp-2 flex-1">{scheme.description.en}</p>

        {scheme.applyLink && (
          <a
            href={scheme.applyLink}
            target="_blank"
            rel="noreferrer"
            className="flex items-center gap-1 text-xs text-blue-600 hover:underline mt-1"
            onClick={e => e.stopPropagation()}
          >
            <ExternalLink className="w-3 h-3" /> Apply Link
          </a>
        )}
      </div>

      {/* Actions */}
      <div className="flex border-t border-gray-100">
        <button
          onClick={onTogglePublish}
          disabled={toggling}
          title={scheme.isPublished ? 'Unpublish' : 'Publish'}
          className="flex-1 flex items-center justify-center gap-1.5 py-2.5 text-xs font-medium text-gray-600 hover:bg-gray-50 transition disabled:opacity-50"
        >
          {toggling
            ? <RefreshCw className="w-3.5 h-3.5 animate-spin" />
            : scheme.isPublished
              ? <EyeOff className="w-3.5 h-3.5" />
              : <Eye className="w-3.5 h-3.5" />}
          {scheme.isPublished ? 'Unpublish' : 'Publish'}
        </button>
        <div className="w-px bg-gray-100" />
        <button
          onClick={onEdit}
          className="flex-1 flex items-center justify-center gap-1.5 py-2.5 text-xs font-medium text-blue-600 hover:bg-blue-50 transition"
        >
          <Pencil className="w-3.5 h-3.5" /> Edit
        </button>
        <div className="w-px bg-gray-100" />
        <button
          onClick={onDelete}
          className="flex-1 flex items-center justify-center gap-1.5 py-2.5 text-xs font-medium text-red-500 hover:bg-red-50 transition"
        >
          <Trash2 className="w-3.5 h-3.5" /> Delete
        </button>
      </div>
    </div>
  );
}

// ─── MAIN PAGE ────────────────────────────────────────────────────────────────

export default function SchemesManagement() {
  const [schemes, setSchemes]       = useState<SchemeRecord[]>([]);
  const [loading, setLoading]       = useState(true);
  const [error, setError]           = useState('');
  const [modalScheme, setModal]     = useState<SchemeRecord | 'new' | null>(null);
  const [toggling, setToggling]     = useState<string | null>(null);
  const [filterCat, setFilterCat]   = useState<SchemeCategory | 'all'>('all');
  const [filterPub, setFilterPub]   = useState<'all' | 'published' | 'draft'>('all');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await schemesService.getSchemes();
      setSchemes(res.data);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Failed to load schemes');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleDelete = async (scheme: SchemeRecord) => {
    if (!window.confirm(`Delete "${scheme.title.en}"? This cannot be undone.`)) return;
    try {
      await schemesService.deleteScheme(scheme.id);
      setSchemes(s => s.filter(x => x.id !== scheme.id));
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Delete failed');
    }
  };

  const handleTogglePublish = async (scheme: SchemeRecord) => {
    setToggling(scheme.id);
    try {
      const res = await schemesService.updateScheme(scheme.id, { is_published: !scheme.isPublished });
      setSchemes(s => s.map(x => x.id === scheme.id ? res.data : x));
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Update failed');
    } finally {
      setToggling(null);
    }
  };

  const visible = schemes.filter(s => {
    const catOk = filterCat === 'all' || s.category === filterCat;
    const pubOk =
      filterPub === 'all' ||
      (filterPub === 'published' && s.isPublished) ||
      (filterPub === 'draft' && !s.isPublished);
    return catOk && pubOk;
  });

  const publishedCount = schemes.filter(s => s.isPublished).length;

  return (
    <div className="p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Schemes</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            {schemes.length} schemes · {publishedCount} published
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={load}
            disabled={loading}
            className="p-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition disabled:opacity-50"
            title="Refresh"
          >
            <RefreshCw className={clsx('w-4 h-4 text-gray-600', loading && 'animate-spin')} />
          </button>
          <button
            onClick={() => setModal('new')}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition"
          >
            <Plus className="w-4 h-4" /> Add Scheme
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="flex items-center gap-3 flex-wrap">
        <div className="flex items-center gap-1.5 text-sm text-gray-500">
          <Filter className="w-4 h-4" />
        </div>
        {/* Category filter */}
        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => setFilterCat('all')}
            className={clsx(
              'px-3 py-1 rounded-full text-xs font-medium border transition',
              filterCat === 'all'
                ? 'bg-gray-800 text-white border-gray-800'
                : 'border-gray-300 text-gray-600 hover:border-gray-400',
            )}
          >
            All Categories
          </button>
          {SCHEME_CATEGORIES.map(c => (
            <button
              key={c}
              onClick={() => setFilterCat(c)}
              className={clsx(
                'px-3 py-1 rounded-full text-xs font-medium border transition',
                filterCat === c
                  ? `${CATEGORY_COLORS[c].bg} ${CATEGORY_COLORS[c].text} border-transparent`
                  : 'border-gray-300 text-gray-600 hover:border-gray-400',
              )}
            >
              {CATEGORY_LABELS[c]}
            </button>
          ))}
        </div>

        {/* Published filter */}
        <select
          value={filterPub}
          onChange={e => setFilterPub(e.target.value as typeof filterPub)}
          className="ml-auto border border-gray-300 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
        >
          <option value="all">All Status</option>
          <option value="published">Published</option>
          <option value="draft">Draft</option>
        </select>
      </div>

      {/* Error */}
      {error && (
        <div className="flex items-center gap-2 p-3 bg-red-50 text-red-700 rounded-lg text-sm">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          {error}
        </div>
      )}

      {/* Loading */}
      {loading && (
        <div className="flex items-center justify-center py-16">
          <RefreshCw className="w-7 h-7 animate-spin text-gray-400" />
        </div>
      )}

      {/* Empty */}
      {!loading && visible.length === 0 && (
        <div className="text-center py-16 text-gray-400">
          <BookOpen className="w-14 h-14 mx-auto mb-3 opacity-30" />
          <p className="font-medium">No schemes found</p>
          <p className="text-sm mt-1">
            {schemes.length === 0 ? 'Create your first scheme using the button above.' : 'Try adjusting the filters.'}
          </p>
        </div>
      )}

      {/* Cards grid */}
      {!loading && visible.length > 0 && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {visible.map(s => (
            <SchemeCard
              key={s.id}
              scheme={s}
              onEdit={() => setModal(s)}
              onDelete={() => handleDelete(s)}
              onTogglePublish={() => handleTogglePublish(s)}
              toggling={toggling === s.id}
            />
          ))}
        </div>
      )}

      {/* Modal */}
      {modalScheme !== null && (
        <SchemeModal
          initial={modalScheme === 'new' ? null : modalScheme}
          onClose={() => setModal(null)}
          onSaved={load}
        />
      )}
    </div>
  );
}
