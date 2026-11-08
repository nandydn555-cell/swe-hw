const competitionSource = 'https://www.ufe.edu.mn/widgetDetail/1850';
const competition = {
  category: 'Технологи', year_created: 2026, collection: 'Уралдааны бүтээл',
  image_url: '/events/projects-2026-cover.jpg', image_caption: '2026 оны бүтээлийн уралдааны зураг',
  technology_stack: [], source_url: competitionSource, source_label: 'СЭЗИС · Уралдааны тайлан',
  reference_only: true, status: 'published'
};
const research = {
  category: 'Судалгаа', collection: 'Дипломын ажил', year_created: 2026,
  reference_only: true, status: 'published', source_label: 'СЭЗИС · Бүтээлийн сан'
};

export const exhibits = [
  { ...competition, id: 'archive-waffle-2026', title: 'Пирамид', creator: 'Waffle баг',
    contributors: ['Б.Тамир · 4-р курс', 'Б.Энхжин · 3-р курс', 'Г.Энхмэнд · 3-р курс'],
    award: '🥇 1-р байр', featured: true,
    description: '2026 оны 3 сарын 26-нд болсон оюутны бүтээлийн уралдаанд 13 багаас тэргүүн байр эзэлсэн Waffle багийн бүтээл.',
    highlights: ['МСМТ-ийн 3 оюутны баг', 'Бүтээлийн уралдаан · 4С танхим', 'Ерөнхий ивээн тэтгэгч · М банк'],
    topics: ['Оюутны төсөл', 'Багийн бүтээл'] },
  { ...competition, id: 'archive-bit-2026', title: 'Just a bit?', creator: 'BIT баг',
    contributors: ['Н.Мөнхпүрэв · IO институт · 2-р курс'], award: '🥈 2-р байр',
    description: 'Оюутны 2026 оны бүтээлийн уралдааны дэд байрт шалгарсан BIT багийн бүтээл. Бүтээгч нь IO институтын 2-р курсын оюутан Н.Мөнхпүрэв.',
    highlights: ['2026.03.26 · Бүтээлийн уралдаан', '50 оюутан, 13 баг оролцсон'], topics: ['Оюутны төсөл'] },
  { ...competition, id: 'archive-mongol-mind-2026', title: 'Mongol mind', creator: 'Mongol mind баг',
    contributors: ['А.Угтах-Эрин · 2-р курс', 'Б.Цогт · 2-р курс', 'Ч.Тамир · 2-р курс'], award: '🥉 3-р байр',
    image_url: '/events/projects-2026-gallery.jpg',
    description: 'МСМТ-ийн 2-р курсын оюутнуудын хамтарсан бүтээл. 2026 оны бүтээлийн уралдаанд гуравдугаар байр эзэлж, ивээн тэтгэгчийн шагнал хүртсэн.',
    highlights: ['2-р курсын 3 оюутны баг', '2026.03.26 · Бүтээлийн уралдаан'], topics: ['Оюутны төсөл', 'Багийн бүтээл'] },
  { ...research, id: 'archive-ai-proctor-2026', title: 'Хиймэл оюунд суурилсан онлайн шалгалтын хяналтын систем',
    creator: 'Гандүүрэн, Билгээ', cover_style: 'ai',
    description: 'Онлайн шалгалтын явцад зөрчилтэй байж болзошгүй үйлдлийг илрүүлж, багшийн нягтлалд шилжүүлэх туршилтын систем. Компьютерын хараа, аудио шинжилгээ, хөтчийн үйлдлийг нэгтгэн судалсан.',
    technology_stack: ['Next.js', 'FastAPI', 'SQLite', 'WebSocket', 'MediaPipe', 'YOLOv8'], topics: ['Хиймэл оюун', 'Цахим сургалт'],
    highlights: ['8 төрлийн зөрчил илрүүлэх загвар', 'Эцсийн шийдвэрийг багш гаргана', 'Дипломын төслийн туршилтын хэрэгжүүлэлт'],
    source_url: 'https://www.repository.ufe.edu.mn/xmlui/handle/8524/4870' },
  { ...research, id: 'archive-uml-2026', title: 'Хиймэл оюун ухаанд суурилан UML диаграмм боловсруулах нь',
    creator: 'Долгорням, Ану', cover_style: 'systems', technology_stack: [], topics: ['UML', 'Хиймэл оюун', 'Системийн шинжилгээ'],
    description: 'Текстээр бичсэн шаардлагаас UML диаграмм үүсгэх боломжийг судалсан дипломын ажил. Диаграмм үүсгэгч хэрэгслүүдийг харьцуулж, системийн шаардлага болон туршилтын загварын чиглэлийг боловсруулсан.',
    highlights: ['Class, sequence, use case зэрэг диаграммын төрөл', 'Design Science Research Methodology', 'Шаардлагаас диаграмм үүсгэх шийдэл'],
    source_url: 'https://www.repository.ufe.edu.mn/xmlui/handle/8524/4691' },
  { ...research, id: 'archive-soh-2026', title: 'СӨХ-ийн нэгдсэн платформ',
    creator: 'Батсүмбэрэл, Энэрэлт', cover_style: 'platform', technology_stack: [], topics: ['Системийн шинжилгээ', 'Дижитал шилжилт'],
    description: 'Сууц өмчлөгчдийн холбооны өдөр тутмын үйл ажиллагааг цахимжуулах нэгдсэн платформын системийн шинжилгээ, зохиомжийг боловсруулахад чиглэсэн дипломын төсөл.',
    highlights: ['СӨХ-ийн үйл ажиллагааны цахимжилт', 'Нэгдсэн платформын шинжилгээ, зохиомж'],
    source_url: 'https://repository.ufe.edu.mn/xmlui/handle/8524/4674' },
  { ...research, id: 'archive-ux-2025', title: 'Цахим худалдааны UX/UI ба худалдан авах зан төлөв',
    original_title: 'Монголын цахим худалдааны платформуудын UX/UI дизайн нь хэрэглэгчийн худалдан авах зан төлөвт хэрхэн нөлөөлж буй судалгаа',
    creator: 'Төмөрбаатар, Алтанзул', year_created: 2025, cover_style: 'design', technology_stack: [], topics: ['UX/UI', 'Цахим худалдаа', 'Хэрэглэгчийн судалгаа'],
    description: 'Монголын цахим худалдааны платформын интерфейс, хэрэглэхэд хялбар байдал нь худалдан авалтын шийдвэрт хэрхэн нөлөөлөхийг судалсан ажил. Санал асуулга болон өрсөлдөөнт шинжилгээг хослуулсан.',
    highlights: ['Чанарын болон тоон судалгаа', 'Навигаци, хурд, төлбөрийн урсгал', 'Хэрэглэгч төвтэй сайжруулалтын санал'],
    source_url: 'https://repository.ufe.edu.mn/xmlui/handle/8524/4451' }
];

export function mergeExhibits(records) {
  const key = title => title.trim().toLocaleLowerCase();
  const merged = new Map(exhibits.map(item => [key(item.title), item]));
  for (const record of records) {
    // Private submissions must remain separate from the published reference.
    const recordKey = record.status === 'published' ? key(record.title) : record.id;
    const existing = merged.get(recordKey);
    merged.set(recordKey, { ...existing, ...record, reference_only: false,
      image_url: record.image_url || existing?.image_url || '',
      technology_stack: record.technology_stack || [] });
  }
  return [...merged.values()];
}

export function filterExhibits(items, { category = 'Бүгд', collection = 'Бүгд', query = '', sort = 'featured' } = {}) {
  const search = query.trim().toLocaleLowerCase();
  return items.filter(item => (item.status === 'published' || !item.status)
    && (category === 'Бүгд' || item.category === category)
    && (collection === 'Бүгд' || (item.collection || 'Оюутны бүтээл') === collection)
    && [item.title, item.original_title, item.description, item.creator, item.award, item.category, item.year_created,
      ...(item.technology_stack || []), ...(item.topics || []), ...(item.contributors || [])].join(' ').toLocaleLowerCase().includes(search))
    .sort((a, b) => sort === 'oldest' ? a.year_created - b.year_created
      : sort === 'newest' ? b.year_created - a.year_created
      : Number(Boolean(b.featured)) - Number(Boolean(a.featured)) || b.year_created - a.year_created);
}
