import { useState, useEffect, useRef } from "react";
import { FileText, Upload as UploadIcon, Download, Trash2, HardDrive, X, CheckCircle, AlertCircle, Eye, EyeOff, Edit } from "lucide-react";
import type { ElementType } from "react";
import clsx from "clsx";
import { documentService, type Document } from "../../services/documentService";
import { useAuth } from "../../contexts/AuthContext";
import { translationService } from "../../services/translationService";
import GeographicAccessSelector, { type GeographicAccessData } from "../../components/GeographicAccessSelector";

type DocCategory = "Policy" | "Circular" | "Guidelines" | "Reports" | "Other";

function MetricCard({
  icon: Icon,
  value,
  label,
  color,
}: {
  icon: ElementType;
  value: string | number;
  label: string;
  color?: string;
}) {
  return (
    <div className="bg-white rounded-lg shadow-card p-4 flex items-center gap-4">
      <div className={clsx("p-2 rounded-md", color || "bg-gray-100")}>
        <Icon className="w-5 h-5" />
      </div>
      <div>
        <div className="text-xl font-semibold">{typeof value === "number" ? value.toLocaleString() : value}</div>
        <div className="text-xs text-gray-500">{label}</div>
      </div>
    </div>
  );
}

function CategoryPill({ category }: { category: DocCategory }) {
  const styles =
    category === "Policy"
      ? "bg-green-100 text-green-700 border border-green-200"
      : category === "Circular"
      ? "bg-blue-100 text-blue-700 border border-blue-200"
      : category === "Guidelines"
      ? "bg-amber-100 text-amber-700 border border-amber-200"
      : category === "Reports"
      ? "bg-purple-100 text-purple-700 border border-purple-200"
      : "bg-gray-100 text-gray-700 border border-gray-200";
  return <span className={clsx("px-3 py-1 rounded-full text-xs font-semibold", styles)}>{category}</span>;
}

function AccessPill({ label }: { label: "public" | "cadre" | "admin" }) {
  const styles =
    label === "public"
      ? "bg-white text-gray-700 border border-gray-300"
      : label === "cadre"
      ? "bg-green-50 text-green-700 border border-green-200"
      : "bg-orange-50 text-orange-700 border border-orange-200";
  return <span className={clsx("px-2 py-1 rounded-full text-xs", styles)}>{label}</span>;
}

export default function UploadDocuments() {
  const { user } = useAuth();
  const [documents, setDocuments] = useState<Document[]>([]);
  const [loading, setLoading] = useState(false);
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [editingDocument, setEditingDocument] = useState<Document | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [titleEn, setTitleEn] = useState("");
  const [titleTe, setTitleTe] = useState("");
  const [category, setCategory] = useState<DocCategory>("Policy");
  const [accessLevels, setAccessLevels] = useState<Array<"public" | "cadre" | "admin">>(["public"]);
  const [isPublished, setIsPublished] = useState(true);
  const [geographicAccess, setGeographicAccess] = useState<GeographicAccessData>({
    districtIds: [],
    mandalIds: [],
    assemblyConstituencyIds: [],
    parliamentaryConstituencyIds: [],
    postToAll: true,
  });
  const [uploading, setUploading] = useState(false);
  const [updating, setUpdating] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalDocs, setTotalDocs] = useState(0);

  const categories: DocCategory[] = ["Policy", "Circular", "Guidelines", "Reports", "Other"];
  const accessLevelOptions: Array<"public" | "cadre" | "admin"> = ["public", "cadre", "admin"];

  // Track if Telugu field was manually edited
  const titleTeManualEdit = useRef(false);

  useEffect(() => {
    loadDocuments();
  }, [currentPage]);

  // Auto-translate Title English to Telugu (only when not editing)
  useEffect(() => {
    if (!titleEn || titleTeManualEdit.current || showEditModal) {
      return;
    }
    
    const debouncedTranslate = translationService.createDebouncedTranslator(800);
    const currentTitleEn = titleEn;
    
    debouncedTranslate(currentTitleEn, (translated) => {
      if (!titleTeManualEdit.current && !showEditModal) {
        setTitleTe(translated);
      }
    });
  }, [titleEn, showEditModal]);

  const loadDocuments = async () => {
    setLoading(true);
    setError(null);
    try {
      // Pass all=true for admins to see all documents including unpublished and with geographic restrictions
      const response = await documentService.getDocuments({ page: currentPage, per_page: 20, all: true });
      setDocuments(response.documents || []);
      setTotalDocs(response.total || 0);
      setTotalPages(response.pages || 1);
    } catch (err: any) {
      console.error("Failed to load documents:", err);
      setError(err.response?.data?.message || err.message || "Failed to load documents");
    } finally {
      setLoading(false);
    }
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      // Validate file type
      const allowedTypes = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.rtf', '.odt', '.ods', '.odp'];
      const fileExt = '.' + file.name.split('.').pop()?.toLowerCase();
      
      if (!allowedTypes.includes(fileExt)) {
        setError(`Invalid file type. Allowed: ${allowedTypes.join(', ')}`);
        return;
      }
      
      setSelectedFile(file);
      setError(null);
      
      // Auto-fill title from filename if empty
      if (!titleEn) {
        const nameWithoutExt = file.name.replace(/\.[^/.]+$/, "");
        setTitleEn(nameWithoutExt);
      }
    }
  };

  const toggleAccessLevel = (level: "public" | "cadre" | "admin") => {
    setAccessLevels((prev) =>
      prev.includes(level) ? prev.filter((l) => l !== level) : [...prev, level]
    );
  };

  const handleUpload = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!selectedFile) {
      setError("Please select a file");
      return;
    }

    if (!titleEn.trim()) {
      setError("Title (English) is required");
      return;
    }

    if (accessLevels.length === 0) {
      setError("Please select at least one access level");
      return;
    }

    setUploading(true);
    setError(null);

    try {
      // Step 1: Upload the file
      const uploadResult = await documentService.uploadFile(selectedFile);
      
      // Step 2: Create the document record
      const documentData = {
        title_en: titleEn,
        title_te: titleTe || titleEn,
        category: category,
        file_url: uploadResult.url,
        file_type: uploadResult.file_type || selectedFile.name.split('.').pop() || 'pdf',
        file_size: uploadResult.file_size || selectedFile.size,
        access_level: accessLevels,
        is_published: isPublished,
        districtIds: geographicAccess.postToAll ? undefined : (geographicAccess.districtIds.length > 0 ? geographicAccess.districtIds : undefined),
        mandalIds: geographicAccess.postToAll ? undefined : (geographicAccess.mandalIds.length > 0 ? geographicAccess.mandalIds : undefined),
        assemblyConstituencyIds: geographicAccess.postToAll ? undefined : (geographicAccess.assemblyConstituencyIds.length > 0 ? geographicAccess.assemblyConstituencyIds : undefined),
        parliamentaryConstituencyIds: geographicAccess.postToAll ? undefined : (geographicAccess.parliamentaryConstituencyIds.length > 0 ? geographicAccess.parliamentaryConstituencyIds : undefined),
      };

      await documentService.createDocument(documentData);

      setSuccess(true);
      
      // Clear form
      setTimeout(() => {
        setSelectedFile(null);
        setTitleEn("");
        setTitleTe("");
        setCategory("Policy");
        setAccessLevels(["public"]);
        setIsPublished(true);
        setGeographicAccess({
          districtIds: [],
          mandalIds: [],
          assemblyConstituencyIds: [],
          parliamentaryConstituencyIds: [],
          postToAll: true,
        });
        setShowUploadModal(false);
        setSuccess(false);
        titleTeManualEdit.current = false; // Reset manual edit flag
        loadDocuments(); // Reload documents list
      }, 2000);

    } catch (err: any) {
      console.error("Failed to upload document:", err);
      setError(err.response?.data?.message || err.message || "Failed to upload document. Please try again.");
    } finally {
      setUploading(false);
    }
  };

  const handleDelete = async (documentId: string) => {
    if (!confirm("Are you sure you want to delete this document?")) {
      return;
    }

    try {
      // Document IDs are UUID strings, not integers
      await documentService.deleteDocument(documentId);
      loadDocuments();
    } catch (err: any) {
      console.error("Failed to delete document:", err);
      alert(err.response?.data?.message || err.message || "Failed to delete document");
    }
  };

  const handleEdit = (doc: Document) => {
    // Pre-populate all form fields with existing document data
    setEditingDocument(doc);
    setTitleEn(doc.title_en || "");
    setTitleTe(doc.title_te || "");
    setCategory((doc.category as DocCategory) || "Policy");
    
    // Handle access levels - convert to array if needed
    let accessLevelsArray: Array<"public" | "cadre" | "admin"> = ["public"];
    if (Array.isArray(doc.access_level)) {
      accessLevelsArray = doc.access_level as Array<"public" | "cadre" | "admin">;
    } else if (doc.access_level) {
      // If it's a string, try to parse it
      try {
        const parsed = typeof doc.access_level === 'string' ? JSON.parse(doc.access_level) : doc.access_level;
        accessLevelsArray = Array.isArray(parsed) ? parsed as Array<"public" | "cadre" | "admin"> : ["public"];
      } catch {
        accessLevelsArray = ["public"];
      }
    }
    setAccessLevels(accessLevelsArray);
    
    setIsPublished(doc.is_published !== undefined ? doc.is_published : true);
    
    // Pre-populate geographic access data
    // Handle null, undefined, or array values from the API
    const getArrayValue = (value: any): number[] => {
      if (value === null || value === undefined) return [];
      if (Array.isArray(value)) {
        // Filter out null/undefined values and ensure all are numbers
        return value.filter((id: any) => id != null && !isNaN(Number(id))).map((id: any) => Number(id));
      }
      return [];
    };
    
    const districtIds = getArrayValue(doc.districtIds);
    const mandalIds = getArrayValue(doc.mandalIds);
    const assemblyConstituencyIds = getArrayValue(doc.assemblyConstituencyIds);
    const parliamentaryConstituencyIds = getArrayValue(doc.parliamentaryConstituencyIds);
    
    // Check if there are any geographic restrictions
    // If all arrays are empty, it means "post to all"
    const hasGeographicRestrictions = 
      districtIds.length > 0 ||
      mandalIds.length > 0 ||
      assemblyConstituencyIds.length > 0 ||
      parliamentaryConstituencyIds.length > 0;
    
    setGeographicAccess({
      districtIds: districtIds,
      mandalIds: mandalIds,
      assemblyConstituencyIds: assemblyConstituencyIds,
      parliamentaryConstituencyIds: parliamentaryConstituencyIds,
      postToAll: !hasGeographicRestrictions,
    });
    
    setSelectedFile(null);
    setError(null);
    setSuccess(false);
    titleTeManualEdit.current = !!doc.title_te;
    setShowEditModal(true);
  };

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingDocument) return;

    setUpdating(true);
    setError(null);
    setSuccess(false);

    try {
      const updateData = {
        title_en: titleEn,
        title_te: titleTe || undefined,
        category: category,
        access_level: accessLevels,
        is_published: isPublished,
        districtIds: geographicAccess.postToAll ? [] : geographicAccess.districtIds,
        mandalIds: geographicAccess.postToAll ? [] : geographicAccess.mandalIds,
        assemblyConstituencyIds: geographicAccess.postToAll ? [] : geographicAccess.assemblyConstituencyIds,
        parliamentaryConstituencyIds: geographicAccess.postToAll ? [] : geographicAccess.parliamentaryConstituencyIds,
      };

      await documentService.updateDocument(editingDocument.id.toString(), updateData);
      setSuccess(true);
      setTimeout(() => {
        setShowEditModal(false);
        setEditingDocument(null);
        loadDocuments();
        // Reset form
        setTitleEn("");
        setTitleTe("");
        setCategory("Policy");
        setAccessLevels(["public"]);
        setIsPublished(true);
        setGeographicAccess({
          districtIds: [],
          mandalIds: [],
          assemblyConstituencyIds: [],
          parliamentaryConstituencyIds: [],
          postToAll: true,
        });
        titleTeManualEdit.current = false;
      }, 1500);
    } catch (err: any) {
      console.error("Failed to update document:", err);
      setError(err.response?.data?.message || err.message || "Failed to update document");
    } finally {
      setUpdating(false);
    }
  };

  const isValidFileUrl = (fileUrl: string | null | undefined): boolean => {
    if (!fileUrl || fileUrl === 'None' || fileUrl === 'null' || fileUrl.trim() === '') {
      return false;
    }
    try {
      const url = new URL(fileUrl);
      return url.protocol === 'http:' || url.protocol === 'https:';
    } catch {
      return false;
    }
  };

  const handleDownload = (fileUrl: string | null | undefined, title: string) => {
    // Validate file URL
    if (!isValidFileUrl(fileUrl)) {
      setError(`Unable to download "${title}": File URL is missing or invalid.`);
      return;
    }

    // Create a temporary anchor element to trigger download
    try {
      const link = document.createElement('a');
      link.href = fileUrl!;
      link.download = title;
      link.target = '_blank';
      link.rel = 'noopener noreferrer';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (err) {
      console.error('Download error:', err);
      setError(`Failed to download "${title}". Please try again.`);
    }
  };

  const formatDate = (dateString: string) => {
    try {
      const date = new Date(dateString);
      return date.toLocaleDateString('en-GB', { day: 'numeric', month: 'numeric', year: 'numeric' });
    } catch {
      return dateString;
    }
  };

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
  };

  const calculateStorageUsed = () => {
    const totalBytes = documents.reduce((sum, doc) => sum + (doc.file_size || 0), 0);
    return formatFileSize(totalBytes);
  };

  const filteredDocuments = documents.filter(doc => {
    if (!user) return false;
    const userRole = user.role?.toLowerCase() || 'public';
    
    if (userRole === 'admin') return true;
    
    const docAccessLevels = Array.isArray(doc.access_level) 
      ? doc.access_level.map(l => l.toLowerCase())
      : [doc.access_level].filter(Boolean).map(l => String(l).toLowerCase());

    if (userRole === 'cadre') {
      return docAccessLevels.some(level => ['public', 'cadre'].includes(level));
    }
    
    // default to public
    return docAccessLevels.includes('public');
  });

  const canUpload = user?.role?.toLowerCase() === 'admin' || user?.role?.toLowerCase() === 'cadre';
  const canDelete = user?.role?.toLowerCase() === 'admin';
  const canEdit = user?.role?.toLowerCase() === 'admin' || user?.role?.toLowerCase() === 'cadre';

  return (
    <div className="space-y-4">
      {/* Header + action */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-xl sm:text-2xl font-semibold">Upload Documents</h1>
          <p className="text-xs sm:text-sm text-gray-500">Upload and manage party documents</p>
        </div>
        {canUpload && (
          <button
            onClick={() => setShowUploadModal(true)}
            className="flex items-center justify-center gap-2 px-4 py-2 rounded-md bg-orange-500 text-white hover:bg-orange-600 transition-colors text-sm sm:text-base"
          >
            <UploadIcon className="w-4 h-4" />
            Upload Document
          </button>
        )}
      </div>

      {/* Metrics */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
        <div>
          <MetricCard icon={FileText} value={totalDocs} label="Total Documents" />
        </div>
        <div>
          <MetricCard icon={UploadIcon} value={filteredDocuments.length} label="Visible Documents" color="bg-green-100" />
        </div>
        <div>
          <MetricCard icon={Download} value={0} label="Total Downloads" color="bg-indigo-100" />
        </div>
        <div>
          <MetricCard icon={HardDrive} value={calculateStorageUsed()} label="Storage Used" color="bg-amber-100" />
        </div>
      </div>

      {/* Error/Success Messages */}
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-md flex items-center gap-2">
          <AlertCircle className="w-5 h-5" />
          <span>{error}</span>
        </div>
      )}

      {/* Table */}
      <div className="bg-white rounded-lg shadow-card overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-gray-500">Loading documents...</div>
        ) : filteredDocuments.length === 0 ? (
          <div className="p-8 text-center text-gray-500">No documents found.</div>
        ) : (
          <table className="min-w-full">
            <thead className="bg-gray-50">
              <tr className="text-left text-sm text-gray-600">
                <th className="px-4 py-3 font-medium">Document</th>
                <th className="px-4 py-3 font-medium">Category</th>
                <th className="px-4 py-3 font-medium">Access Level</th>
                <th className="px-4 py-3 font-medium">Upload Date</th>
                <th className="px-4 py-3 font-medium">Size</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3 font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredDocuments.map((doc) => (
                <tr key={doc.id} className="border-t">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <FileText className="w-4 h-4 text-gray-600" />
                      <div>
                        <span className="font-medium text-gray-900">{doc.title_en}</span>
                        {doc.title_te && (
                          <div className="text-xs text-gray-500">{doc.title_te}</div>
                        )}
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <CategoryPill category={doc.category as DocCategory} />
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      {Array.isArray(doc.access_level) ? (
                        doc.access_level.map((level) => (
                          <AccessPill key={level} label={level as "public" | "cadre" | "admin"} />
                        ))
                      ) : (
                        <AccessPill label="public" />
                      )}
                    </div>
                  </td>
                  <td className="px-4 py-3 text-gray-700">{formatDate(doc.created_at)}</td>
                  <td className="px-4 py-3 text-gray-700">{formatFileSize(doc.file_size || 0)}</td>
                  <td className="px-4 py-3">
                    {doc.is_published ? (
                      <span className="flex items-center gap-1 text-green-700 text-xs">
                        <Eye className="w-3 h-3" />
                        Published
                      </span>
                    ) : (
                      <span className="flex items-center gap-1 text-gray-500 text-xs">
                        <EyeOff className="w-3 h-3" />
                        Draft
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => handleDownload(doc.file_url, doc.title_en)}
                        disabled={!isValidFileUrl(doc.file_url)}
                        className={clsx(
                          "p-2 rounded-md transition-colors",
                          isValidFileUrl(doc.file_url)
                            ? "hover:bg-gray-100 cursor-pointer"
                            : "opacity-50 cursor-not-allowed"
                        )}
                        title={isValidFileUrl(doc.file_url) ? "Download" : "File URL is missing or invalid"}
                      >
                        <Download className={clsx(
                          "w-4 h-4",
                          isValidFileUrl(doc.file_url) ? "text-gray-700" : "text-gray-400"
                        )} />
                      </button>
                      {canEdit && (
                        <button
                          onClick={() => handleEdit(doc)}
                          className="p-2 rounded-md hover:bg-blue-50"
                          title="Edit"
                        >
                          <Edit className="w-4 h-4 text-blue-600" />
                        </button>
                      )}
                      {canDelete && (
                        <button
                          onClick={() => handleDelete(doc.id.toString())}
                          className="p-2 rounded-md hover:bg-red-50"
                          title="Delete"
                        >
                          <Trash2 className="w-4 h-4 text-red-600" />
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-2">
          <button
            onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
            disabled={currentPage === 1}
            className="px-3 py-1 rounded border disabled:opacity-50"
          >
            Previous
          </button>
          <span className="text-sm text-gray-600">
            Page {currentPage} of {totalPages}
          </span>
          <button
            onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
            disabled={currentPage === totalPages}
            className="px-3 py-1 rounded border disabled:opacity-50"
          >
            Next
          </button>
        </div>
      )}

      {/* Upload Modal */}
      {showUploadModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 overflow-y-auto">
          <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full p-4 sm:p-6 my-auto">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg sm:text-xl font-semibold">Upload Document</h2>
                <button
                  onClick={() => {
                    setShowUploadModal(false);
                    setError(null);
                    setSuccess(false);
                  }}
                  className="text-gray-500 hover:text-gray-700"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {success && (
                <div className="mb-4 bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-md flex items-center gap-2">
                  <CheckCircle className="w-5 h-5" />
                  <span>Document uploaded successfully!</span>
                </div>
              )}

              {error && (
                <div className="mb-4 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-md flex items-center gap-2">
                  <AlertCircle className="w-5 h-5" />
                  <span>{error}</span>
                </div>
              )}

              <form onSubmit={handleUpload} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    File <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="file"
                    onChange={handleFileSelect}
                    accept=".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.rtf,.odt,.ods,.odp"
                    className="w-full px-3 py-2 border border-gray-300 rounded-md bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                    required
                  />
                  {selectedFile && (
                    <p className="mt-1 text-sm text-gray-500">
                      Selected: {selectedFile.name} ({(selectedFile.size / 1024).toFixed(2)} KB)
                    </p>
                  )}
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Title (English) <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    value={titleEn}
                    onChange={(e) => setTitleEn(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Title (Telugu)
                  </label>
                  <input
                    type="text"
                    value={titleTe}
                    onChange={(e) => {
                      setTitleTe(e.target.value);
                      titleTeManualEdit.current = true;
                    }}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                    placeholder="Auto-translated"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Category <span className="text-red-500">*</span>
                  </label>
                  <select
                    value={category}
                    onChange={(e) => setCategory(e.target.value as DocCategory)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                    required
                  >
                    {categories.map((cat) => (
                      <option key={cat} value={cat}>
                        {cat}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Access Level <span className="text-red-500">*</span>
                  </label>
                  <div className="flex gap-4">
                    {accessLevelOptions.map((level) => (
                      <label key={level} className="flex items-center gap-2">
                        <input
                          type="checkbox"
                          checked={accessLevels.includes(level)}
                          onChange={() => toggleAccessLevel(level)}
                          className="rounded w-4 h-4 text-orange-500 border-gray-300 focus:ring-orange-300 bg-white"
                        />
                        <span className="text-sm capitalize">{level}</span>
                      </label>
                    ))}
                  </div>
                </div>

                <div>
                  <label className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={isPublished}
                      onChange={(e) => setIsPublished(e.target.checked)}
                      className="rounded w-4 h-4 text-orange-500 border-gray-300 focus:ring-orange-300 bg-white"
                    />
                    <span className="text-sm">Publish immediately</span>
                  </label>
                </div>

                {/* Geographic Access Control */}
                <div className="border-t pt-4">
                  <h3 className="text-sm font-medium mb-3">Geographic Access</h3>
                  <GeographicAccessSelector
                    value={geographicAccess}
                    onChange={setGeographicAccess}
                    disabled={uploading}
                  />
                </div>

                <div className="flex gap-2 pt-4">
                  <button
                    type="button"
                    onClick={() => {
                      setShowUploadModal(false);
                      setError(null);
                      setSuccess(false);
                      titleTeManualEdit.current = false; // Reset manual edit flag
                    }}
                    className="flex-1 px-4 py-2 rounded-md border hover:bg-gray-50"
                    disabled={uploading}
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={uploading || !selectedFile}
                    className="flex-1 px-4 py-2 bg-orange-500 text-white rounded-md hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {uploading ? "Uploading..." : "Upload Document"}
                  </button>
                </div>
              </form>
          </div>
        </div>
      )}

      {/* Edit Modal */}
      {showEditModal && editingDocument && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 overflow-y-auto">
          <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full p-4 sm:p-6 my-auto">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg sm:text-xl font-semibold">Edit Document</h2>
              <button
                onClick={() => {
                  setShowEditModal(false);
                  setEditingDocument(null);
                  setError(null);
                  setSuccess(false);
                }}
                className="text-gray-500 hover:text-gray-700"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {success && (
              <div className="mb-4 bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-md flex items-center gap-2">
                <CheckCircle className="w-5 h-5" />
                <span>Document updated successfully!</span>
              </div>
            )}

            {error && (
              <div className="mb-4 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-md flex items-center gap-2">
                <AlertCircle className="w-5 h-5" />
                <span>{error}</span>
              </div>
            )}

            <form onSubmit={handleUpdate} className="space-y-4">
              {/* Display current file info */}
              {editingDocument?.file_url && (
                <div className="bg-gray-50 border border-gray-200 rounded-md p-3 mb-4">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Current File
                  </label>
                  <div className="flex items-center gap-2">
                    <FileText className="w-4 h-4 text-gray-500" />
                    <a
                      href={editingDocument.file_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-sm text-blue-600 hover:underline truncate"
                    >
                      {editingDocument.file_url}
                    </a>
                  </div>
                  <p className="text-xs text-gray-500 mt-1">
                    File cannot be changed. Only metadata can be edited.
                  </p>
                </div>
              )}

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Title (English) <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={titleEn}
                  onChange={(e) => setTitleEn(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Title (Telugu)
                </label>
                <input
                  type="text"
                  value={titleTe}
                  onChange={(e) => {
                    setTitleTe(e.target.value);
                    titleTeManualEdit.current = true;
                  }}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                  placeholder="Auto-translated"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Category <span className="text-red-500">*</span>
                </label>
                <select
                  value={category}
                  onChange={(e) => setCategory(e.target.value as DocCategory)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-orange-300"
                  required
                >
                  {categories.map((cat) => (
                    <option key={cat} value={cat}>
                      {cat}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Access Level <span className="text-red-500">*</span>
                </label>
                <div className="flex gap-4">
                  {accessLevelOptions.map((level) => (
                    <label key={level} className="flex items-center gap-2">
                      <input
                        type="checkbox"
                        checked={accessLevels.includes(level)}
                        onChange={() => toggleAccessLevel(level)}
                        className="rounded w-4 h-4 text-orange-500 border-gray-300 focus:ring-orange-300 bg-white"
                      />
                      <span className="text-sm capitalize">{level}</span>
                    </label>
                  ))}
                </div>
              </div>

              <div>
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={isPublished}
                    onChange={(e) => setIsPublished(e.target.checked)}
                    className="rounded w-4 h-4 text-orange-500 border-gray-300 focus:ring-orange-300 bg-white"
                  />
                  <span className="text-sm">Publish immediately</span>
                </label>
              </div>

              {/* Geographic Access Control */}
              <div className="border-t pt-4">
                <h3 className="text-sm font-medium mb-3">Geographic Access</h3>
                <GeographicAccessSelector
                  value={geographicAccess}
                  onChange={setGeographicAccess}
                  disabled={updating}
                />
              </div>

              <div className="flex gap-2 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowEditModal(false);
                    setEditingDocument(null);
                    setError(null);
                    setSuccess(false);
                  }}
                  className="flex-1 px-4 py-2 rounded-md border hover:bg-gray-50"
                  disabled={updating}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={updating}
                  className="flex-1 px-4 py-2 bg-orange-500 text-white rounded-md hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {updating ? "Updating..." : "Update Document"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
