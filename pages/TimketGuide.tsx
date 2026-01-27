
import React from 'react';
import { useLanguage } from '../components/LanguageContext';
import { ShieldCheck, Info, Calendar, MapPin, Camera, Coffee, Waves } from 'lucide-react';

const TimketGuide: React.FC = () => {
  const { t } = useLanguage();

  const sections = [
    {
      title: "What is Timket?",
      icon: Info,
      content: "Timket is the Ethiopian Orthodox Tewahedo Church celebration of Epiphany, commemorating the baptism of Jesus in the Jordan River. Gondar is the world's premier destination for this festival, centering around the historic Fasilides Bath."
    },
    {
      title: "The Schedule (Three Days)",
      icon: Calendar,
      content: "• Day 1: Ketera (Timket Eve, Jan 18) - Grand processions of Tabots (Arks) from 40+ churches to Fasilides Bath. Thousands camp out for an overnight vigil.\n• Day 2: Timket Day (Jan 19) - Before dawn, priests bless the water. At sunrise, water is sprinkled on the faithful, and young men leap into the pool in a joyous expression of faith.\n• Day 3: Kana Ze Galila (Jan 20) - Celebration of the Miracle at Cana and the final return of the Tabots."
    },
    {
      title: "Key Rituals",
      icon: Waves,
      content: "The iconic moment occurs at sunrise on January 19. As sunlight filters through the banyan trees, the chief priest blesses the pool. The ensuing 'symbolic renewal of baptism' is a powerful, jubilant event that was inscribed on UNESCO's list of Intangible Cultural Heritage in 2019."
    }
  ];

  const tips = [
    { icon: Coffee, title: "Stay Hydrated", text: "Massive crowds pack the bath area. Carry water and snacks as movement is difficult once celebrations begin." },
    { icon: ShieldCheck, title: "Modest Dress", text: "Wear white if possible, covering shoulders and knees. Expect to get slightly wet during the sprinkling!" },
    { icon: Camera, title: "Photography", text: "Climb ancient walls or nearby trees for the best vantage points. Use a zoom lens to capture the priests' ceremonial umbrellas." },
  ];

  return (
    <div className="pb-20">
      <div className="relative h-[500px] flex items-center justify-center text-center text-white px-4">
        <img 
          src="https://images.unsplash.com/photo-1548013146-72479768bbaa?auto=format&fit=crop&w=1920&q=80" 
          alt="Timket Celebration" 
          className="absolute inset-0 w-full h-full object-cover brightness-[0.4]"
        />
        <div className="relative z-10 max-w-4xl">
          <span className="bg-amber-600 px-4 py-1 rounded-full text-xs font-bold uppercase tracking-widest mb-4 inline-block">UNESCO Heritage</span>
          <h1 className="text-5xl md:text-7xl font-extrabold mb-6">{t('timket_guide')}</h1>
          <p className="text-xl md:text-2xl text-white/90 leading-relaxed font-light">Witness the most spectacular religious festival in sub-Saharan Africa.</p>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-4 mt-16">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-12 mb-20">
          {sections.map((sec, idx) => (
            <div key={idx} className={idx === 1 ? "md:col-span-2 bg-white border border-slate-200 rounded-3xl p-8 shadow-sm" : ""}>
              <div className="flex items-center gap-3 mb-6">
                <div className="p-3 bg-amber-100 text-amber-600 rounded-xl">
                  <sec.icon className="h-6 w-6" />
                </div>
                <h2 className="text-2xl font-bold text-slate-800">{sec.title}</h2>
              </div>
              <p className="text-slate-600 leading-relaxed text-lg whitespace-pre-line">
                {sec.content}
              </p>
            </div>
          ))}
        </div>

        <div className="bg-slate-900 rounded-[3rem] p-10 md:p-16 text-white shadow-2xl">
          <h2 className="text-3xl font-bold mb-12 text-center">Traveler Tips for Timket</h2>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-12">
            {tips.map((tip, idx) => (
              <div key={idx} className="flex flex-col items-center text-center">
                <div className="p-5 bg-white/10 rounded-2xl mb-6 backdrop-blur-sm border border-white/10">
                  <tip.icon className="h-10 w-10 text-amber-400" />
                </div>
                <h3 className="font-bold text-xl mb-3 text-amber-100">{tip.title}</h3>
                <p className="text-slate-400 text-sm leading-relaxed">{tip.text}</p>
              </div>
            ))}
          </div>
        </div>

        <div className="mt-20 text-center bg-white rounded-[3rem] p-12 border border-slate-200 shadow-sm">
          <h2 className="text-3xl font-bold text-slate-800 mb-6">Plan Your Timket Stay</h2>
          <p className="text-slate-600 mb-10 max-w-2xl mx-auto text-lg">Hotels book up as early as 6 months in advance. We recommend staying at least 3 days to experience the full ritual from Ketera to the return of the Arks.</p>
          <div className="flex flex-wrap justify-center gap-6">
            <button className="bg-amber-600 text-white px-10 py-4 rounded-2xl font-bold hover:bg-amber-700 transition-all shadow-lg shadow-amber-600/20">Find Available Hotels</button>
            <button className="bg-white border-2 border-amber-600 text-amber-600 px-10 py-4 rounded-2xl font-bold hover:bg-amber-50 transition-all">Download Ceremony Schedule</button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default TimketGuide;
