
import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { Listing, ListingType } from '../types';
import { useLanguage } from './LanguageContext';
import { MapPin, Phone, Info, Star, Heart, ExternalLink } from 'lucide-react';

interface CardProps {
  listing: Listing;
}

const Card: React.FC<CardProps> = ({ listing }) => {
  const { language, t } = useLanguage();
  const [isLiked, setIsLiked] = useState(false);
  const [isImageLoaded, setIsImageLoaded] = useState(false);
  const name = language === 'en' ? listing.name_en : listing.name_am;
  const desc = language === 'en' ? listing.desc_en : listing.desc_am;

  return (
    <div className="bg-white rounded-2xl shadow-lg border border-slate-200 overflow-hidden hover:shadow-2xl transition-all duration-300 group transform hover:-translate-y-1">
      <div className="relative h-56 overflow-hidden bg-slate-100">
        {!isImageLoaded && (
          <div className="absolute inset-0 bg-gradient-to-br from-slate-200 to-slate-300 animate-pulse" />
        )}
        <img
          src={listing.image_url}
          alt={name}
          className={`w-full h-full object-cover group-hover:scale-110 transition-transform duration-700 ${isImageLoaded ? 'opacity-100' : 'opacity-0'}`}
          onLoad={() => setIsImageLoaded(true)}
        />
        {listing.category && (
          <span className="absolute top-4 left-4 bg-white/95 backdrop-blur-sm px-3 py-1.5 rounded-full text-xs font-bold text-amber-700 uppercase tracking-wider shadow-lg">
            {listing.category}
          </span>
        )}
        {listing.featured && (
          <span className="absolute top-4 right-4 bg-gradient-to-r from-amber-500 to-amber-600 text-white px-3 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider shadow-lg flex items-center gap-1">
            <Star className="h-3 w-3" />
            Featured
          </span>
        )}
        <button
          onClick={() => setIsLiked(!isLiked)}
          className="absolute bottom-4 right-4 bg-white/95 backdrop-blur-sm p-2 rounded-full shadow-lg hover:bg-white transition-all hover:scale-110"
        >
          <Heart className={`h-4 w-4 ${isLiked ? 'fill-red-500 text-red-500' : 'text-slate-600'}`} />
        </button>
      </div>
      <div className="p-6">
        <div className="flex justify-between items-start mb-3">
          <h3 className="text-xl font-bold text-slate-800 line-clamp-1 group-hover:text-amber-700 transition-colors">{name}</h3>
          {listing.price_level && (
            <span className="bg-amber-50 text-amber-700 px-2 py-1 rounded-lg text-sm font-semibold">
              {listing.price_level}
            </span>
          )}
        </div>
        <p className="text-slate-600 text-sm mb-4 line-clamp-2 leading-relaxed">{desc}</p>
        
        <div className="flex items-center text-sm text-slate-500 mb-5">
          <MapPin className="h-4 w-4 mr-2 text-amber-600" />
          <span>{language === 'en' ? listing.area : listing.address_am}</span>
        </div>

        <div className="flex gap-2">
          <Link
            to={`/details/${listing.id}`}
            className="flex-1 bg-gradient-to-r from-amber-600 to-amber-700 hover:from-amber-700 hover:to-amber-800 text-white text-center py-3 rounded-xl text-sm font-semibold transition-all duration-300 flex items-center justify-center gap-2 shadow-lg hover:shadow-xl transform hover:scale-105"
          >
            <Info className="h-4 w-4" />
            {t('details')}
          </Link>
          <a
            href={`https://www.google.com/maps/dir/?api=1&destination=${listing.lat},${listing.lng}`}
            target="_blank"
            rel="noopener noreferrer"
            className="bg-slate-100 hover:bg-slate-200 text-slate-700 p-3 rounded-xl transition-all duration-300 hover:scale-105 group"
          >
            <MapPin className="h-4 w-4 group-hover:text-amber-600" />
          </a>
          {listing.phone && (
            <a
              href={`tel:${listing.phone}`}
              className="bg-slate-100 hover:bg-slate-200 text-slate-700 p-3 rounded-xl transition-all duration-300 hover:scale-105 group"
            >
              <Phone className="h-4 w-4 group-hover:text-green-600" />
            </a>
          )}
        </div>
      </div>
    </div>
  );
};

export default Card;
