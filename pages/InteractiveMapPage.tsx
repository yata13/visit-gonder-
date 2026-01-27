
import React, { useEffect, useRef, useState } from 'react';
import { useLanguage } from '../components/LanguageContext';
import { Listing, ListingType } from '../types';
import { supabaseService } from '../services/supabaseService';
import { MapPin, Navigation, Info, Phone, X } from 'lucide-react';

declare const L: any;

const InteractiveMapPage: React.FC = () => {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<any>(null);
  const markersRef = useRef<any[]>([]);
  const { language, t } = useLanguage();
  const [listings, setListings] = useState<Listing[]>([]);
  const [selectedListing, setSelectedListing] = useState<Listing | null>(null);
  const [activeFilter, setActiveFilter] = useState<ListingType | 'all'>('all');

  useEffect(() => {
    supabaseService.getListings().then(setListings);
  }, []);

  useEffect(() => {
    if (mapContainerRef.current && !mapRef.current) {
      mapRef.current = L.map(mapContainerRef.current).setView([12.6072, 37.4695], 14);
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors'
      }).addTo(mapRef.current);
    }

    return () => {
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
    };
  }, []);

  useEffect(() => {
    if (!mapRef.current || listings.length === 0) return;

    // Clear existing markers
    markersRef.current.forEach(m => m.remove());
    markersRef.current = [];

    const filtered = activeFilter === 'all' 
      ? listings 
      : listings.filter(l => l.type === activeFilter);

    filtered.forEach(listing => {
      const marker = L.marker([listing.lat, listing.lng])
        .addTo(mapRef.current)
        .on('click', () => setSelectedListing(listing));
      markersRef.current.push(marker);
    });
  }, [listings, activeFilter]);

  const handleLocateMe = () => {
    if (navigator.geolocation && mapRef.current) {
      navigator.geolocation.getCurrentPosition((pos) => {
        const { latitude, longitude } = pos.coords;
        mapRef.current.flyTo([latitude, longitude], 16);
        L.circle([latitude, longitude], { radius: 20, color: '#f59e0b' }).addTo(mapRef.current);
      });
    }
  };

  return (
    <div className="fixed inset-0 top-16 bg-white flex flex-col md:flex-row overflow-hidden">
      {/* Sidebar - Hidden on mobile by default or shown as small overlay */}
      <div className="w-full md:w-80 lg:w-96 border-r flex flex-col h-1/3 md:h-full bg-slate-50 relative z-20 shadow-xl md:shadow-none">
        <div className="p-4 border-b bg-white">
          <h2 className="font-bold text-slate-800 text-lg mb-3">Gondar Map</h2>
          <div className="flex gap-2 overflow-x-auto pb-2">
            {(['all', ...Object.values(ListingType)] as const).map(f => (
              <button
                key={f}
                onClick={() => setActiveFilter(f)}
                className={`px-3 py-1 rounded-full text-xs font-bold whitespace-nowrap uppercase tracking-wider transition-colors ${
                  activeFilter === f ? 'bg-amber-600 text-white' : 'bg-slate-200 text-slate-600 hover:bg-slate-300'
                }`}
              >
                {f}
              </button>
            ))}
          </div>
        </div>
        
        <div className="flex-1 overflow-y-auto p-2 space-y-2">
          {listings
            .filter(l => activeFilter === 'all' || l.type === activeFilter)
            .map(l => (
            <button
              key={l.id}
              onClick={() => {
                setSelectedListing(l);
                mapRef.current.flyTo([l.lat, l.lng], 16);
              }}
              className={`w-full text-left p-3 rounded-xl transition-all border ${
                selectedListing?.id === l.id ? 'bg-amber-50 border-amber-300' : 'bg-white border-transparent hover:border-slate-200'
              }`}
            >
              <div className="font-bold text-slate-800 line-clamp-1">{language === 'en' ? l.name_en : l.name_am}</div>
              <div className="text-xs text-slate-500 mt-1 flex items-center">
                <MapPin className="h-3 w-3 mr-1" />
                {l.area}
              </div>
            </button>
          ))}
        </div>
      </div>

      {/* Map Content */}
      <div className="flex-1 relative">
        <div ref={mapContainerRef} className="w-full h-full" />
        
        {/* Map Controls */}
        <div className="absolute top-4 right-4 z-[1001] flex flex-col gap-2">
          <button 
            onClick={handleLocateMe}
            className="p-3 bg-white rounded-full shadow-lg hover:bg-slate-50 text-amber-600"
            title="Locate me"
          >
            <Navigation className="h-6 w-6" />
          </button>
        </div>

        {/* Info Popup (Simulated Custom UI) */}
        {selectedListing && (
          <div className="absolute bottom-6 left-1/2 -translate-x-1/2 md:left-6 md:translate-x-0 w-[90%] md:w-96 bg-white rounded-2xl shadow-2xl z-[1002] overflow-hidden animate-in fade-in slide-in-from-bottom-4 duration-300">
            <div className="relative h-32">
              <img src={selectedListing.image_url} alt="" className="w-full h-full object-cover" />
              <button 
                onClick={() => setSelectedListing(null)}
                className="absolute top-2 right-2 p-1 bg-black/50 text-white rounded-full backdrop-blur"
              >
                <X className="h-4 w-4" />
              </button>
            </div>
            <div className="p-4">
              <h3 className="font-bold text-lg text-slate-800 line-clamp-1">
                {language === 'en' ? selectedListing.name_en : selectedListing.name_am}
              </h3>
              <p className="text-sm text-slate-600 mt-1 line-clamp-2">
                {language === 'en' ? selectedListing.desc_en : selectedListing.desc_am}
              </p>
              
              <div className="flex gap-2 mt-4">
                 <a
                    href={`https://www.google.com/maps/dir/?api=1&destination=${selectedListing.lat},${selectedListing.lng}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex-1 bg-amber-600 text-white py-2 rounded-lg text-sm font-bold text-center flex items-center justify-center gap-2"
                  >
                    <MapPin className="h-4 w-4" />
                    {t('directions')}
                  </a>
                  {selectedListing.phone && (
                    <a href={`tel:${selectedListing.phone}`} className="p-2 border rounded-lg text-slate-600">
                      <Phone className="h-5 w-5" />
                    </a>
                  )}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default InteractiveMapPage;
