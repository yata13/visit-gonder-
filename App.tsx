
import React from 'react';
import { HashRouter as Router, Routes, Route, Link } from 'react-router-dom';
import { LanguageProvider } from './components/LanguageContext';
import Navbar from './components/Navbar';
import Home from './pages/Home';
import ListingList from './pages/ListingList';
import ListingDetail from './pages/ListingDetail';
import InteractiveMapPage from './pages/InteractiveMapPage';
import TimketGuide from './pages/TimketGuide';
import Events from './pages/Events';
import AdminLogin from './pages/AdminLogin';
import AdminDashboard from './pages/AdminDashboard';
import { ListingType } from './types';

const App: React.FC = () => {
  return (
    <LanguageProvider>
      <Router>
        <div className="min-h-screen flex flex-col bg-gradient-to-br from-slate-50 to-amber-50">
          <Navbar />
          <main className="flex-grow">
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/attractions" element={<ListingList type={ListingType.ATTRACTION} titleKey="attractions" />} />
              <Route path="/hotels" element={<ListingList type={ListingType.HOTEL} titleKey="hotels" />} />
              <Route path="/restaurants" element={<ListingList type={ListingType.RESTAURANT} titleKey="restaurants" />} />
              <Route path="/events" element={<Events />} />
              <Route path="/details/:id" element={<ListingDetail />} />
              <Route path="/map" element={<InteractiveMapPage />} />
              <Route path="/timket" element={<TimketGuide />} />
              
              {/* Admin Routes */}
              <Route path="/admin/login" element={<AdminLogin />} />
              <Route path="/admin/dashboard" element={<AdminDashboard />} />

              {/* Fallback for other routes */}
              <Route path="*" element={
                <div className="min-h-screen flex items-center justify-center">
                  <div className="text-center p-8">
                    <div className="mb-8">
                      <div className="w-24 h-24 bg-amber-100 rounded-full flex items-center justify-center mx-auto mb-4">
                        <span className="text-4xl">🏰</span>
                      </div>
                      <h1 className="text-6xl font-bold text-slate-800 mb-4">404</h1>
                      <h2 className="text-2xl font-semibold text-slate-700 mb-4">Page Not Found</h2>
                      <p className="text-slate-600 mb-8 max-w-md mx-auto">
                        The page you're looking for seems to have vanished into the Ethiopian highlands.
                      </p>
                    </div>
                    <Link 
                      to="/" 
                      className="inline-flex items-center space-x-2 bg-gradient-to-r from-amber-600 to-amber-700 hover:from-amber-700 hover:to-amber-800 text-white px-8 py-4 rounded-xl font-semibold transition-all duration-300 transform hover:scale-105 shadow-lg"
                    >
                      <span>Return Home</span>
                      <span>🏠</span>
                    </Link>
                  </div>
                </div>
              } />
            </Routes>
          </main>
          <footer className="bg-gradient-to-r from-slate-900 to-slate-800 border-t border-slate-700 py-16 px-4 mt-20">
             <div className="max-w-7xl mx-auto">
                <div className="grid grid-cols-1 md:grid-cols-4 gap-8 mb-8">
                  {/* Brand */}
                  <div className="md:col-span-2">
                    <div className="flex items-center space-x-3 mb-4">
                      <div className="w-10 h-10 bg-amber-600 rounded-lg flex items-center justify-center">
                        <span className="text-white font-bold">VG</span>
                      </div>
                      <div>
                        <h3 className="text-xl font-bold text-white">Visit Gondar</h3>
                        <p className="text-slate-400 text-sm">Digital Tourism Hub</p>
                      </div>
                    </div>
                    <p className="text-slate-400 leading-relaxed max-w-md">
                      Discover the medieval castles, sacred churches, and cultural wonders of Ethiopia's historic capital.
                    </p>
                  </div>
                  
                  {/* Quick Links */}
                  <div>
                    <h4 className="text-white font-semibold mb-4">Quick Links</h4>
                    <div className="space-y-2">
                      <Link to="/" className="block text-slate-400 hover:text-amber-400 transition-colors">Home</Link>
                      <Link to="/attractions" className="block text-slate-400 hover:text-amber-400 transition-colors">Attractions</Link>
                      <Link to="/hotels" className="block text-slate-400 hover:text-amber-400 transition-colors">Hotels</Link>
                      <Link to="/restaurants" className="block text-slate-400 hover:text-amber-400 transition-colors">Restaurants</Link>
                    </div>
                  </div>
                  
                  {/* Resources */}
                  <div>
                    <h4 className="text-white font-semibold mb-4">Resources</h4>
                    <div className="space-y-2">
                      <Link to="/map" className="block text-slate-400 hover:text-amber-400 transition-colors">Interactive Map</Link>
                      <Link to="/events" className="block text-slate-400 hover:text-amber-400 transition-colors">Events</Link>
                      <Link to="/admin/login" className="block text-slate-400 hover:text-amber-400 transition-colors font-semibold">Admin Portal</Link>
                      <a href="#" className="block text-slate-400 hover:text-amber-400 transition-colors">Privacy Policy</a>
                    </div>
                  </div>
                </div>
                
                {/* Bottom Bar */}
                <div className="border-t border-slate-700 pt-8">
                  <div className="flex flex-col md:flex-row justify-between items-center">
                    <div className="text-slate-400 text-sm mb-4 md:mb-0">
                      © 2024 Visit Gondar — Digital Tourism Hub. All rights reserved.
                    </div>
                    <div className="flex items-center space-x-6">
                      <span className="text-slate-500 text-sm">Made with ❤️ for Ethiopia</span>
                    </div>
                  </div>
                </div>
             </div>
          </footer>
        </div>
      </Router>
    </LanguageProvider>
  );
};

export default App;
