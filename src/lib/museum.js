export const statusLabel = status => ({ pending: 'ХЯНАЛТАД', published: 'НИЙТЛЭГДСЭН', rejected: 'ТАТГАЛЗСАН' }[status] || 'ХЯНАЛТАД');
export const listText = value => Array.isArray(value) ? value.join(', ') : value || '';
export const textList = value => Array.isArray(value) ? value : String(value || '').split(',').map(s => s.trim()).filter(Boolean);
export const canManageExhibit = (item, user, isAdmin) => Boolean(user && !item.reference_only && (isAdmin || item.creator_id === user.id));

export function exhibitDraft(item) {
  return { ...item, technology_stack: listText(item.technology_stack), courses: listText(item.courses), event_date: item.event_date || '', description: item.description || '', bio: item.bio || '', position: item.position || '' };
}

export function hydrateExhibits(records, archive = []) {
  return records.map(record => {
    const original = archive.find(item => item.title.trim().toLocaleLowerCase() === record.title.trim().toLocaleLowerCase());
    return { ...original, ...record.archive_details, ...record, reference_only: false, creator: record.creator_name || original?.creator || record.profiles?.display_name || 'ISM бүтээгч', creator_avatar: record.profiles?.avatar_url || '', creator_bio: record.profiles?.bio || '', technology_stack: record.technology_stack || [] };
  });
}

export function hydrateTeachers(records, archive = []) {
  return records.map((record, i) => ({ ...record, source_url: archive.find(t => t.name === record.name)?.source_url, courses: textList(record.courses).join(' · '), initials: record.name.split('.').at(-1).trim()[0], color: ['mint', 'peach', 'lavender'][i % 3] }));
}

export function hydrateEvents(records, archive = []) {
  return records.map(record => {
    const original = archive.find(item => item.title.trim().toLocaleLowerCase() === record.title.trim().toLocaleLowerCase());
    return { ...original, ...record, article: record.article || original?.article, date: record.event_date.replaceAll('-', '.'), type: record.event_type || original?.type || 'Арга хэмжээ', image_url: record.cover_image_url || '' };
  }).sort((a, b) => b.date.localeCompare(a.date));
}

export function validateExhibit(form) {
  if (!form.title?.trim() || !form.description?.trim()) throw new Error('Бүтээлийн нэр, тайлбарыг бөглөнө үү.');
  const year = Number(form.year_created);
  if (!Number.isInteger(year) || year < 1900 || year > new Date().getFullYear() + 2) throw new Error('Бүтээсэн оныг зөв оруулна уу.');
  for (const field of ['image_url', 'demo_url', 'github_url']) {
    if (!form[field]) continue;
    let url;
    try { url = new URL(form[field], globalThis.location?.origin || 'http://localhost'); } catch { throw new Error('Холбоосын хаягийг зөв оруулна уу.'); }
    if (!['https:', 'http:'].includes(url.protocol)) throw new Error('Зөвхөн http эсвэл https холбоос ашиглана уу.');
  }
}
