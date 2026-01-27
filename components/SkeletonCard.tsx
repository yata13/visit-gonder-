import React from 'react';

interface SkeletonCardProps {
  count?: number;
}

const SkeletonCard: React.FC<SkeletonCardProps> = ({ count = 1 }) => {
  return (
    <>
      {Array.from({ length: count }).map((_, index) => (
        <div key={index} className="bg-white rounded-2xl shadow-lg border border-slate-200 overflow-hidden animate-pulse">
          <div className="h-56 bg-slate-200" />
          <div className="p-6">
            <div className="flex justify-between items-start mb-3">
              <div className="h-6 bg-slate-200 rounded w-3/4" />
              <div className="h-6 bg-slate-200 rounded w-12" />
            </div>
            <div className="space-y-2 mb-4">
              <div className="h-4 bg-slate-200 rounded" />
              <div className="h-4 bg-slate-200 rounded w-5/6" />
            </div>
            <div className="h-4 bg-slate-200 rounded w-1/2 mb-5" />
            <div className="flex gap-2">
              <div className="h-12 bg-slate-200 rounded-xl flex-1" />
              <div className="h-12 bg-slate-200 rounded-xl w-12" />
              <div className="h-12 bg-slate-200 rounded-xl w-12" />
            </div>
          </div>
        </div>
      ))}
    </>
  );
};

export default SkeletonCard;
