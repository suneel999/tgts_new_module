import { useLocation, useNavigate } from "react-router-dom";
import { Menu, LogOut, User } from "lucide-react";
import { authService } from "../services/authService";

interface HeaderProps {
  onMenuClick: () => void;
}

export default function Header({ onMenuClick }: HeaderProps) {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const isDashboard = pathname === "/";
  const user = authService.getStoredUser();
  
  // Get page title from pathname
  const getPageTitle = () => {
    if (pathname === "/") return "Dashboard";
    if (pathname === "/users") return "User Management";
    if (pathname === "/content") return "News";
    if (pathname === "/events") return "Event Management";
    if (pathname === "/media") return "Media Gallery";
    if (pathname === "/constituencies") return "Constituency Management";
    if (pathname === "/analytics") return "Analytics";
    if (pathname === "/uploads") return "Upload Documents";
    if (pathname === "/profile") return "My Profile";
    if (pathname === "/settings") return "Settings";
    if (pathname === "/districts") return "Districts & Mandals";
    return "Admin Panel";
  };

  const handleLogout = () => {
    if (confirm("Are you sure you want to logout?")) {
      authService.logout();
    }
  };

  return (
    <header className="h-14 border-b bg-white sticky top-0 z-30 shadow-sm">
      <div className="h-full px-4 flex items-center justify-between">
        <div className="flex items-center gap-4">
          {/* Hamburger Menu Button - Mobile Only */}
          <button
            onClick={onMenuClick}
            className="md:hidden p-2 hover:bg-gray-100 rounded-md transition-colors"
            aria-label="Toggle menu"
          >
            <Menu className="w-6 h-6 text-gray-700" />
          </button>
          
          {/* Page Title */}
          <div>
            <div className="text-lg md:text-xl font-semibold">{getPageTitle()}</div>
            {isDashboard && (
              <div className="hidden md:block text-xs text-gray-500">
                Overview of key metrics and activities
              </div>
            )}
          </div>
        </div>

        {/* User Info and Logout */}
        <div className="flex items-center gap-3">
          {user && (
            <button
              onClick={() => navigate('/profile')}
              className="hidden md:flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900 hover:bg-gray-100 px-3 py-2 rounded-md transition-colors cursor-pointer"
              title="View Profile"
            >
              <User className="w-4 h-4" />
              <span>{user.name || "Admin"}</span>
            </button>
          )}
          <button
            onClick={handleLogout}
            className="flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 rounded-md transition-colors"
            title="Logout"
          >
            <LogOut className="w-4 h-4" />
            <span className="hidden md:inline">Logout</span>
          </button>
        </div>
      </div>
    </header>
  );
}