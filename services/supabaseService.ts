
import { MOCK_LISTINGS, MOCK_EVENTS } from '../constants';
import { Listing, ListingType, Event, Status } from '../types';

class SupabaseService {
  private listings: Listing[] = [...MOCK_LISTINGS];
  private events: Event[] = [...MOCK_EVENTS];

  async getListings(type?: ListingType, featuredOnly: boolean = false): Promise<Listing[]> {
    let result = [...this.listings];
    if (type) {
      result = result.filter(l => l.type === type);
    }
    if (featuredOnly) {
      result = result.filter(l => l.featured);
    }
    // Public view only sees published
    return result.filter(l => l.status === Status.PUBLISHED || featuredOnly);
  }

  async getAllListings(): Promise<Listing[]> {
    return [...this.listings];
  }

  async getListingById(id: string): Promise<Listing | undefined> {
    return this.listings.find(l => l.id === id);
  }

  async getEvents(): Promise<Event[]> {
    return [...this.events];
  }

  // Admin CRUD operations
  async saveListing(listing: Partial<Listing>): Promise<Listing> {
    if (listing.id) {
      const index = this.listings.findIndex(l => l.id === listing.id);
      if (index !== -1) {
        this.listings[index] = { ...this.listings[index], ...listing } as Listing;
        return this.listings[index];
      }
    }
    const newListing = {
      ...listing,
      id: Math.random().toString(36).substr(2, 9),
      created_at: new Date().toISOString(),
      status: listing.status || Status.DRAFT
    } as Listing;
    this.listings.push(newListing);
    return newListing;
  }

  async deleteListing(id: string): Promise<void> {
    this.listings = this.listings.filter(l => l.id !== id);
  }

  async saveEvent(event: Partial<Event>): Promise<Event> {
    if (event.id) {
      const index = this.events.findIndex(e => e.id === event.id);
      if (index !== -1) {
        this.events[index] = { ...this.events[index], ...event } as Event;
        return this.events[index];
      }
    }
    const newEvent = {
      ...event,
      id: Math.random().toString(36).substr(2, 9),
    } as Event;
    this.events.push(newEvent);
    return newEvent;
  }

  async deleteEvent(id: string): Promise<void> {
    this.events = this.events.filter(e => e.id !== id);
  }
}

export const supabaseService = new SupabaseService();
