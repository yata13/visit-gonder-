
import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useLanguage } from '../components/LanguageContext';
import { Listing } from '../types';
import { supabaseService } from '../services/supabaseService';
import { MapPin, Phone, Globe, MessageCircle, ChevronLeft, Clock, DollarSign, Lightbulb } from 'lucide-react';

const ListingDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { language, t } = useLanguage();
  const [listing, setListing] = useState<Listing | null>(null);

  useEffect(() => {
    if (id) {
      supabaseService.getListingById(id).then(setListing);
    }
  }, [id]);

  if (!listing) return <div className="p-10 text-center">Loading...</div>;

  const name = language === 'en' ? listing.name_en : listing.name_am;
  const desc = language === 'en' ? listing.desc_en : listing.desc_am;
  const details = language === 'en' ? listing.details_en : listing.details_am;
  const address = language === 'en' ? listing.address_en : listing.address_am;

  return (
    <div className="max-w-5xl mx-auto px-4 py-8">
      <button 
        onClick={() => navigate(-1)}
        className="flex items-center text-slate-500 hover:text-amber-600 mb-6 transition-colors"
      >
        <ChevronLeft className="h-5 w-5 mr-1" />
        Back
      </button>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Main Content */}
        <div className="lg:col-span-2">
          <div className="rounded-3xl overflow-hidden shadow-lg mb-8 aspect-video">
            <img src={listing.image_url} alt={name} className="w-full h-full object-cover" />
          </div>

          <div className="mb-8">
            <div className="flex items-center gap-2 mb-2">
               <span className="bg-amber-100 text-amber-700 px-3 py-1 rounded-full text-xs font-bold uppercase">
                {listing.category || listing.type}
              </span>
              {listing.price_level && (
                 <span className="bg-slate-100 text-slate-600 px-3 py-1 rounded-full text-xs font-bold">
                  {listing.price_level}
                </span>
              )}
            </div>
            <h1 className="text-3xl md:text-4xl font-extrabold text-slate-900 mb-4">{name}</h1>
            <div className="flex items-center text-slate-500 mb-6">
              <MapPin className="h-4 w-4 mr-2 text-amber-600" />
              <span className="text-sm">{address}</span>
            </div>
            
            <p className="text-lg text-slate-700 leading-relaxed mb-10 whitespace-pre-wrap">
              {details}
            </p>

            <div className="bg-white border border-slate-200 rounded-2xl p-6">
              <h2 className="text-xl font-bold mb-4 flex items-center">
                <Info className="h-5 w-5 mr-2 text-amber-600" />
                {t('visiting_info')}
              </h2>
              <div className="space-y-4">
                <div className="flex items-start">
                  <Clock className="h-5 w-5 text-slate-400 mr-3 mt-1" />
                  <div>
                    <div className="font-semibold text-slate-800">{t('open_hours')}</div>
                    <div className="text-slate-600">Typically 8:30 AM – 5:30 PM</div>
                  </div>
                </div>
                <div className="flex items-start">
                  <DollarSign className="h-5 w-5 text-slate-400 mr-3 mt-1" />
                  <div>
                    <div className="font-semibold text-slate-800">{t('entry_fee')}</div>
                    <div className="text-slate-600">Varies (100–500 ETB for tourists)</div>
                  </div>
                </div>
                <div className="flex items-start">
                  <Lightbulb className="h-5 w-5 text-slate-400 mr-3 mt-1" />
                  <div>
                    <div className="font-semibold text-slate-800">Visiting Tip</div>
                    <div className="text-slate-600">Hire a licensed guide at the entrance for the best experience.</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Sidebar Actions */}
        <div className="lg:col-span-1">
          <div className="sticky top-24 space-y-4">
            <div className="bg-white border border-slate-200 rounded-2xl p-6 shadow-sm">
              <h3 className="font-bold text-slate-800 mb-6">Connect & Navigate</h3>
              <div className="space-y-3">
                <a 
                  href={`https://www.google.com/maps/dir/?api=1&destination=${listing.lat},${listing.lng}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center justify-center w-full py-3 bg-amber-600 hover:bg-amber-700 text-white font-bold rounded-xl transition-colors"
                >
                  <MapPin className="h-5 w-5 mr-2" />
                  {t('directions')}
                </a>
                {listing.phone && (
                  <a 
                    href={`tel:${listing.phone}`}
                    className="flex items-center justify-center w-full py-3 bg-white border-2 border-slate-100 hover:border-amber-100 text-slate-700 font-bold rounded-xl transition-colors"
                  >
                    <Phone className="h-5 w-5 mr-2 text-amber-600" />
                    {t('call')}
                  </a>
                )}
                {listing.whatsapp && (
                   <a 
                    href={`https://wa.me/${listing.whatsapp}`}
                    className="flex items-center justify-center w-full py-3 bg-white border-2 border-slate-100 hover:border-green-100 text-slate-700 font-bold rounded-xl transition-colors"
                  >
                    <MessageCircle className="h-5 w-5 mr-2 text-green-600" />
                    {t('whatsapp')}
                  </a>
                )}
                {listing.website_url && (
                  <a 
                    href={listing.website_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center justify-center w-full py-3 bg-slate-50 text-slate-600 font-bold rounded-xl hover:bg-slate-100 transition-colors"
                  >
                    <Globe className="h-5 w-5 mr-2" />
                    {t('visit_website')}
                  </a>
                )}
              </div>
            </div>

            {listing.amenities && (
              <div className="bg-slate-900 rounded-2xl p-6 text-white">
                <h3 className="font-bold mb-4">Amenities</h3>
                <div className="grid grid-cols-2 gap-3">
                  {listing.amenities.map(item => (
                    <div key={item} className="flex items-center text-sm text-slate-300">
                      <div className="h-1.5 w-1.5 bg-amber-500 rounded-full mr-2"></div>
                      {item}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

// Internal Info icon duplicate to avoid export issues
const Info: React.FC<{ className?: string }> = ({ className }) => (
  <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>
);

export default ListingDetail;
