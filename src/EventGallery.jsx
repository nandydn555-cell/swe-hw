import React, { useEffect, useState } from 'react';
import { ImagePlus, Trash2, X } from 'lucide-react';
import { supabase } from './lib/supabase';

const BUCKET = 'museum-media';

export function EventGallery({ event, onClose, isAdmin = false }) {
  const [photos, setPhotos] = useState([]);
  const [caption, setCaption] = useState('');
  const [file, setFile] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  async function perform(action) {
    try { await action(); } catch (failure) { setError(failure.message || 'Хүсэлт амжилтгүй боллоо.'); } finally { setBusy(false); }
  }
  useEffect(() => {
    if (!supabase || !event?.id) return;
    supabase.from('event_photos').select('*').eq('event_id', event.id).order('created_at')
      .then(({ data, error: loadError }) => {
        if (loadError) setError(loadError.message);
        else setPhotos(data || []);
      }).catch(failure => setError(failure.message));
  }, [event?.id]);

  async function addPhoto(e) {
    e.preventDefault();
    if (!supabase || !file || !isAdmin) return;
    const form = e.currentTarget;
    if (file.size > 8 * 1024 * 1024 || !['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
      setError('JPG, PNG эсвэл WebP зураг 8 MB хүртэл оруулна уу.'); return;
    }
    setBusy(true); setError('');
    const { data: auth, error: authError } = await supabase.auth.getUser();
    if (authError || !auth.user) throw authError || new Error('Дахин нэвтэрнэ үү.');
    const path = `${auth.user.id}/gallery/${event.id}/${Date.now()}-${file.name.replace(/[^a-zA-Z0-9._-]/g, '-')}`;
    const { error: uploadError } = await supabase.storage.from(BUCKET).upload(path, file);
    if (uploadError) { setError(uploadError.message); setBusy(false); return; }
    const image_url = supabase.storage.from(BUCKET).getPublicUrl(path).data.publicUrl;
    const { data, error: insertError } = await supabase.from('event_photos')
      .insert({ event_id: event.id, image_url, caption: caption.trim() || null }).select().single();
    if (insertError) setError(insertError.message);
    else { setPhotos((current) => [...current, data]); setCaption(''); setFile(null); form.reset(); }
    setBusy(false);
  }

  async function removePhoto(photo) {
    if (!window.confirm('Энэ зургийг цомгоос устгах уу?')) return;
    const { data, error: removeError } = await supabase.from('event_photos').delete().eq('id', photo.id).select('id');
    if (removeError) { setError(removeError.message); return; }
    if (!data?.length) throw new Error('Устгах эрхгүй эсвэл зураг олдсонгүй.');
    setPhotos((current) => current.filter((item) => item.id !== photo.id));
    const marker = '/storage/v1/object/public/museum-media/';
    const objectPath = photo.image_url.includes(marker) ? decodeURIComponent(photo.image_url.split(marker)[1]) : null;
    // Imported archive images can also be covers for events and exhibits.
    // Only individually uploaded gallery files belong exclusively to this row.
    if (objectPath?.includes(`/gallery/${event.id}/`)) {
      const { error: storageError } = await supabase.storage.from(BUCKET).remove([objectPath]);
      if (storageError) setError(`Зургийн бүртгэл устсан ч файлыг устгаж чадсангүй: ${storageError.message}`);
    }
  }

  async function editCaption(photo) {
    const nextCaption = window.prompt('Зургийн тайлбар', photo.caption || '');
    if (nextCaption === null) return;
    const { data, error: updateError } = await supabase.from('event_photos')
      .update({ caption: nextCaption.trim() || null }).eq('id', photo.id).select().single();
    if (updateError) setError(updateError.message);
    else setPhotos((current) => current.map((item) => item.id === photo.id ? data : item));
  }

  return <div className="overlay gallery-overlay" role="dialog" aria-modal="true" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
    <section className="gallery-modal" aria-label={`${event.title} зургийн цомог`}>
      <button className="close" onClick={onClose} aria-label="Хаах"><X /></button>
      <div className="eyebrow muted">ISM ARCHIVE / {event.article ? 'ҮЙЛ ЯВДЛЫН АРХИВ' : 'ЗУРГИЙН ЦОМОГ'}</div>
      <h2>{event.title}</h2><p className="gallery-description">{event.description}</p>
      {event.article && <article className="event-article">
        <time>{event.date}</time>
        <img src={event.image_url} alt={event.title}/>
        {event.article.paragraphs.map(paragraph => <p key={paragraph}>{paragraph}</p>)}
        {event.article.updates?.length > 0 && <><h3>{event.article.heading || 'Бакалавр 2.0 хөтөлбөрийн шинэчлэл'}</h3>
        <ol className={event.article.heading ? 'event-results' : undefined}>{event.article.updates.map(update => <li key={update.title}><h4>{update.title}</h4><p>{update.text}</p></li>)}</ol></>}
        {event.article.closing?.map(paragraph => <p key={paragraph}>{paragraph}</p>)}
        {!event.id && event.article.photos?.length > 0 && <div className="event-article-photos"><h3>Зургийн цомог</h3>{event.article.photos.map(photo => <figure key={photo.image_url}><img src={photo.image_url} alt={photo.caption} loading="lazy"/><figcaption>{photo.caption}</figcaption></figure>)}</div>}
        <p className="event-source">Эх сурвалж: {event.article.source_url ? <a href={event.article.source_url} target="_blank" rel="noreferrer">{event.article.source}</a> : event.article.source} · {event.date.slice(0,4)} оны мэдээ</p>
      </article>}
      {error && <p className="gallery-error">{error}</p>}
      {photos.length ? <div className="gallery-grid">{photos.map((photo) => <figure key={photo.id}>
        <img src={photo.image_url} alt={photo.caption || `${event.title} арга хэмжээний зураг`} />
        <figcaption><span>{photo.caption || 'ISM-ийн дурсамж'}</span>{isAdmin && <span className="gallery-actions"><button onClick={() => void perform(() => editCaption(photo))} aria-label="Тайлбар засах">Засах</button><button onClick={() => void perform(() => removePhoto(photo))} aria-label="Зураг устгах"><Trash2 size={15}/></button></span>}</figcaption>
      </figure>)}</div> : !event.article && <div className="gallery-empty"><ImagePlus/><h3>Энэ цомогт зураг хараахан алга</h3><p>Арга хэмжээний дурсамжийг энд цуглуулна.</p></div>}
      {isAdmin && event.id && <form className="gallery-upload" onSubmit={e => void perform(() => addPhoto(e))}>
        <label>Зураг<input type="file" accept="image/jpeg,image/png,image/webp" required onChange={(e) => setFile(e.target.files?.[0] || null)} /></label>
        <label>Тайлбар<input value={caption} onChange={(e) => setCaption(e.target.value)} placeholder="Энэ мөчийг тайлбарлаарай" /></label>
        <button className="primary" disabled={busy || !file}>{busy ? 'Оруулж байна…' : 'Цомогт нэмэх'} <ImagePlus size={15}/></button>
      </form>}
    </section>
  </div>;
}

export function CapsuleWall({ isAdmin = false }) {
  const [messages, setMessages] = useState([]);
  const [error, setError] = useState('');
  async function perform(action) { try { await action(); } catch (failure) { setError(failure.message); } }
  useEffect(() => {
    if (!supabase) return;
    let query = supabase.from('time_capsules').select('*').order('created_at', { ascending: false });
    if (!isAdmin) query = query.eq('approved', true).limit(12);
    query.then(({ data, error: loadError }) => { if (loadError) setError(loadError.message); else setMessages(data || []); }).catch(failure => setError(failure.message));
  }, [isAdmin]);
  async function review(message, approved) {
    const { error: updateError } = await supabase.from('time_capsules').update({ approved }).eq('id', message.id).select('id').single();
    if (updateError) setError(updateError.message);
    else setMessages((current) => current.map((item) => item.id === message.id ? { ...item, approved } : item));
  }
  async function remove(message) {
    if (!window.confirm('Энэ захиаг бүрмөсөн устгах уу?')) return;
    const { data, error: deleteError } = await supabase.from('time_capsules').delete().eq('id', message.id).select('id');
    if (deleteError) setError(deleteError.message);
    else if (!data?.length) setError('Устгах эрхгүй эсвэл захиа олдсонгүй.');
    else setMessages((current) => current.filter((item) => item.id !== message.id));
  }
  if (!supabase) return <div className="capsule-wall"><p className="capsule-empty">Захиануудыг Supabase тохируулсны дараа нийтэд харуулна.</p></div>;
  return <div className="capsule-wall">
    {error && <p className="gallery-error">{error}</p>}
    {messages.map((message) => <article className="capsule-note" key={message.id}>
      <span className="capsule-note-mark">“</span><p>{message.message}</p>
      <footer><span>{message.author_name || 'Нууц нэр'}</span><time>{new Date(message.created_at).toLocaleDateString('mn-MN')}</time></footer>
      {isAdmin && <div className="capsule-review"><span>{message.approved ? 'Нийтэлсэн' : 'Хяналтад'}</span>
        <button onClick={() => void perform(() => review(message, !message.approved))}>{message.approved ? 'Нуух' : 'Нийтлэх'}</button>
        <button onClick={() => void perform(() => remove(message))}>Устгах</button></div>}
    </article>)}
    {!messages.length && <p className="capsule-empty">Эхний захиа музейн цагийн капсулыг нээнэ.</p>}
  </div>;
}
