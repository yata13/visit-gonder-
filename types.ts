
export enum ListingType {
  ATTRACTION = 'attraction',
  HOTEL = 'hotel',
  RESTAURANT = 'restaurant'
}

export enum Status {
  DRAFT = 'draft',
  PUBLISHED = 'published'
}

export interface Listing {
  id: string;
  type: ListingType;
  name_en: string;
  name_am: string;
  desc_en: string;
  desc_am: string;
  details_en: string;
  details_am: string;
  lat: number;
  lng: number;
  address_en: string;
  address_am: string;
  area: string;
  featured: boolean;
  status: Status;
  phone?: string;
  whatsapp?: string;
  website_url?: string;
  booking_url?: string;
  price_level?: string; // $, $$, $$$
  amenities?: string[];
  category?: string; // e.g., castle, church, cafe, resort
  image_url: string;
  created_at: string;
}

export interface Event {
  id: string;
  title_en: string;
  title_am: string;
  desc_en: string;
  desc_am: string;
  start_date: string;
  end_date: string;
  lat: number;
  lng: number;
  location_name_en: string;
  location_name_am: string;
  featured: boolean;
  image_url: string;
}

export type Language = 'en' | 'am';

export interface i18nContent {
  [key: string]: {
    en: string;
    am: string;
  };
}
