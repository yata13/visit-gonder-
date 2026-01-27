
import React, { useState, useEffect } from 'react';
import { useLanguage } from '../components/LanguageContext';
import { Event as EventType } from '../types';
import { supabaseService } from '../services/supabaseService';
import { Calendar, MapPin, Clock, ArrowRight } from 'lucide-react';
import { Link } from 'react-router-dom';

const Events: React.FC = () => {
  const { language, t } = useLanguage();
  const [events, setEvents] = useState<EventType[]>([]);

  useEffect(() => {
    supabaseService.getEvents().then(setEvents);
  }, []);

  return (
    <div className="max-w-7xl mx-auto px-4 py-12">
      <div className="mb-12">
        <h1 className="text-4xl font-extrabold text-slate-900 mb-4">{t('events')}</h1>
        <p className="text-slate-500">Plan your visit around Gondar's most vibrant celebrations and cultural gatherings.</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {events.map((event) => {
          const title = language === 'en' ? event.title_en : event.title_am;
          const desc = language === 'en' ? event.desc_en : event.desc_am;
          const location = language === 'en' ? event.location_name_en : event.location_name_am;
          
          return (
            <div key={event.id} className="bg-white rounded-3xl overflow-hidden shadow-sm border border-slate-200 flex flex-col md:flex-row group">
              <div className="md:w-1/3 h-48 md:h-auto overflow-hidden">
                <img src={event.image_url} alt={title} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" />
              </div>
              <div className="md:w-2/3 p-6 flex flex-col">
                <div className="flex items-center gap-2 text-amber-600 font-bold text-xs uppercase tracking-widest mb-3">
                  <Calendar className="h-4 w-4" />
                  {new Date(event.start_date).toLocaleDateString(language === 'en' ? 'en-US' : 'am-ET', { month: 'long', day: 'numeric', year: 'numeric' })}
                </div>
                <h2 className="text-2xl font-bold text-slate-800 mb-2">{title}</h2>
                <p className="text-slate-600 text-sm mb-6 flex-grow">{desc}</p>
                
                <div className="space-y-2 mb-6">
                  <div className="flex items-center text-slate-500 text-sm">
                    <MapPin className="h-4 w-4 mr-2" />
                    {location}
                  </div>
                </div>

                <div className="flex gap-3">
                  {event.title_en.toLowerCase().includes('timket') && (
                    <Link 
                      to="/timket"
                      className="inline-flex items-center text-amber-600 font-bold hover:gap-2 transition-all text-sm"
                    >
                      View Timket Guide <ArrowRight className="h-4 w-4 ml-1" />
                    </Link>
                  )}
                  <button className="text-slate-400 font-medium text-sm hover:text-slate-600 ml-auto">
                    Add to Calendar
                  </button>
                </div>
              </div>
            </div>
          );
        })}
      </div>
      
      {events.length === 0 && (
        <div className="text-center py-20 text-slate-400">
          No upcoming events at the moment. Check back later!
        </div>
      )}
    </div>
  );
};

export default Events;
