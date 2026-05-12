import { useState } from "react";
import { Settings as SettingsIcon, Copy, CheckCircle, Link, QrCode } from "lucide-react";

export default function Settings() {
  const [copied, setCopied] = useState(false);

  const verificationBaseUrl = window.location.origin;
  const templateUrl = `${verificationBaseUrl}/verify/{memberId}`;
  const exampleUrl = `${verificationBaseUrl}/verify/TS001000000001`;

  const handleCopy = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Fallback for older browsers
      const textarea = document.createElement("textarea");
      textarea.value = text;
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand("copy");
      document.body.removeChild(textarea);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      {/* Page Header */}
      <div className="flex items-center gap-3">
        <SettingsIcon className="w-7 h-7 text-gray-700" />
        <h1 className="text-2xl font-bold text-gray-900">Settings</h1>
      </div>

      {/* Verification URL Section */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-100 bg-gray-50">
          <div className="flex items-center gap-2">
            <QrCode className="w-5 h-5 text-orange-600" />
            <h2 className="font-semibold text-gray-900">QR Code Verification</h2>
          </div>
          <p className="text-sm text-gray-500 mt-1">
            Configuration for the member verification QR codes on ID cards.
          </p>
        </div>

        <div className="p-6 space-y-5">
          {/* Verification Base URL */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Verification Base URL
            </label>
            <div className="flex items-center gap-2">
              <div className="flex-1 flex items-center gap-2 px-3 py-2.5 bg-gray-50 border border-gray-200 rounded-lg">
                <Link className="w-4 h-4 text-gray-400 flex-shrink-0" />
                <span className="text-sm text-gray-700 font-mono truncate">{verificationBaseUrl}</span>
              </div>
            </div>
            <p className="text-xs text-gray-400 mt-1.5">
              Automatically detected from the current deployment URL.
            </p>
          </div>

          {/* URL Template */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Verification URL Template
            </label>
            <div className="flex items-center gap-2">
              <div className="flex-1 flex items-center gap-2 px-3 py-2.5 bg-gray-50 border border-gray-200 rounded-lg">
                <Link className="w-4 h-4 text-gray-400 flex-shrink-0" />
                <span className="text-sm text-gray-700 font-mono truncate">{templateUrl}</span>
              </div>
              <button
                onClick={() => handleCopy(templateUrl)}
                className="flex items-center gap-1.5 px-3 py-2.5 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition text-sm font-medium whitespace-nowrap"
              >
                {copied ? (
                  <>
                    <CheckCircle className="w-4 h-4" />
                    Copied
                  </>
                ) : (
                  <>
                    <Copy className="w-4 h-4" />
                    Copy
                  </>
                )}
              </button>
            </div>
            <p className="text-xs text-gray-400 mt-1.5">
              <code className="bg-gray-100 px-1 py-0.5 rounded text-xs">{"{memberId}"}</code> is replaced with the member's 14-character ID (e.g., TS001000000001).
            </p>
          </div>

          {/* Example URL */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Example Verification Link
            </label>
            <a
              href={exampleUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 text-sm text-orange-600 hover:text-orange-700 font-mono underline underline-offset-2"
            >
              {exampleUrl}
            </a>
          </div>

          {/* Info box */}
          <div className="bg-blue-50 border border-blue-100 rounded-lg p-4">
            <h3 className="text-sm font-semibold text-blue-800 mb-1">How it works</h3>
            <ul className="text-sm text-blue-700 space-y-1 list-disc list-inside">
              <li>Each member's ID card contains a QR code with their unique verification link.</li>
              <li>When scanned, the QR code opens a public page displaying the member's verification status.</li>
              <li>The verification URL is automatically generated using this deployment's URL.</li>
              <li>No login is required to view the verification page.</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}
