import { useParams } from "react-router-dom";
import { useEffect, useState } from "react";
import { ShieldCheck, ShieldX, Loader2, AlertTriangle } from "lucide-react";
import { fetchMemberVerification, type VerifyMemberResponse } from "../services/verifyService";

type PageState = "loading" | "success" | "not_found" | "error";

export default function VerifyMember() {
  const { memberId } = useParams<{ memberId: string }>();
  const [state, setState] = useState<PageState>("loading");
  const [member, setMember] = useState<VerifyMemberResponse | null>(null);

  useEffect(() => {
    if (!memberId) {
      setState("not_found");
      return;
    }

    let cancelled = false;

    async function load() {
      try {
        const data = await fetchMemberVerification(memberId!);
        if (!cancelled) {
          setMember(data);
          setState("success");
        }
      } catch (err: any) {
        if (!cancelled) {
          if (err?.response?.status === 404) {
            setState("not_found");
          } else {
            setState("error");
          }
        }
      }
    }

    load();
    return () => { cancelled = true; };
  }, [memberId]);

  return (
    <div className="min-h-screen bg-gradient-to-br from-orange-50 via-white to-green-50 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Header branding */}
        <div className="text-center mb-6">
          <h1 className="text-2xl font-bold text-gray-800">Indian National Congress</h1>
          <p className="text-sm text-gray-500 mt-1">Member Verification Portal</p>
        </div>

        {state === "loading" && <LoadingCard />}
        {state === "success" && member && <VerificationCard member={member} />}
        {state === "not_found" && <NotFoundCard memberId={memberId} />}
        {state === "error" && <ErrorCard />}

        {/* Footer */}
        <p className="text-center text-xs text-gray-400 mt-6">
          Telangana Pradesh Congress Committee
        </p>
      </div>
    </div>
  );
}

function LoadingCard() {
  return (
    <div className="bg-white rounded-2xl shadow-lg p-8 text-center">
      <Loader2 className="w-12 h-12 text-orange-500 animate-spin mx-auto" />
      <p className="mt-4 text-gray-600 font-medium">Verifying member...</p>
    </div>
  );
}

function VerificationCard({ member }: { member: VerifyMemberResponse }) {
  const isVerified = member.isVerified;

  // Build profile picture URL
  let photoUrl = member.profilePictureUrl;
  if (photoUrl && !photoUrl.startsWith("http")) {
    photoUrl = `https://apitgts.codeology.solutions${photoUrl}`;
  }

  return (
    <div className="bg-white rounded-2xl shadow-lg overflow-hidden">
      {/* Status banner */}
      <div className={`px-6 py-4 flex items-center gap-3 ${isVerified ? "bg-green-600" : "bg-red-600"}`}>
        {isVerified ? (
          <ShieldCheck className="w-8 h-8 text-white flex-shrink-0" />
        ) : (
          <ShieldX className="w-8 h-8 text-white flex-shrink-0" />
        )}
        <div>
          <h2 className="text-white font-bold text-lg">
            {isVerified ? "Verified Member" : "Not Verified"}
          </h2>
          <p className="text-white/80 text-sm">
            {isVerified
              ? "This member is an approved member of the Indian National Congress."
              : "This member's registration has not been approved yet."}
          </p>
        </div>
      </div>

      {/* Member details */}
      <div className="p-6">
        {/* Photo and name */}
        <div className="flex items-center gap-4 mb-6">
          {photoUrl ? (
            <img
              src={photoUrl}
              alt={member.fullName}
              className="w-20 h-20 rounded-full object-cover border-2 border-gray-200"
              onError={(e) => {
                (e.target as HTMLImageElement).style.display = "none";
              }}
            />
          ) : (
            <div className="w-20 h-20 rounded-full bg-gray-100 flex items-center justify-center border-2 border-gray-200">
              <span className="text-2xl font-bold text-gray-400">
                {member.fullName?.charAt(0) || "?"}
              </span>
            </div>
          )}
          <div>
            <h3 className="text-xl font-bold text-gray-900">{member.fullName}</h3>
            <p className="text-sm text-gray-500 font-mono mt-0.5">ID: {member.memberId}</p>
          </div>
        </div>

        {/* Details grid */}
        <div className="space-y-3">
          {member.partyDesignation && (
            <DetailRow label="Party Designation" value={member.partyDesignation} />
          )}
          {member.cadreLevelName && (
            <DetailRow label="Cadre Level" value={member.cadreLevelName} />
          )}
          {member.district && (
            <DetailRow label="District" value={member.district} />
          )}
          {member.assemblyConstituency && (
            <DetailRow label="Assembly Constituency" value={member.assemblyConstituency} />
          )}
          <DetailRow
            label="Membership Status"
            value={
              member.status === "approved"
                ? "Approved"
                : member.status === "pending"
                ? "Pending Approval"
                : "Rejected"
            }
            highlight={member.status === "approved" ? "green" : member.status === "pending" ? "yellow" : "red"}
          />
        </div>
      </div>
    </div>
  );
}

function DetailRow({
  label,
  value,
  highlight,
}: {
  label: string;
  value: string;
  highlight?: "green" | "yellow" | "red";
}) {
  const highlightClasses: Record<string, string> = {
    green: "text-green-700 bg-green-50 px-2 py-0.5 rounded-md font-semibold",
    yellow: "text-yellow-700 bg-yellow-50 px-2 py-0.5 rounded-md font-semibold",
    red: "text-red-700 bg-red-50 px-2 py-0.5 rounded-md font-semibold",
  };

  return (
    <div className="flex justify-between items-center py-2 border-b border-gray-100 last:border-b-0">
      <span className="text-sm text-gray-500">{label}</span>
      <span className={highlight ? highlightClasses[highlight] : "text-sm font-medium text-gray-900"}>
        {value}
      </span>
    </div>
  );
}

function NotFoundCard({ memberId }: { memberId?: string }) {
  return (
    <div className="bg-white rounded-2xl shadow-lg p-8 text-center">
      <AlertTriangle className="w-12 h-12 text-yellow-500 mx-auto" />
      <h2 className="mt-4 text-lg font-bold text-gray-900">Member Not Found</h2>
      <p className="mt-2 text-gray-500 text-sm">
        No member was found with ID <span className="font-mono font-medium">{memberId || "unknown"}</span>.
        Please check the QR code and try again.
      </p>
    </div>
  );
}

function ErrorCard() {
  return (
    <div className="bg-white rounded-2xl shadow-lg p-8 text-center">
      <AlertTriangle className="w-12 h-12 text-red-500 mx-auto" />
      <h2 className="mt-4 text-lg font-bold text-gray-900">Verification Error</h2>
      <p className="mt-2 text-gray-500 text-sm">
        An error occurred while verifying this member. Please try again later.
      </p>
    </div>
  );
}
