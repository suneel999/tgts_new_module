import { NavLink } from "react-router-dom";
import { Home, Users, Megaphone, CalendarDays, Upload, Languages, Image, X, MapPin, Map, Settings, Vote, Gift, BookOpen } from "lucide-react";
import { useState } from "react";

const nav = [
  { to: "/", label: "Dashboard", icon: Home },
  { to: "/users", label: "User Management", icon: Users },
  { to: "/content", label: "News", icon: Megaphone },
  { to: "/events", label: "Event Management", icon: CalendarDays },
  { to: "/media", label: "Media Gallery", icon: Image },
  { to: "/uploads", label: "Upload Documents", icon: Upload },
  { to: "/constituencies", label: "Constituencies", icon: MapPin },
  { to: "/districts", label: "Districts & Mandals", icon: Map },
  { to: "/voter-list", label: "Voter List", icon: Vote },
  { to: "/schemes", label: "Schemes", icon: BookOpen },
  { to: "/scheme-beneficiaries", label: "Scheme Beneficiaries", icon: Gift },
  { to: "/settings", label: "Settings", icon: Settings },
];

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function Sidebar({ isOpen, onClose }: SidebarProps) {
  const [language, setLanguage] = useState<"en" | "te">("en");

  const handleNavClick = () => {
    // Close mobile menu when navigating
    if (window.innerWidth < 768) {
      onClose();
    }
  };

  return (
    <>
      {/* Mobile Overlay Sidebar */}
      <aside
        className={`
          fixed md:static inset-y-0 left-0 z-50
          w-64 min-h-screen bg-gradient-to-b from-orange-500 via-white to-green-500 text-gray-900 flex flex-col
          transform transition-transform duration-300 ease-in-out
          ${isOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0'}
        `}
      >
        {/* Mobile Close Button */}
        <div className="md:hidden flex items-center justify-between px-5 py-4 border-b border-gray-300/30">
          <div>
            <div className="font-semibold text-xl text-gray-900">Admin Panel</div>
            <div className="text-sm text-gray-700">Telangana Congress</div>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-200/50 rounded-md transition-colors"
            aria-label="Close menu"
          >
            <X className="w-6 h-6 text-gray-900" />
          </button>
        </div>

        {/* Desktop Header */}
        <div className="hidden md:block px-5 py-6">
          <div className="font-semibold text-xl text-gray-900">Admin Panel</div>
          <div className="text-sm text-gray-700">Telangana Congress</div>
        </div>

        {/* Navigation */}
        <nav className="flex-1 px-3 space-y-2 overflow-y-auto">
          {nav.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              end={to === "/"}
              onClick={handleNavClick}
              className={({ isActive }) =>
                `flex items-center gap-3 px-4 py-3 rounded-lg font-medium text-base transition 
                 ${isActive ? "bg-gray-200/60 shadow-sm" : "hover:bg-gray-200/40"} text-gray-900`
              }
            >
              <Icon className="w-5 h-5 md:w-6 md:h-6 flex-shrink-0" />
              <span className="text-sm md:text-base">{label}</span>
            </NavLink>
          ))}
        </nav>

        {/* Footer Actions */}
        <div className="mt-auto px-2 pb-4 space-y-2 border-t border-gray-300/30 pt-4">
          <button
            className="flex items-center gap-2 w-full px-3 py-2 rounded-md bg-gray-200/40 hover:bg-gray-200/60 transition text-gray-900"
            onClick={() => setLanguage(language === "en" ? "te" : "en")}
            aria-label="Change language"
            title="Change language"
          >
            <Languages className="w-5 h-5" />
            <span className="text-sm">{language === "en" ? "తెలుగు" : "English"}</span>
          </button>
        </div>
      </aside>
    </>
  );
}