
import React, { useState, useEffect } from 'react';
import { useLanguage } from '../components/LanguageContext';
import { Listing, ListingType } from '../types';
import { supabaseService } from '../services/supabaseService';
import Card from '../components/Card';
import LoadingSpinner from '../components/LoadingSpinner';
import SkeletonCard from '../components/SkeletonCard';
import { SlidersHorizontal, Search as SearchIcon, MapPin, Filter, Grid, List } from 'lucide-react';

interface ListingListProps {
  type: ListingType;
  titleKey: string;
}

const ListingList: React.FC<ListingListProps> = ({ type, titleKey }) => {
  const { t } = useLanguage();
  const [listings, setListings] = useState<Listing[]>([]);
  const [filtered, setFiltered] = useState<Listing[]>([]);
  const [search, setSearch] = useState('');
  const [areaFilter, setAreaFilter] = useState('All');
  const [isLoading, setIsLoading] = useState(true);
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid');

  useEffect(() => {
    const fetchData = async () => {
      setIsLoading(true);
      try {
        const data = await supabaseService.getListings(type);
        setListings(data);
        setFiltered(data);
      } catch (error) {
        console.error('Error fetching listings:', error);
      } finally {
        setTimeout(() => setIsLoading(false), 500); // Add small delay for better UX
      }
    };
    fetchData();
  }, [type]);

  useEffect(() => {
    let result = listings.filter(l => 
      l.name_en.toLowerCase().includes(search.toLowerCase()) ||
      l.name_am.includes(search)
    );
    if (areaFilter !== 'All') {
      result = result.filter(l => l.area === areaFilter);
    }
    setFiltered(result);
  }, [search, areaFilter, listings]);

  const areas = ['All', ...new Set(listings.map(l => l.area))];

  return (
    <div className="max-w-7xl mx-auto px-4 py-12">
      {/* Header */}
      <div className="mb-12">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between mb-4">
          <div>
            <h1 className="text-4xl md:text-5xl font-extrabold text-slate-900 mb-2">{t(titleKey)}</h1>
            <p className="text-slate-600 text-lg">Discover the best {type}s Gondar has to offer.</p>
          </div>
          
          {/* View Mode Toggle */}
          <div className="flex items-center space-x-2 mt-4 md:mt-0">
            <button
              onClick={() => setViewMode('grid')}
              className={`p-2 rounded-lg transition-colors ${
                viewMode === 'grid' ? 'bg-amber-100 text-amber-700' : 'text-slate-400 hover:text-slate-600'
              }`}
            >
              <Grid className="h-5 w-5" />
            </button>
            <button
              onClick={() => setViewMode('list')}
              className={`p-2 rounded-lg transition-colors ${
                viewMode === 'list' ? 'bg-amber-100 text-amber-700' : 'text-slate-400 hover:text-slate-600'
              }`}
            >
              <List className="h-5 w-5" />
            </button>
          </div>
        </div>
        
        {/* Stats */}
        <div className="flex items-center space-x-6 text-sm text-slate-500">
          <span className="flex items-center">
            <MapPin className="h-4 w-4 mr-1 text-amber-600" />
            {filtered.length} of {listings.length} places
          </span>
          {search && (
            <span className="flex items-center">
              <Filter className="h-4 w-4 mr-1" />
              Filtered by "{search}"
            </span>
          )}
        </div>
      </div>

      {/* Search and Filters */}
      <div className="bg-white rounded-2xl shadow-lg border border-slate-200 p-6 mb-12">
        <div className="flex flex-col lg:flex-row gap-6">
          <div className="relative flex-1">
            <input
              type="text"
              placeholder={t('search_placeholder')}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full py-4 pl-12 pr-4 rounded-xl border border-slate-200 focus:ring-2 focus:ring-amber-500 outline-none text-lg transition-all duration-300 focus:border-amber-500"
            />
            <SearchIcon className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-slate-400" />
          </div>
          
          <div className="flex items-center space-x-3 overflow-x-auto pb-2 lg:pb-0">
            <SlidersHorizontal className="h-5 w-5 text-slate-400 shrink-0" />
            <span className="text-sm font-medium text-slate-600 whitespace-nowrap">Areas:</span>
            {areas.map(area => (
              <button
                key={area}
                onClick={() => setAreaFilter(area)}
                className={`px-4 py-2 rounded-full text-sm font-semibold whitespace-nowrap transition-all duration-300 transform hover:scale-105 ${
                  areaFilter === area 
                    ? 'bg-gradient-to-r from-amber-600 to-amber-700 text-white shadow-lg' 
                    : 'bg-white border border-slate-200 text-slate-600 hover:border-amber-300 hover:bg-amber-50'
                }`}
              >
                {area}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Content */}
      {isLoading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8">
          <SkeletonCard count={6} />
        </div>
      ) : filtered.length > 0 ? (
        <div className={`grid gap-8 ${
          viewMode === 'grid' 
            ? 'grid-cols-1 sm:grid-cols-2 lg:grid-cols-3' 
            : 'grid-cols-1'
        }`}>
          {filtered.map(item => (
            <div key={item.id} className={viewMode === 'list' ? 'max-w-4xl mx-auto w-full' : ''}>
              <Card listing={item} />
            </div>
          ))}
        </div>
      ) : (
        <div className="text-center py-20 bg-white rounded-3xl border border-dashed border-slate-300">
          <div className="w-20 h-20 bg-amber-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <SearchIcon className="h-8 w-8 text-amber-600" />
          </div>
          <h3 className="text-xl font-semibold text-slate-700 mb-2">No listings found</h3>
          <p className="text-slate-500 mb-6">Try adjusting your search or filters to find what you're looking for.</p>
          <button
            onClick={() => {
              setSearch('');
              setAreaFilter('All');
            }}
            className="px-6 py-3 bg-amber-600 hover:bg-amber-700 text-white rounded-xl font-semibold transition-colors"
          >
            Clear Filters
          </button>
        </div>
      )}
    </div>
  );
};

export default ListingList;
