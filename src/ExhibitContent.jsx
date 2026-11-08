import React from 'react';
import { Cpu, Network, Building2, PanelsTopLeft } from 'lucide-react';

const covers = {
  ai: { label: 'AI', icon: Cpu }, systems: { label: 'UML', icon: Network },
  platform: { label: 'СӨХ', icon: Building2 }, design: { label: 'UX/UI', icon: PanelsTopLeft }
};

export function ExhibitCover({ item }) {
  const cover = covers[item.cover_style] || covers.systems;
  const Icon = cover.icon;
  return <span className={`exhibit-cover cover-${item.cover_style || 'systems'}`} aria-hidden="true">
    <span className="cover-grid"/><span className="cover-type">{item.collection || 'ОЮУТНЫ БҮТЭЭЛ'}</span>
    <Icon size={58} strokeWidth={1}/><strong>{cover.label}</strong><span className="cover-year">ISM / {item.year_created}</span>
  </span>;
}

export function ExhibitDetails({ item }) {
  return <>
    {item.award && <div className="exhibit-award">{item.award} · Бүтээлийн уралдаан 2026</div>}
    {item.original_title && <p className="exhibit-original">Бүрэн нэр: {item.original_title}</p>}
    {item.contributors?.length > 0 && <div className="exhibit-team"><h3>Багийн гишүүд</h3><ul>{item.contributors.map(name => <li key={name}>{name}</li>)}</ul></div>}
    {item.highlights?.length > 0 && <div className="exhibit-highlights"><h3>Бүтээлийн тухай</h3><ul>{item.highlights.map(detail => <li key={detail}>{detail}</li>)}</ul></div>}
    {item.image_caption && <p className="exhibit-caption">Зураг: {item.image_caption}</p>}
  </>;
}
