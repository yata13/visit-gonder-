
import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Listing, ListingType, Status, Event } from '../types';
import { supabaseService } from '../services/supabaseService';
import { Plus, Edit, Trash2, CheckCircle, XCircle, LayoutGrid, List, LogOut, Star } from 'lucide-react';

const AdminDashboard: React.FC = () => {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState<'listings' | 'events'>('listings');
  const [listings, setListings] = useState<Listing[]>([]);
  const [events, setEvents] = useState<Event[]>([]);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingItem, setEditingItem] = useState<any>(null);

  useEffect(() => {
    if (localStorage.getItem('isAdmin') !== 'true') {
      navigate('/admin/login');
    }
    fetchData();
  }, [navigate]);

  const fetchData = async () => {
    const l = await supabaseService.getAllListings();
    const e = await supabaseService.getEvents();
    setListings(l);
    setEvents(e);
  };

  const handleLogout = () => {
    localStorage.removeItem('isAdmin');
    navigate('/');
  };

  const handleDeleteListing = async (id: string) => {
    if (window.confirm('Are you sure you want to delete this listing?')) {
      await supabaseService.deleteListing(id);
      fetchData();
    }
  };

  const handleToggleStatus = async (listing: Listing) => {
    const newStatus = listing.status === Status.PUBLISHED ? Status.DRAFT : Status.PUBLISHED;
    await supabaseService.saveListing({ ...listing, status: newStatus });
    fetchData();
  };

  const handleToggleFeatured = async (listing: Listing) => {
    await supabaseService.saveListing({ ...listing, featured: !listing.featured });
    fetchData();
  };

  return (
    <div className="bg-slate-50 min-h-screen">
      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-8 gap-4">
          <div>
            <h1 className="text-3xl font-bold text-slate-800">Dashboard</h1>
            <p className="text-slate-500">Manage your tourism hub content</p>
          </div>
          <div className="flex gap-3">
            <button
              onClick={() => { setEditingItem(null); setIsModalOpen(true); }}
              className="bg-amber-600 text-white px-4 py-2 rounded-xl font-bold flex items-center gap-2 hover:bg-amber-700 transition-colors"
            >
              <Plus className="h-4 w-4" /> Add New
            </button>
            <button
              onClick={handleLogout}
              className="bg-white border border-slate-200 text-slate-600 px-4 py-2 rounded-xl font-bold flex items-center gap-2 hover:bg-slate-50 transition-colors"
            >
              <LogOut className="h-4 w-4" /> Logout
            </button>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex gap-4 border-b border-slate-200 mb-8">
          <button
            onClick={() => setActiveTab('listings')}
            className={`pb-4 px-2 font-bold transition-colors relative ${activeTab === 'listings' ? 'text-amber-600' : 'text-slate-400'}`}
          >
            Listings
            {activeTab === 'listings' && <div className="absolute bottom-0 left-0 right-0 h-1 bg-amber-600 rounded-t-full" />}
          </button>
          <button
            onClick={() => setActiveTab('events')}
            className={`pb-4 px-2 font-bold transition-colors relative ${activeTab === 'events' ? 'text-amber-600' : 'text-slate-400'}`}
          >
            Events
            {activeTab === 'events' && <div className="absolute bottom-0 left-0 right-0 h-1 bg-amber-600 rounded-t-full" />}
          </button>
        </div>

        {/* Table View */}
        <div className="bg-white rounded-3xl border border-slate-200 shadow-sm overflow-hidden">
          <div className="overflow-x-auto">
            {activeTab === 'listings' ? (
              <table className="w-full text-left">
                <thead className="bg-slate-50 border-b border-slate-200 text-slate-500 uppercase text-xs font-bold">
                  <tr>
                    <th className="px-6 py-4">Image & Name</th>
                    <th className="px-6 py-4">Type</th>
                    <th className="px-6 py-4">Area</th>
                    <th className="px-6 py-4">Status</th>
                    <th className="px-6 py-4">Featured</th>
                    <th className="px-6 py-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {listings.map(l => (
                    <tr key={l.id} className="hover:bg-slate-50 transition-colors">
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <img src={l.image_url} className="w-12 h-12 rounded-lg object-cover" alt="" />
                          <div>
                            <div className="font-bold text-slate-800">{l.name_en}</div>
                            <div className="text-xs text-slate-400">{l.name_am}</div>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <span className="text-xs font-bold uppercase text-slate-500 bg-slate-100 px-2 py-1 rounded">
                          {l.type}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-sm text-slate-600">{l.area}</td>
                      <td className="px-6 py-4">
                        <button 
                          onClick={() => handleToggleStatus(l)}
                          className={`flex items-center gap-1 text-xs font-bold ${l.status === Status.PUBLISHED ? 'text-emerald-600' : 'text-slate-400'}`}
                        >
                          {l.status === Status.PUBLISHED ? <CheckCircle className="h-4 w-4" /> : <XCircle className="h-4 w-4" />}
                          {l.status}
                        </button>
                      </td>
                      <td className="px-6 py-4">
                        <button 
                           onClick={() => handleToggleFeatured(l)}
                           className={`p-1 rounded-full transition-colors ${l.featured ? 'text-amber-500 bg-amber-50' : 'text-slate-200'}`}
                        >
                          <Star className="h-5 w-5 fill-current" />
                        </button>
                      </td>
                      <td className="px-6 py-4 text-right">
                        <div className="flex justify-end gap-2">
                          <button className="p-2 text-slate-400 hover:text-amber-600 transition-colors">
                            <Edit className="h-5 w-5" />
                          </button>
                          <button 
                            onClick={() => handleDeleteListing(l.id)}
                            className="p-2 text-slate-400 hover:text-red-600 transition-colors"
                          >
                            <Trash2 className="h-5 w-5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <table className="w-full text-left">
                <thead className="bg-slate-50 border-b border-slate-200 text-slate-500 uppercase text-xs font-bold">
                  <tr>
                    <th className="px-6 py-4">Image & Title</th>
                    <th className="px-6 py-4">Date</th>
                    <th className="px-6 py-4">Location</th>
                    <th className="px-6 py-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {events.map(e => (
                    <tr key={e.id} className="hover:bg-slate-50 transition-colors">
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <img src={e.image_url} className="w-12 h-12 rounded-lg object-cover" alt="" />
                          <div className="font-bold text-slate-800">{e.title_en}</div>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-sm text-slate-600">{e.start_date}</td>
                      <td className="px-6 py-4 text-sm text-slate-600">{e.location_name_en}</td>
                      <td className="px-6 py-4 text-right">
                        <div className="flex justify-end gap-2">
                          <button className="p-2 text-slate-400 hover:text-amber-600 transition-colors">
                            <Edit className="h-5 w-5" />
                          </button>
                          <button className="p-2 text-slate-400 hover:text-red-600 transition-colors">
                            <Trash2 className="h-5 w-5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>

        {/* Modal Overlay (Simplified form placeholder) */}
        {isModalOpen && (
          <div className="fixed inset-0 z-[2000] flex items-center justify-center p-4">
            <div className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm" onClick={() => setIsModalOpen(false)} />
            <div className="bg-white rounded-3xl w-full max-w-2xl p-8 relative z-10 shadow-2xl overflow-y-auto max-h-[90vh]">
              <h2 className="text-2xl font-bold mb-6">Add New Listing</h2>
              <div className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium mb-1">English Name</label>
                    <input type="text" className="w-full p-2 border rounded-lg" />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-1">Amharic Name</label>
                    <input type="text" className="w-full p-2 border rounded-lg" />
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-medium mb-1">Listing Type</label>
                  <select className="w-full p-2 border rounded-lg">
                    <option value="attraction">Attraction</option>
                    <option value="hotel">Hotel</option>
                    <option value="restaurant">Restaurant</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium mb-1">Image URL</label>
                  <input type="text" placeholder="https://..." className="w-full p-2 border rounded-lg" />
                </div>
                <div className="flex gap-4 pt-4">
                  <button 
                    onClick={() => {
                      alert('Successfully saved (Simulated)');
                      setIsModalOpen(false);
                    }}
                    className="flex-1 bg-amber-600 text-white font-bold py-3 rounded-xl"
                  >
                    Save Changes
                  </button>
                  <button 
                    onClick={() => setIsModalOpen(false)}
                    className="px-6 py-3 border rounded-xl font-bold"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default AdminDashboard;
