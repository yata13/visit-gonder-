/**
 * Database types for the Visit Gondar Supabase project.
 *
 * Hand-written from `supabase/migrations` + `supabase/legacy` (the live
 * project was unreachable on 2026-07-20). The shape mirrors the output of
 * `supabase gen types typescript`, so once the project is back you can
 * regenerate with `npm run gen:types` and drop the result straight in.
 */

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export interface Database {
  public: {
    Tables: {
      hotels: {
        Row: {
          id: string;
          name_en: string | null;
          name_am: string | null;
          description: string | null;
          location: string | null;
          contact: string | null;
          photos: string[] | null;
          price: number | null;
          star_ranking: number | null;
          publish_status: string | null;
          lat: number | null;
          lng: number | null;
          owner_id: string | null;
          created_at: string | null;
        };
        Insert: {
          id?: string;
          name_en?: string | null;
          name_am?: string | null;
          description?: string | null;
          location?: string | null;
          contact?: string | null;
          photos?: string[] | null;
          price?: number | null;
          star_ranking?: number | null;
          publish_status?: string | null;
          lat?: number | null;
          lng?: number | null;
          owner_id?: string | null;
          created_at?: string | null;
        };
        Update: {
          id?: string;
          name_en?: string | null;
          name_am?: string | null;
          description?: string | null;
          location?: string | null;
          contact?: string | null;
          photos?: string[] | null;
          price?: number | null;
          star_ranking?: number | null;
          publish_status?: string | null;
          lat?: number | null;
          lng?: number | null;
          owner_id?: string | null;
          created_at?: string | null;
        };
        Relationships: [];
      };
      guides: {
        Row: {
          id: string;
          name: string | null;
          initials: string | null;
          specialty: string | null;
          photo: string | null;
          languages: string[] | null;
          price: number | null;
          license_status: string | null;
          publish_status: string | null;
          contact: string | null;
          owner_id: string | null;
          created_at: string | null;
        };
        Insert: {
          id?: string;
          name?: string | null;
          initials?: string | null;
          specialty?: string | null;
          photo?: string | null;
          languages?: string[] | null;
          price?: number | null;
          license_status?: string | null;
          publish_status?: string | null;
          contact?: string | null;
          owner_id?: string | null;
          created_at?: string | null;
        };
        Update: {
          id?: string;
          name?: string | null;
          initials?: string | null;
          specialty?: string | null;
          photo?: string | null;
          languages?: string[] | null;
          price?: number | null;
          license_status?: string | null;
          publish_status?: string | null;
          contact?: string | null;
          owner_id?: string | null;
          created_at?: string | null;
        };
        Relationships: [];
      };
      sites: {
        Row: {
          id: string;
          name_en: string | null;
          name_am: string | null;
          description: string | null;
          info: string | null;
          location: string | null;
          photo: string | null;
          lat: number | null;
          lng: number | null;
          publish_status: string | null;
          created_at: string | null;
        };
        Insert: {
          id?: string;
          name_en?: string | null;
          name_am?: string | null;
          description?: string | null;
          info?: string | null;
          location?: string | null;
          photo?: string | null;
          lat?: number | null;
          lng?: number | null;
          publish_status?: string | null;
          created_at?: string | null;
        };
        Update: {
          id?: string;
          name_en?: string | null;
          name_am?: string | null;
          description?: string | null;
          info?: string | null;
          location?: string | null;
          photo?: string | null;
          lat?: number | null;
          lng?: number | null;
          publish_status?: string | null;
          created_at?: string | null;
        };
        Relationships: [];
      };
      places: {
        Row: {
          id: string;
          name_en: string;
          name_am: string | null;
          category: string | null;
          photo: string | null;
          info: string | null;
          description: string | null;
          lat: number | null;
          lng: number | null;
          publish_status: string | null;
          created_at: string | null;
        };
        Insert: {
          id?: string;
          name_en: string;
          name_am?: string | null;
          category?: string | null;
          photo?: string | null;
          info?: string | null;
          description?: string | null;
          lat?: number | null;
          lng?: number | null;
          publish_status?: string | null;
          created_at?: string | null;
        };
        Update: {
          id?: string;
          name_en?: string;
          name_am?: string | null;
          category?: string | null;
          photo?: string | null;
          info?: string | null;
          description?: string | null;
          lat?: number | null;
          lng?: number | null;
          publish_status?: string | null;
          created_at?: string | null;
        };
        Relationships: [];
      };
      events: {
        Row: {
          id: string;
          name: string | null;
          date: string | null;
          description: string | null;
          photo: string | null;
          category: string | null;
          includes_timket: boolean | null;
          publish_status: string | null;
          created_at: string | null;
        };
        Insert: {
          id?: string;
          name?: string | null;
          date?: string | null;
          description?: string | null;
          photo?: string | null;
          category?: string | null;
          includes_timket?: boolean | null;
          publish_status?: string | null;
          created_at?: string | null;
        };
        Update: {
          id?: string;
          name?: string | null;
          date?: string | null;
          description?: string | null;
          photo?: string | null;
          category?: string | null;
          includes_timket?: boolean | null;
          publish_status?: string | null;
          created_at?: string | null;
        };
        Relationships: [];
      };
      posts: {
        Row: {
          id: string;
          title: string;
          title_am: string | null;
          body: string | null;
          body_am: string | null;
          photo: string | null;
          category: string | null;
          publish_status: string | null;
          created_at: string | null;
        };
        Insert: {
          id?: string;
          title: string;
          title_am?: string | null;
          body?: string | null;
          body_am?: string | null;
          photo?: string | null;
          category?: string | null;
          publish_status?: string | null;
          created_at?: string | null;
        };
        Update: {
          id?: string;
          title?: string;
          title_am?: string | null;
          body?: string | null;
          body_am?: string | null;
          photo?: string | null;
          category?: string | null;
          publish_status?: string | null;
          created_at?: string | null;
        };
        Relationships: [];
      };
      notifications: {
        Row: {
          id: string;
          title: string | null;
          type: string | null;
          message: string | null;
          body: string | null;
          send_to_all: boolean | null;
          created_at: string | null;
        };
        Insert: {
          id?: string;
          title?: string | null;
          type?: string | null;
          message?: string | null;
          body?: string | null;
          send_to_all?: boolean | null;
          created_at?: string | null;
        };
        Update: {
          id?: string;
          title?: string | null;
          type?: string | null;
          message?: string | null;
          body?: string | null;
          send_to_all?: boolean | null;
          created_at?: string | null;
        };
        Relationships: [];
      };
      bookings: {
        Row: {
          id: string;
          item_type: string | null;
          item_id: string | null;
          item_name: string | null;
          customer_name: string | null;
          customer_contact: string | null;
          booking_date: string | null;
          check_in: string | null;
          check_out: string | null;
          guests: number | null;
          status: string | null;
          price: number | null;
          total_price: number | null;
          commission_rate: number | null;
          commission_amount: number | null;
          commission_earned: number | null;
          payment_status: string;
          deposit_amount: number | null;
          user_id: string | null;
          user_email: string | null;
          created_at: string | null;
        };
        Insert: {
          id?: string;
          item_type?: string | null;
          item_id?: string | null;
          item_name?: string | null;
          customer_name?: string | null;
          customer_contact?: string | null;
          booking_date?: string | null;
          check_in?: string | null;
          check_out?: string | null;
          guests?: number | null;
          status?: string | null;
          price?: number | null;
          total_price?: number | null;
          commission_rate?: number | null;
          commission_amount?: number | null;
          commission_earned?: number | null;
          payment_status?: string;
          deposit_amount?: number | null;
          user_id?: string | null;
          user_email?: string | null;
          created_at?: string | null;
        };
        Update: {
          id?: string;
          item_type?: string | null;
          item_id?: string | null;
          item_name?: string | null;
          customer_name?: string | null;
          customer_contact?: string | null;
          booking_date?: string | null;
          check_in?: string | null;
          check_out?: string | null;
          guests?: number | null;
          status?: string | null;
          price?: number | null;
          total_price?: number | null;
          commission_rate?: number | null;
          commission_amount?: number | null;
          commission_earned?: number | null;
          payment_status?: string;
          deposit_amount?: number | null;
          user_id?: string | null;
          user_email?: string | null;
          created_at?: string | null;
        };
        Relationships: [];
      };
      users: {
        Row: {
          id: string;
          full_name: string | null;
          language: string | null;
          country: string | null;
          phone: string | null;
          email: string | null;
          created_at: string | null;
        };
        Insert: {
          id: string;
          full_name?: string | null;
          language?: string | null;
          country?: string | null;
          phone?: string | null;
          email?: string | null;
          created_at?: string | null;
        };
        Update: {
          id?: string;
          full_name?: string | null;
          language?: string | null;
          country?: string | null;
          phone?: string | null;
          email?: string | null;
          created_at?: string | null;
        };
        Relationships: [];
      };
      user_roles: {
        Row: {
          user_id: string;
          role: string;
          created_at: string;
          created_by: string | null;
        };
        Insert: {
          user_id: string;
          role: string;
          created_at?: string;
          created_by?: string | null;
        };
        Update: {
          user_id?: string;
          role?: string;
          created_at?: string;
          created_by?: string | null;
        };
        Relationships: [];
      };
      ride_fares: {
        Row: {
          vehicle_type: string;
          base_fare: number;
          per_km: number;
          minimum: number;
          updated_at: string;
        };
        Insert: {
          vehicle_type: string;
          base_fare: number;
          per_km: number;
          minimum: number;
          updated_at?: string;
        };
        Update: {
          vehicle_type?: string;
          base_fare?: number;
          per_km?: number;
          minimum?: number;
          updated_at?: string;
        };
        Relationships: [];
      };
      drivers: {
        Row: {
          user_id: string;
          full_name: string;
          phone: string;
          vehicle_type: string;
          plate: string;
          vehicle_desc: string | null;
          photo: string | null;
          status: string;
          is_online: boolean;
          lat: number | null;
          lng: number | null;
          location_at: string | null;
          rating_sum: number;
          rating_count: number;
          rides_completed: number;
          created_at: string;
          approved_at: string | null;
        };
        Insert: {
          user_id: string;
          full_name: string;
          phone: string;
          vehicle_type: string;
          plate: string;
          vehicle_desc?: string | null;
          photo?: string | null;
          status?: string;
          is_online?: boolean;
          lat?: number | null;
          lng?: number | null;
          location_at?: string | null;
          rating_sum?: number;
          rating_count?: number;
          rides_completed?: number;
          created_at?: string;
          approved_at?: string | null;
        };
        Update: {
          user_id?: string;
          full_name?: string;
          phone?: string;
          vehicle_type?: string;
          plate?: string;
          vehicle_desc?: string | null;
          photo?: string | null;
          status?: string;
          is_online?: boolean;
          lat?: number | null;
          lng?: number | null;
          location_at?: string | null;
          rating_sum?: number;
          rating_count?: number;
          rides_completed?: number;
          created_at?: string;
          approved_at?: string | null;
        };
        Relationships: [];
      };
      rides: {
        Row: {
          id: string;
          rider_id: string;
          rider_name: string | null;
          rider_phone: string | null;
          vehicle_type: string;
          pickup_lat: number;
          pickup_lng: number;
          pickup_label: string | null;
          dropoff_lat: number;
          dropoff_lng: number;
          dropoff_label: string | null;
          distance_km: number;
          fare_estimate: number;
          status: string;
          driver_id: string | null;
          driver_name: string | null;
          driver_phone: string | null;
          vehicle_plate: string | null;
          vehicle_desc: string | null;
          driver_lat: number | null;
          driver_lng: number | null;
          driver_location_at: string | null;
          rider_rating: number | null;
          cancelled_by: string | null;
          cancel_reason: string | null;
          created_at: string;
          accepted_at: string | null;
          arrived_at: string | null;
          started_at: string | null;
          completed_at: string | null;
          cancelled_at: string | null;
        };
        Insert: {
          id?: string;
          rider_id: string;
          rider_name?: string | null;
          rider_phone?: string | null;
          vehicle_type: string;
          pickup_lat: number;
          pickup_lng: number;
          pickup_label?: string | null;
          dropoff_lat: number;
          dropoff_lng: number;
          dropoff_label?: string | null;
          distance_km: number;
          fare_estimate: number;
          status?: string;
          driver_id?: string | null;
          driver_name?: string | null;
          driver_phone?: string | null;
          vehicle_plate?: string | null;
          vehicle_desc?: string | null;
          driver_lat?: number | null;
          driver_lng?: number | null;
          driver_location_at?: string | null;
          rider_rating?: number | null;
          cancelled_by?: string | null;
          cancel_reason?: string | null;
          created_at?: string;
          accepted_at?: string | null;
          arrived_at?: string | null;
          started_at?: string | null;
          completed_at?: string | null;
          cancelled_at?: string | null;
        };
        Update: {
          id?: string;
          rider_id?: string;
          rider_name?: string | null;
          rider_phone?: string | null;
          vehicle_type?: string;
          pickup_lat?: number;
          pickup_lng?: number;
          pickup_label?: string | null;
          dropoff_lat?: number;
          dropoff_lng?: number;
          dropoff_label?: string | null;
          distance_km?: number;
          fare_estimate?: number;
          status?: string;
          driver_id?: string | null;
          driver_name?: string | null;
          driver_phone?: string | null;
          vehicle_plate?: string | null;
          vehicle_desc?: string | null;
          driver_lat?: number | null;
          driver_lng?: number | null;
          driver_location_at?: string | null;
          rider_rating?: number | null;
          cancelled_by?: string | null;
          cancel_reason?: string | null;
          created_at?: string;
          accepted_at?: string | null;
          arrived_at?: string | null;
          started_at?: string | null;
          completed_at?: string | null;
          cancelled_at?: string | null;
        };
        Relationships: [];
      };
      partner_requests: {
        Row: {
          id: string;
          user_id: string;
          email: string | null;
          business_type: string;
          business_name: string;
          phone: string | null;
          message: string | null;
          status: string;
          created_at: string;
          handled_at: string | null;
          handled_by: string | null;
        };
        Insert: {
          id?: string;
          user_id?: string;
          email?: string | null;
          business_type: string;
          business_name: string;
          phone?: string | null;
          message?: string | null;
          status?: string;
          created_at?: string;
          handled_at?: string | null;
          handled_by?: string | null;
        };
        Update: {
          id?: string;
          user_id?: string;
          email?: string | null;
          business_type?: string;
          business_name?: string;
          phone?: string | null;
          message?: string | null;
          status?: string;
          created_at?: string;
          handled_at?: string | null;
          handled_by?: string | null;
        };
        Relationships: [];
      };
      user_tiers: {
        Row: {
          user_id: string;
          tier: string;
          premium_until: string | null;
          updated_at: string;
          updated_by: string | null;
        };
        Insert: {
          user_id: string;
          tier?: string;
          premium_until?: string | null;
          updated_at?: string;
          updated_by?: string | null;
        };
        Update: {
          user_id?: string;
          tier?: string;
          premium_until?: string | null;
          updated_at?: string;
          updated_by?: string | null;
        };
        Relationships: [];
      };
      premium_requests: {
        Row: {
          id: string;
          user_id: string;
          email: string | null;
          note: string | null;
          status: string;
          created_at: string;
          handled_at: string | null;
          handled_by: string | null;
        };
        Insert: {
          id?: string;
          user_id: string;
          email?: string | null;
          note?: string | null;
          status?: string;
          created_at?: string;
          handled_at?: string | null;
          handled_by?: string | null;
        };
        Update: {
          id?: string;
          user_id?: string;
          email?: string | null;
          note?: string | null;
          status?: string;
          created_at?: string;
          handled_at?: string | null;
          handled_by?: string | null;
        };
        Relationships: [];
      };
      ai_knowledge: {
        Row: {
          id: string;
          title: string;
          title_am: string | null;
          body: string | null;
          body_am: string | null;
          category: string | null;
          publish_status: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          title: string;
          title_am?: string | null;
          body?: string | null;
          body_am?: string | null;
          category?: string | null;
          publish_status?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          title?: string;
          title_am?: string | null;
          body?: string | null;
          body_am?: string | null;
          category?: string | null;
          publish_status?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      ai_questions: {
        Row: {
          id: string;
          user_id: string | null;
          mode: string;
          lang: string | null;
          question: string;
          answer: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id?: string | null;
          mode?: string;
          lang?: string | null;
          question: string;
          answer?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string | null;
          mode?: string;
          lang?: string | null;
          question?: string;
          answer?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      commission_rates: {
        Row: {
          target_type: string;
          rate: number;
          updated_at: string;
        };
        Insert: {
          target_type: string;
          rate: number;
          updated_at?: string;
        };
        Update: {
          target_type?: string;
          rate?: number;
          updated_at?: string;
        };
        Relationships: [];
      };
      commissions: {
        Row: {
          id: string;
          booking_id: string;
          target_type: string;
          target_id: string | null;
          total_amount: number;
          commission_rate: number;
          commission_amount: number;
          status: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          booking_id: string;
          target_type: string;
          target_id?: string | null;
          total_amount: number;
          commission_rate: number;
          commission_amount: number;
          status?: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          booking_id?: string;
          target_type?: string;
          target_id?: string | null;
          total_amount?: number;
          commission_rate?: number;
          commission_amount?: number;
          status?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      danger_zones: {
        Row: {
          id: string;
          name: string;
          description: string | null;
          severity: string | null;
          lat: number;
          lng: number;
          radius: number | null;
          is_active: boolean | null;
          created_at: string | null;
        };
        Insert: {
          id?: string;
          name: string;
          description?: string | null;
          severity?: string | null;
          lat: number;
          lng: number;
          radius?: number | null;
          is_active?: boolean | null;
          created_at?: string | null;
        };
        Update: {
          id?: string;
          name?: string;
          description?: string | null;
          severity?: string | null;
          lat?: number;
          lng?: number;
          radius?: number | null;
          is_active?: boolean | null;
          created_at?: string | null;
        };
        Relationships: [];
      };
      emergency_requests: {
        Row: {
          id: string;
          type: string | null;
          name: string | null;
          phone: string | null;
          message: string | null;
          location: string | null;
          status: string | null;
          lat: number | null;
          lng: number | null;
          email: string | null;
          user_id: string | null;
          created_at: string | null;
        };
        Insert: {
          id?: string;
          type?: string | null;
          name?: string | null;
          phone?: string | null;
          message?: string | null;
          location?: string | null;
          status?: string | null;
          lat?: number | null;
          lng?: number | null;
          email?: string | null;
          user_id?: string | null;
          created_at?: string | null;
        };
        Update: {
          id?: string;
          type?: string | null;
          name?: string | null;
          phone?: string | null;
          message?: string | null;
          location?: string | null;
          status?: string | null;
          lat?: number | null;
          lng?: number | null;
          email?: string | null;
          user_id?: string | null;
          created_at?: string | null;
        };
        Relationships: [];
      };
      availability: {
        Row: {
          id: string;
          business_type: string;
          business_id: string;
          day: string;
          capacity: number;
          booked: number;
          is_closed: boolean;
          note: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          business_type: string;
          business_id: string;
          day: string;
          capacity?: number;
          booked?: number;
          is_closed?: boolean;
          note?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          business_type?: string;
          business_id?: string;
          day?: string;
          capacity?: number;
          booked?: number;
          is_closed?: boolean;
          note?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      deposits: {
        Row: {
          id: string;
          booking_id: string;
          amount: number;
          currency: string;
          chapa_tx_ref: string | null;
          status: string;
          checkout_url: string | null;
          raw: Json | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          booking_id: string;
          amount: number;
          currency?: string;
          chapa_tx_ref?: string | null;
          status?: string;
          checkout_url?: string | null;
          raw?: Json | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          booking_id?: string;
          amount?: number;
          currency?: string;
          chapa_tx_ref?: string | null;
          status?: string;
          checkout_url?: string | null;
          raw?: Json | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      passport_checkpoints: {
        Row: {
          id: string;
          name_en: string;
          name_am: string | null;
          description_en: string | null;
          description_am: string | null;
          photo: string | null;
          lat: number;
          lng: number;
          points: number;
          sort_order: number;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          name_en: string;
          name_am?: string | null;
          description_en?: string | null;
          description_am?: string | null;
          photo?: string | null;
          lat: number;
          lng: number;
          points?: number;
          sort_order?: number;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          name_en?: string;
          name_am?: string | null;
          description_en?: string | null;
          description_am?: string | null;
          photo?: string | null;
          lat?: number;
          lng?: number;
          points?: number;
          sort_order?: number;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      passport_checkpoint_secrets: {
        Row: {
          checkpoint_id: string;
          qr_token: string;
          rotated_at: string;
        };
        Insert: {
          checkpoint_id: string;
          qr_token?: string;
          rotated_at?: string;
        };
        Update: {
          checkpoint_id?: string;
          qr_token?: string;
          rotated_at?: string;
        };
        Relationships: [];
      };
      passport_stories: {
        Row: {
          id: string;
          checkpoint_id: string;
          title_en: string;
          title_am: string | null;
          body_en: string | null;
          body_am: string | null;
          media_url: string | null;
          sort_order: number;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          checkpoint_id: string;
          title_en: string;
          title_am?: string | null;
          body_en?: string | null;
          body_am?: string | null;
          media_url?: string | null;
          sort_order?: number;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          checkpoint_id?: string;
          title_en?: string;
          title_am?: string | null;
          body_en?: string | null;
          body_am?: string | null;
          media_url?: string | null;
          sort_order?: number;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      passport_trivia: {
        Row: {
          id: string;
          checkpoint_id: string;
          question_en: string;
          question_am: string | null;
          options_en: string[];
          options_am: string[];
          correct_index: number;
          points: number;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          checkpoint_id: string;
          question_en: string;
          question_am?: string | null;
          options_en?: string[];
          options_am?: string[];
          correct_index?: number;
          points?: number;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          checkpoint_id?: string;
          question_en?: string;
          question_am?: string | null;
          options_en?: string[];
          options_am?: string[];
          correct_index?: number;
          points?: number;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      passport_checkins: {
        Row: {
          id: string;
          user_id: string;
          checkpoint_id: string;
          method: string;
          checked_in_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          checkpoint_id: string;
          method?: string;
          checked_in_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          checkpoint_id?: string;
          method?: string;
          checked_in_at?: string;
        };
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: {
      ride_quote: {
        Args: {
          p_vehicle_type: string;
          p_pickup_lat: number;
          p_pickup_lng: number;
          p_dropoff_lat: number;
          p_dropoff_lng: number;
        };
        Returns: { distance_km: number; fare: number }[];
      };
      admin_set_driver_status: {
        Args: { p_user_id: string; p_status: string };
        Returns: Database["public"]["Tables"]["drivers"]["Row"];
      };
      admin_cancel_ride: {
        Args: { p_ride_id: string; p_reason?: string | null };
        Returns: Database["public"]["Tables"]["rides"]["Row"];
      };
      owns_business: {
        Args: { p_type: string; p_id: string };
        Returns: boolean;
      };
      partner_set_booking_status: {
        Args: { p_booking_id: string; p_status: string };
        Returns: Database["public"]["Tables"]["bookings"]["Row"];
      };
      partner_update_hotel: {
        Args: {
          p_hotel_id: string;
          p_description: string | null;
          p_contact: string | null;
          p_location: string | null;
          p_price: number;
          p_photos: string[] | null;
        };
        Returns: Database["public"]["Tables"]["hotels"]["Row"];
      };
      partner_update_guide: {
        Args: {
          p_guide_id: string;
          p_specialty: string | null;
          p_contact: string | null;
          p_price: number;
          p_languages: string[] | null;
          p_photo: string | null;
        };
        Returns: Database["public"]["Tables"]["guides"]["Row"];
      };
      admin_link_owner: {
        Args: { p_type: string; p_business_id: string; p_email: string };
        Returns: string;
      };
      admin_unlink_owner: {
        Args: { p_type: string; p_business_id: string };
        Returns: undefined;
      };
      is_admin: {
        Args: Record<PropertyKey, never>;
        Returns: boolean;
      };
      is_editor: {
        Args: Record<PropertyKey, never>;
        Returns: boolean;
      };
      is_premium: {
        Args: Record<PropertyKey, never>;
        Returns: boolean;
      };
      admin_set_user_tier: {
        Args: { p_user_id: string; p_tier: string; p_until?: string | null };
        Returns: undefined;
      };
      passport_check_in: {
        Args: { p_qr_token: string };
        Returns: Json;
      };
      admin_rotate_checkpoint_qr: {
        Args: { p_checkpoint_id: string };
        Returns: string;
      };
      admin_grant_role: {
        Args: { p_user_id: string; p_role: string };
        Returns: undefined;
      };
      admin_set_booking_status: {
        Args: { p_booking_id: string; p_status: string };
        Returns: undefined;
      };
      admin_set_emergency_status: {
        Args: { p_id: string; p_status: string };
        Returns: undefined;
      };
      admin_delete_emergency: {
        Args: { p_id: string };
        Returns: undefined;
      };
      admin_revoke_role: {
        Args: { p_user_id: string };
        Returns: undefined;
      };
      cancel_my_booking: {
        Args: { p_booking_id: string };
        Returns: Json;
      };
      create_booking: {
        Args: {
          p_item_type: string;
          p_item_id: string;
          p_check_in: string;
          p_check_out: string;
          p_guests: number;
          p_customer_name: string;
          p_customer_contact: string;
        };
        Returns: Json;
      };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}

export type Tables<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Row"];
export type TablesInsert<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Insert"];
export type TablesUpdate<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Update"];

/** The publish workflow used across all content tables. */
export const PUBLISH_STATUSES = ["draft", "pending", "published"] as const;
export type PublishStatus = (typeof PUBLISH_STATUSES)[number];
