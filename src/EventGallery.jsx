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
  useEffect(() => {
    if (!supabase || !event?.id) return;
    supabase.from('event_photos').select('*').eq('event_id', event.id).order('created_at')
      .then(({ data, error: loadError }) => {
        if (loadError) setError(loadError.message);
        else setPhotos(data || []);
      });
  }, [event?.id]);

  async function addPhoto(e) {
    e.preventDefault();
    if (!supabase || !file || !isAdmin) return;
    const form = e.currentTarget;
    if (file.size > 8 * 1024 * 1024 || !['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
      setError('JPG, PNG эсвэл WebP зураг 8 MB хүртэл оруулна уу.'); return;
    }
    setBusy(true); setError('');
    const { data: auth } = await supabase.auth.getUser();
    const path = `${auth.user.id}/${Date.now()}-${file.name.replace(/[^a-zA-Z0-9._-]/g, '-')}`;
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
    const { error: removeError } = await supabase.from('event_photos').delete().eq('id', photo.id);
    if (removeError) { setError(removeError.message); return; }
    setPhotos((current) => current.filter((item) => item.id !== photo.id));
    const marker = '/storage/v1/object/public/museum-media/';
    const objectPath = photo.image_url.includes(marker) ? decodeURIComponent(photo.image_url.split(marker)[1]) : null;
    if (objectPath) {
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

  return <div className="overlay gallery-overlay" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
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
        {event.article.photos?.length > 0 && <div className="event-article-photos"><h3>Зургийн цомог</h3>{event.article.photos.map(photo => <figure key={photo.image_url}><img src={photo.image_url} alt={photo.caption} loading="lazy"/><figcaption>{photo.caption}</figcaption></figure>)}</div>}
        <p className="event-source">Эх сурвалж: {event.article.source_url ? <a href={event.article.source_url} target="_blank" rel="noreferrer">{event.article.source}</a> : event.article.source} · {event.date.slice(0,4)} оны мэдээ</p>
      </article>}
      {error && <p className="gallery-error">{error}</p>}
      {photos.length ? <div className="gallery-grid">{photos.map((photo) => <figure key={photo.id}>
        <img src={photo.image_url} alt={photo.caption || `${event.title} арга хэмжээний зураг`} />
        <figcaption><span>{photo.caption || 'ISM-ийн дурсамж'}</span>{isAdmin && <span className="gallery-actions"><button onClick={() => editCaption(photo)} aria-label="Тайлбар засах">Засах</button><button onClick={() => removePhoto(photo)} aria-label="Зураг устгах"><Trash2 size={15}/></button></span>}</figcaption>
      </figure>)}</div> : !event.article && <div className="gallery-empty"><ImagePlus/><h3>Энэ цомогт зураг хараахан алга</h3><p>Арга хэмжээний дурсамжийг энд цуглуулна.</p></div>}
      {isAdmin && event.id && <form className="gallery-upload" onSubmit={addPhoto}>
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
  useEffect(() => {
    if (!supabase) return;
    let query = supabase.from('time_capsules').select('*').order('created_at', { ascending: false }).limit(12);
    query.then(({ data, error: loadError }) => { if (loadError) setError(loadError.message); else setMessages(data || []); });
  }, [isAdmin]);
  async function review(message, approved) {
    const { error: updateError } = await supabase.from('time_capsules').update({ approved }).eq('id', message.id);
    if (updateError) setError(updateError.message);
    else setMessages((current) => current.map((item) => item.id === message.id ? { ...item, approved } : item));
  }
  async function remove(message) {
    if (!window.confirm('Энэ захиаг бүрмөсөн устгах уу?')) return;
    const { error: deleteError } = await supabase.from('time_capsules').delete().eq('id', message.id);
    if (deleteError) setError(deleteError.message);
    else setMessages((current) => current.filter((item) => item.id !== message.id));
  }
  if (!supabase) return <div className="capsule-wall"><p className="capsule-empty">Захиануудыг Supabase тохируулсны дараа нийтэд харуулна.</p></div>;
  return <div className="capsule-wall">
    {error && <p className="gallery-error">{error}</p>}
    {messages.map((message) => <article className="capsule-note" key={message.id}>
      <span className="capsule-note-mark">“</span><p>{message.message}</p>
      <footer><span>{message.author_name || 'Нууц нэр'}</span><time>{new Date(message.created_at).toLocaleDateString('mn-MN')}</time></footer>
      {isAdmin && <div className="capsule-review"><span>{message.approved ? 'Нийтэлсэн' : 'Хяналтад'}</span>
        <button onClick={() => review(message, !message.approved)}>{message.approved ? 'Нуух' : 'Нийтлэх'}</button>
        <button onClick={() => remove(message)}>Устгах</button></div>}
    </article>)}
    {!messages.length && <p className="capsule-empty">Эхний захиа музейн цагийн капсулыг нээнэ.</p>}
  </div>;
}
