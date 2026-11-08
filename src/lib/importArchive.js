import { exhibits, teachers, events } from '../data.js';

// Runs with the signed-in administrator's JWT. Never uses a service-role key.
// Insert missing records only, so a retry preserves existing editorial changes.
export async function importArchive(client, userId, onProgress = () => {}) {
  const check = result => { if (result.error) throw result.error; return result.data; };
  if (!check(await client.rpc('is_admin'))) throw new Error('Архив оруулахад админ эрх шаардлагатай.');
  const media = new Map();
  async function upload(url) {
    if (!url || !url.startsWith('/')) return url || null;
    if (media.has(url)) return media.get(url);
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Зураг олдсонгүй: ${url}`);
    const blob = await response.blob();
    const path = `${userId}/archive${url}`;
    check(await client.storage.from('museum-media').upload(path, blob, { upsert: true, contentType: blob.type }));
    const publicUrl = client.storage.from('museum-media').getPublicUrl(path).data.publicUrl;
    media.set(url, publicUrl);
    return publicUrl;
  }
  const counts = { teachers: 0, events: 0, exhibits: 0, photos: 0 };
  for (const [table, source, key] of [['teachers', teachers, 'name'], ['events', events, 'title'], ['exhibits', exhibits, 'title']]) {
    const existing = check(await client.from(table).select('*')) || [];
    for (const item of source) {
      onProgress(`${table}: ${item[key]}`);
      let row = existing.find(record => record[key].trim().toLocaleLowerCase() === item[key].trim().toLocaleLowerCase());
      if (!row) {
        const payload = table === 'teachers'
          ? { name: item.name, position: item.position, courses: item.courses.split(' · ').filter(Boolean), bio: item.bio, photo_url: await upload(item.photo_url) }
          : table === 'events'
            ? { title: item.title, event_date: item.date.replaceAll('.', '-'), description: item.description, event_type: item.type, article: item.article || null, cover_image_url: await upload(item.image_url) }
            : { title: item.title, description: item.description, category: item.category, technology_stack: item.technology_stack || [], year_created: item.year_created, creator_id: userId, creator_name: item.creator, collection: item.collection, archive_details: Object.fromEntries(['original_title','contributors','award','featured','cover_style','highlights','topics','source_url','source_label','image_caption'].filter(key => item[key] !== undefined).map(key => [key,item[key]])), status: 'published', image_url: await upload(item.image_url), demo_url: item.demo_url || null, github_url: item.github_url || null };
        row = check(await client.from(table).insert(payload).select().single());
        existing.push(row); counts[table]++;
      } else if (table === 'teachers') {
        const patch = {};
        if (!row.bio && item.bio) patch.bio = item.bio;
        if (!row.courses?.length && item.courses) patch.courses = item.courses.split(' · ').filter(Boolean);
        if (row.photo_url === item.photo_url) patch.photo_url = await upload(item.photo_url);
        if (Object.keys(patch).length) check(await client.from(table).update(patch).eq('id', row.id));
      } else {
        const column = table === 'events' ? 'cover_image_url' : 'image_url';
        if (item.image_url && row[column] === item.image_url) {
          check(await client.from(table).update({ [column]: await upload(item.image_url) }).eq('id', row.id));
        }
      }
      if (table === 'events') {
        const photos = check(await client.from('event_photos').select('*').eq('event_id', row.id)) || [];
        const sourcePhotos = [{ image_url: item.image_url, caption: item.title }, ...(item.article?.photos || [])];
        for (const photo of sourcePhotos) {
          const existingPhoto = photos.find(p => p.caption === photo.caption);
          if (existingPhoto) {
            if (existingPhoto.image_url === photo.image_url) check(await client.from('event_photos').update({ image_url: await upload(photo.image_url) }).eq('id', existingPhoto.id));
            continue;
          }
          check(await client.from('event_photos').insert({ event_id: row.id, image_url: await upload(photo.image_url), caption: photo.caption }));
          counts.photos++;
        }
      }
    }
  }
  return counts;
}
