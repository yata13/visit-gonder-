
import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useLanguage } from '../components/LanguageContext';
import { Listing, ListingType, Event } from '../types';
import { supabaseService } from '../services/supabaseService';
import Card from '../components/Card';
import SkeletonCard from '../components/SkeletonCard';
import { Search, Map as MapIcon, Calendar, Utensils, Hotel, Castle, ArrowRight, Sparkles, Compass, Camera } from 'lucide-react';

const Home: React.FC = () => {
  const { t } = useLanguage();
  const [featuredAttractions, setFeaturedAttractions] = useState<Listing[]>([]);
  const [featuredHotels, setFeaturedHotels] = useState<Listing[]>([]);
  const [events, setEvents] = useState<Event[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    const fetchData = async () => {
      const attractions = await supabaseService.getListings(ListingType.ATTRACTION, true);
      const hotels = await supabaseService.getListings(ListingType.HOTEL, true);
      const evs = await supabaseService.getEvents();
      setFeaturedAttractions(attractions);
      setFeaturedHotels(hotels);
      setEvents(evs);
      setTimeout(() => setIsLoaded(true), 100);
    };
    fetchData();
  }, []);

  const categories = [
    { name: t('attractions'), icon: Castle, path: '/attractions', color: 'from-indigo-500 to-indigo-600', bgColor: 'bg-indigo-50' },
    { name: t('hotels'), icon: Hotel, path: '/hotels', color: 'from-amber-500 to-amber-600', bgColor: 'bg-amber-50' },
    { name: t('restaurants'), icon: Utensils, path: '/restaurants', color: 'from-emerald-500 to-emerald-600', bgColor: 'bg-emerald-50' },
    { name: t('events'), icon: Calendar, path: '/events', color: 'from-rose-500 to-rose-600', bgColor: 'bg-rose-50' },
  ];

  return (
    <div className="pb-20 pt-20">
      {/* Hero Section - Matching the design */}
      <section className="relative min-h-screen flex items-center justify-center bg-white">
        {/* Simple Clean Background */}
        <div className="absolute inset-0">
          <div className="absolute inset-0 bg-gradient-to-b from-white to-slate-50" />
        </div>
        
        <div className="max-w-4xl mx-auto px-4 text-center relative z-10">
          <div className={`transition-all duration-1000 transform ${
            isLoaded ? 'translate-y-0 opacity-100' : 'translate-y-10 opacity-0'
          }`}>
            {/* Main Title */}
            <h1 className="text-5xl md:text-6xl font-bold text-slate-900 mb-6 leading-tight">
              Find your<span className="text-amber-600"> stay</span>
            </h1>
            
            <p className="text-xl text-slate-600 mb-12 max-w-2xl mx-auto leading-relaxed">
              Search low prices on hotels, homes and much more...
            </p>

            {/* Search Bar - Matching the design */}
            <div className="bg-white rounded-2xl shadow-xl border border-slate-200 p-2 mb-8">
              <div className="flex flex-col lg:flex-row gap-2">
                {/* Location Input */}
                <div className="flex-1 relative">
                  <div className="flex items-center px-4 py-3 hover:bg-slate-50 rounded-xl transition-colors cursor-pointer">
                    <div className="text-left">
                      <div className="text-xs text-slate-500 font-medium">Location</div>
                      <input
                        type="text"
                        placeholder="Where are you going?"
                        className="text-slate-900 font-medium bg-transparent outline-none w-full"
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                      />
                    </div>
                  </div>
                </div>
                
                {/* Divider */}
                <div className="hidden lg:block w-px bg-slate-200" />
                
                {/* Check In */}
                <div className="flex-1 relative">
                  <div className="flex items-center px-4 py-3 hover:bg-slate-50 rounded-xl transition-colors cursor-pointer">
                    <div className="text-left">
                      <div className="text-xs text-slate-500 font-medium">Check in</div>
                      <div className="text-slate-900 font-medium">Add dates</div>
                    </div>
                  </div>
                </div>
                
                {/* Divider */}
                <div className="hidden lg:block w-px bg-slate-200" />
                
                {/* Check Out */}
                <div className="flex-1 relative">
                  <div className="flex items-center px-4 py-3 hover:bg-slate-50 rounded-xl transition-colors cursor-pointer">
                    <div className="text-left">
                      <div className="text-xs text-slate-500 font-medium">Check out</div>
                      <div className="text-slate-900 font-medium">Add dates</div>
                    </div>
                  </div>
                </div>
                
                {/* Divider */}
                <div className="hidden lg:block w-px bg-slate-200" />
                
                {/* Guests */}
                <div className="flex-1 relative">
                  <div className="flex items-center px-4 py-3 hover:bg-slate-50 rounded-xl transition-colors cursor-pointer">
                    <div className="text-left">
                      <div className="text-xs text-slate-500 font-medium">Guests</div>
                      <div className="text-slate-900 font-medium">Add guests</div>
                    </div>
                  </div>
                </div>
                
                {/* Search Button */}
                <button className="bg-amber-600 hover:bg-amber-700 text-white px-8 py-3 rounded-xl font-semibold transition-all duration-300 flex items-center justify-center min-w-[120px]">
                  <Search className="h-5 w-5" />
                </button>
              </div>
            </div>
            
            {/* Popular Destinations */}
            <div className="text-left">
              <h3 className="text-lg font-semibold text-slate-900 mb-4">Popular destinations</h3>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                {[
                  { name: 'Gondar Castle', image: 'https://picsum.photos/id/1015/300/200' },
                  { name: 'Fasilides Bath', image: 'https://picsum.photos/id/1016/300/200' },
                  { name: 'Debre Berhan Selassie', image: 'https://picsum.photos/id/1018/300/200' },
                  { name: 'Simien Mountains', image: 'https://picsum.photos/id/1019/300/200' },
                ].map((dest, index) => (
                  <div key={index} className="group cursor-pointer">
                    <div className="relative overflow-hidden rounded-xl mb-2">
                      <img 
                        src={dest.image} 
                        alt={dest.name}
                        className="w-full h-32 object-cover group-hover:scale-110 transition-transform duration-500"
                      />
                    </div>
                    <p className="text-sm font-medium text-slate-900">{dest.name}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Featured Listings Section */}
      <section className="max-w-7xl mx-auto px-4 py-16">
        <div className="mb-12">
          <h2 className="text-3xl font-bold text-slate-900 mb-4">Featured Attractions</h2>
          <p className="text-slate-600">Explore the most popular destinations in Gondar</p>
        </div>
        
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8">
          {featuredAttractions.slice(0, 6).map(item => (
            <Card key={item.id} listing={item} />
          ))}
        </div>
        
        {featuredAttractions.length === 0 && (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8">
            <SkeletonCard count={6} />
          </div>
        )}
      </section>

      {/* Best Hotels Section */}
      <section className="max-w-7xl mx-auto px-4 py-16">
        <div className="mb-12">
          <h2 className="text-3xl font-bold text-slate-900 mb-4">Best Hotels</h2>
          <p className="text-slate-600">Comfortable stays with great reviews</p>
        </div>
        
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8">
          {featuredHotels.slice(0, 6).map(item => (
            <Card key={item.id} listing={item} />
          ))}
        </div>
        
        {featuredHotels.length === 0 && (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8">
            <SkeletonCard count={6} />
          </div>
        )}
      </section>

      {/* Interactive Map CTA */}
      <section className="max-w-7xl mx-auto px-4 py-16">
        <Link 
          to="/map"
          className="flex flex-col md:flex-row items-center bg-gradient-to-r from-slate-900 to-slate-800 rounded-3xl overflow-hidden hover:shadow-2xl transition-all duration-300 group"
        >
          <div className="w-full md:w-1/2 p-12 md:p-16 text-white">
            <h2 className="text-3xl font-bold mb-4">Interactive Map</h2>
            <p className="text-slate-300 mb-8 text-lg">
              Navigate Gondar like a local. Explore pins for all major attractions, find your nearest café, or check out event venues in real-time.
            </p>
            <div className="inline-flex items-center space-x-3 bg-amber-600 hover:bg-amber-700 px-8 py-4 rounded-xl font-bold text-lg transition-all duration-300 transform group-hover:scale-105">
              <span>Open Map</span>
              <ArrowRight className="h-5 w-5" />
            </div>
          </div>
          <div className="w-full md:w-1/2 h-64 md:h-auto relative">
             <img 
               src="https://picsum.photos/id/1014/800/600" 
               className="w-full h-full object-cover opacity-80 group-hover:opacity-100 transition-opacity duration-300" 
               alt="Gondar Map" 
             />
             <div className="absolute inset-0 flex items-center justify-center">
                <div className="p-6 bg-white rounded-full shadow-2xl group-hover:scale-110 transition-transform duration-300">
                  <MapIcon className="h-10 w-10 text-amber-600" />
                </div>
             </div>
          </div>
        </Link>
      </section>

      {/* Events Section */}
      <section className="max-w-7xl mx-auto px-4 py-16">
        <div className="mb-12">
          <h2 className="text-3xl font-bold text-slate-900 mb-4">Upcoming Events</h2>
          <p className="text-slate-600">Don't miss out on exciting events in Gondar</p>
        </div>
        
        {events.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {events.slice(0, 3).map(event => (
              <div key={event.id} className="bg-white rounded-2xl shadow-lg border border-slate-200 overflow-hidden hover:shadow-xl transition-shadow">
                <div className="h-48 bg-gradient-to-br from-amber-100 to-amber-200 flex items-center justify-center">
                  <Calendar className="h-12 w-12 text-amber-600" />
                </div>
                <div className="p-6">
                  <h3 className="text-xl font-bold text-slate-900 mb-2">{event.title}</h3>
                  <p className="text-slate-600 mb-4">{event.description}</p>
                  <div className="flex items-center text-amber-600 font-medium">
                    <span>{new Date(event.date).toLocaleDateString()}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="text-center py-12 bg-white rounded-2xl border border-slate-200">
            <Calendar className="h-16 w-16 text-slate-300 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-slate-700 mb-2">No upcoming events</h3>
            <p className="text-slate-500">Check back later for exciting events in Gondar</p>
          </div>
        )}
      </section>
    </div>
  );
};

export default Home;
