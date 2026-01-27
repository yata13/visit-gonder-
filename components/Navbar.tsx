
import React, { useState, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useLanguage } from './LanguageContext';
import { Menu, X, Globe, MapPin, Search, ChevronDown } from 'lucide-react';

const Navbar: React.FC = () => {
  const { language, setLanguage, t } = useLanguage();
  const [isOpen, setIsOpen] = useState(false);
  const [isScrolled, setIsScrolled] = useState(false);
  const location = useLocation();

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 20);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const navLinks = [
    { name: t('attractions'), path: '/attractions' },
    { name: t('hotels'), path: '/hotels' },
    { name: t('restaurants'), path: '/restaurants' },
    { name: t('events'), path: '/events' },
    { name: t('timket_guide'), path: '/timket' },
    { name: t('map'), path: '/map' },
  ];

  const isActive = (path: string) => location.pathname === path;

  return (
    <nav className={`fixed top-0 left-0 right-0 z-[1000] transition-all duration-300 ${
      isScrolled 
        ? 'bg-white/95 backdrop-blur-md shadow-lg border-b border-slate-200/50' 
        : 'bg-white border-b border-slate-200'
    }`}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-18">
          <div className="flex items-center">
            <Link to="/" className="flex items-center space-x-3 group">
              <div className="relative">
                <MapPin className="h-9 w-9 text-amber-600 group-hover:text-amber-700 transition-colors" />
                <div className="absolute -bottom-1 -right-1 w-3 h-3 bg-amber-500 rounded-full animate-pulse" />
              </div>
              <div>
                <span className="text-2xl font-bold tracking-tight text-slate-800 group-hover:text-amber-700 transition-colors">Visit Gondar</span>
                <div className="text-xs text-slate-500 font-medium">Digital Tourism Hub</div>
              </div>
            </Link>
          </div>

          {/* Desktop Links */}
          <div className="hidden lg:flex items-center space-x-8">
            <div className="flex items-center space-x-6">
              {navLinks.map((link) => (
                <Link
                  key={link.path}
                  to={link.path}
                  className={`relative text-sm font-semibold transition-all duration-300 hover:text-amber-600 group ${
                    isActive(link.path) ? 'text-amber-600' : 'text-slate-700'
                  }`}
                >
                  {link.name}
                  <span className={`absolute -bottom-1 left-0 w-full h-0.5 bg-gradient-to-r from-amber-500 to-amber-600 transform transition-transform duration-300 ${
                    isActive(link.path) ? 'scale-x-100' : 'scale-x-0 group-hover:scale-x-100'
                  }`} />
                </Link>
              ))}
            </div>
            
            <div className="flex items-center space-x-4 pl-6 border-l border-slate-200">
              <button
                onClick={() => setLanguage(language === 'en' ? 'am' : 'en')}
                className="flex items-center space-x-2 px-4 py-2 rounded-xl bg-gradient-to-r from-amber-50 to-amber-100 border border-amber-200 text-sm font-semibold text-amber-700 hover:from-amber-100 hover:to-amber-200 transition-all duration-300 group"
              >
                <Globe className="h-4 w-4 group-hover:rotate-180 transition-transform duration-500" />
                <span>{language === 'en' ? 'አማርኛ' : 'English'}</span>
                <ChevronDown className="h-3 w-3" />
              </button>
            </div>
          </div>

          {/* Mobile menu button */}
          <div className="flex lg:hidden items-center space-x-3">
            <button
              onClick={() => setLanguage(language === 'en' ? 'am' : 'en')}
              className="flex items-center space-x-1 px-3 py-2 rounded-lg bg-amber-50 border border-amber-200 text-sm font-medium text-amber-700 hover:bg-amber-100 transition-colors"
            >
              <Globe className="h-4 w-4" />
              <span className="hidden xs:inline">{language === 'en' ? 'አም' : 'En'}</span>
            </button>
            <button
              onClick={() => setIsOpen(!isOpen)}
              className="relative p-2 rounded-lg text-slate-600 hover:text-amber-600 hover:bg-amber-50 transition-all duration-300"
            >
              <div className={`transition-all duration-300 ${isOpen ? 'rotate-90' : ''}`}>
                {isOpen ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
              </div>
            </button>
          </div>
        </div>
      </div>

      {/* Mobile Links */}
      <div className={`lg:hidden transition-all duration-300 overflow-hidden ${
        isOpen ? 'max-h-96 bg-white/95 backdrop-blur-md border-b border-slate-200/50 shadow-lg' : 'max-h-0'
      }`}>
        <div className="px-4 pt-4 pb-6 space-y-2">
          {navLinks.map((link, index) => (
            <Link
              key={link.path}
              to={link.path}
              onClick={() => setIsOpen(false)}
              className={`block px-4 py-3 rounded-xl text-base font-semibold transition-all duration-300 transform hover:translate-x-2 ${
                isActive(link.path) 
                  ? 'bg-gradient-to-r from-amber-50 to-amber-100 text-amber-700 border-l-4 border-amber-600' 
                  : 'text-slate-700 hover:bg-slate-50'
              }`}
              style={{ animationDelay: `${index * 50}ms` }}
            >
              {link.name}
            </Link>
          ))}
        </div>
      </div>
    </nav>
  );
};

export default Navbar;
