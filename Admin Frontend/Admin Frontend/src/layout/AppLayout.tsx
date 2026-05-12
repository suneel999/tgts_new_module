import { Outlet } from "react-router-dom";
import { useState, useEffect } from "react";
import Sidebar from "./Sidebar";
import Header from "./Header";
import { mediaService } from "../services/mediaService";
import { setCachedMediaStats } from "../utils/mediaStatsCache";

export default function AppLayout() {
  console.log('AppLayout rendering');
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  // Preload media stats when app layout loads (so it's ready when user navigates to media tab)
  useEffect(() => {
    const preloadMediaStats = async () => {
      try {
        const stats = await mediaService.getMediaStats();
        setCachedMediaStats(stats);
        console.log('Media stats preloaded:', stats);
      } catch (err) {
        console.error('Failed to preload media stats:', err);
        // Silently fail - will be loaded when user visits media tab
      }
    };
    
    preloadMediaStats();
  }, []);

  // Close mobile menu when clicking outside
  useEffect(() => {
    const handleResize = () => {
      if (window.innerWidth >= 768) {
        setIsMobileMenuOpen(false);
      }
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  // Prevent body scroll when mobile menu is open
  useEffect(() => {
    if (isMobileMenuOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = 'unset';
    }
    return () => {
      document.body.style.overflow = 'unset';
    };
  }, [isMobileMenuOpen]);
  
  return (
    <div className="flex flex-col md:flex-row min-h-screen">
      {/* Mobile Menu Overlay */}
      {isMobileMenuOpen && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 z-40 md:hidden"
          onClick={() => setIsMobileMenuOpen(false)}
        />
      )}
      
      {/* Sidebar */}
      <Sidebar isOpen={isMobileMenuOpen} onClose={() => setIsMobileMenuOpen(false)} />
      
      {/* Main Content */}
      <div className="flex-1 flex flex-col min-h-screen bg-gray-50 md:ml-0">
        <Header onMenuClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)} />
        <main className="flex-1 p-4 md:p-6 overflow-auto">
          <Outlet />
        </main>
      </div>
    </div>
  );
}