import { Routes, Route, Navigate } from "react-router-dom";
import AppLayout from "./layout/AppLayout";
import Dashboard from "./features/dashboard/Dashboard";
import UserManagement from "./features/users/UserManagement";
import ContentPush from "./features/content/ContentPush";
import EventManagement from "./features/events/EventManagement";
import PagePlaceholder from "./pages/PagePlaceholder";
import UploadDocuments from "./features/documents/UploadDocuments";
import MediaManagement from "./features/media/MediaManagement";
import ConstituencyManagement from "./features/constituencies/ConstituencyManagement";
import DistrictsManagement from "./features/districts/DistrictsManagement";
import VoterListManagement from "./features/voterList/VoterListManagement";
import SchemeBeneficiaryManagement from "./features/schemeBeneficiary/SchemeBeneficiaryManagement";
import SchemesManagement from "./features/schemes/SchemesManagement";
import Login from "./pages/Login";
import Profile from "./pages/Profile";
import Settings from "./pages/Settings";
import VerifyMember from "./pages/VerifyMember";
import ProtectedRoute from "./components/ProtectedRoute";

export default function App() {
  console.log('App component rendering');
  
  return (
    <Routes>
      {/* Public routes (no auth required) */}
      <Route path="/login" element={<Login />} />
      <Route path="/verify/:memberId" element={<VerifyMember />} />
      
      {/* Protected routes */}
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <AppLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<Dashboard />} />
        <Route path="users" element={<UserManagement />} />
        <Route path="content" element={<ContentPush />} />
        <Route path="events" element={<EventManagement />} />
        <Route path="media" element={<MediaManagement />} />
        <Route path="constituencies" element={<ConstituencyManagement />} />
        <Route path="districts" element={<DistrictsManagement />} />
        <Route path="voter-list" element={<VoterListManagement />} />
        <Route path="scheme-beneficiaries" element={<SchemeBeneficiaryManagement />} />
        <Route path="schemes" element={<SchemesManagement />} />
        <Route path="analytics" element={<PagePlaceholder title="Analytics" />} />
        <Route path="uploads" element={<UploadDocuments />} />
        <Route path="profile" element={<Profile />} />
        <Route path="settings" element={<Settings />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
