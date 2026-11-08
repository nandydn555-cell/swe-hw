# ISM Digital Museum

Мэдээллийн системийн менежментийн тэнхимийн түүх, багш, арга хэмжээ, оюутны бүтээлийг хадгалж танилцуулах интерактив веб апп.

- Demo: https://swe-hw-9f89.vercel.app/
- Эх код: https://github.com/nandydn555-cell/swe-hw
- Frontend: React 18, JavaScript, Vite, Lucide.
- Backend: Supabase Auth, PostgreSQL, Storage, Row Level Security.
- [ERD, wireframe, 5–7 минутын demo](docs/architecture-and-demo.md)
- [Шалгалтын үр дүн](docs/supabase-verification.md)
- [Агуулгын эх сурвалж](docs/content-sources.md)

## Локал ажиллуулах

```bash
npm ci
cp .env.example .env.local
npm run dev
```

PowerShell дээр `Copy-Item .env.example .env.local` ашиглана. `.env.local`:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-publishable-or-anon-key
```

Зөвхөн publishable/anon key ашиглана. Service role, database password, access token-ийг frontend эсвэл Git-д хадгалахгүй. `.env.local` Git-ээс хасагдсан.

Supabase тохируулсан үед жагсаалтууд серверээс ирнэ. Сервер хоосон байхад локал архив нэмж харуулахгүй; устгасан мөр refresh хийхэд эргэж гарахгүй. Тохиргоогүй үед зөвхөн интерфэйсийн demo архив ажиллана; бүртгэл, upload, байнгын хадгалалтад Supabase шаардлагатай.

## Сервер тохируулах

SQL файлуудыг Supabase Dashboard → SQL Editor дээр `postgres` эрхээр ажиллуулна. Эдгээр нь SQL Editor-ийн скриптүүд; `supabase db push` бүх файлыг автоматаар ажиллуулахгүй.

**Одоо байгаа төсөл:** `supabase/complete-existing-project.sql`-ийг бүхэлд нь ажиллуулна. Үндсэн хүснэгтүүд өмнө нь үүссэн байх ёстой. Байгаа account, редакторын мэдээллийг хадгалж, профайл, category FK, эрх, Storage, архивын дутуу талбар/мөрийг нөхнө.

**Шинэ төсөл:**

1. `supabase/schema.sql`.
2. Аппаар өөрийн account-ийг бүртгүүлж, шаардлагатай бол имэйлээ баталгаажуулна.
3. Доорх алхмаар тэр account-д админ эрх олгоно.
4. `supabase/seed-complete-archive.sql`.
5. `supabase/test-access.sql`, дараа нь `supabase/verify-setup.sql`.

### Эхний админ

Доорх имэйлийг **өөрийн бүртгэлтэй имэйлээр** солиод SQL Editor дээр ажиллуулна. Нууц үг SQL-д оруулахгүй.

```sql
do $$
declare
  target_email text := 'your-email@example.com';
  target_user auth.users%rowtype;
begin
  select * into strict target_user from auth.users where email=target_email;
  if target_user.email_confirmed_at is null then
    raise exception 'Confirm the account email before granting admin';
  end if;
  insert into public.profiles(id,display_name)
  values(target_user.id,split_part(target_user.email,'@',1))
  on conflict(id) do nothing;
  update public.profiles set role='admin' where id=target_user.id;
end $$;
```

Аппаас гарч дахин нэвтрэхэд **Удирдлага** цэс гарна.

## Боломжууд ба эрхийн урсгал

- **Зочин:** нийтлэгдсэн бүтээл, багшийн танилцуулга, түүх, арга хэмжээ, цомог үзнэ. Нэр, зохиогч, он, ангилал, технологиор хайж, бүтээлийн төрлөөр шүүнэ.
- **Оюутан:** бүртгүүлж нэвтэрнэ; нэр, зураг, танилцуулгаа шинэчилнэ. Өөрийн бүтээлээ зурагтай нэмэх, засах, устгах боломжтой. Шинэ болон зассан бүтээл `pending` төлөвт орж, админы хяналтаар нийтлэгдэнэ.
- **Админ:** бүтээл, багш, арга хэмжээний CRUD; бүтээл нийтлэх/татгалзах; цомогт зураг оруулах/тайлбар засах/устгах; цагийн капсулын захиа хянах боломжтой.
- **Digital Time Capsule:** ирээдүйн оюутанд захиа үлдээнэ. Зөвшөөрөгдсөн захиа нийтэд харагдана; админ хүлээгдэж буй бүх захиаг хянана.
- Зураг: JPG/PNG/WebP, 8 MB хүртэл; `museum-media` Storage bucket; хэрэглэгчийн UUID хавтас.
- Keyboard: модаль дотор Tab шилжилт, Escape-ээр хаах, фокус буцаах үйлдэлтэй.

### Архивыг Storage-д оруулах

SQL seed нь энэ вебийн `/teachers/`, `/events/` зургуудыг ашиглана. Админаар **Удирдлага → Архив оруулах** дарвал зургуудыг өөрийн UUID хавтас дахь Supabase Storage-д байршуулна. Давтан дарахад давхардсан мөр нэмэхгүй, дутуу талбарыг нөхөж, редакторын байгаа мэдээллийг хадгална.

Цомгоос архивын зураг устгахад бусад бүтээлд ашиглагдаж буй хамтын файлыг устгахгүй. Тусад нь upload хийсэн gallery файл цомгийн мөртэйгээ хамт цэвэрлэгдэнэ.

## Өгөгдлийн загвар

`profiles.id` нь `auth.users.id`-ийг заана. Нэг профайл олон `exhibits`-тэй; `exhibits.category_id` нь `exhibition_categories.id`-ийг заана. `category` текстээс FK-г trigger автоматаар тааруулна. Нэг `events` мөр олон `event_photos`-той. `time_capsules.user_id` нь профайлыг заах эсвэл зочны захианд хоосон байна.

`creator_name` нь архивын анхны зохиогч/багийн нэр; `creator_id` нь мөрийг удирдах account. `collection` нь бүтээлийн төрөл, `archive_details` нь эх сурвалж, баг, шагнал зэрэг нэмэлт тайлбар. Арга хэмжээний өгүүлэл `events.article` JSON-д хадгалагдана. PK нь мөрийг ялгана, FK нь холбоосын бүрэн бүтэн байдлыг хангана.

## Шалгах

```bash
npm test
npm run build
```

Playwright болон Edge/Chromium байгаа хөгжүүлэлтийн орчинд:

```bash
npm run test:ui
node tests/live-smoke.mjs
```

`PLAYWRIGHT_MODULE`-д гадна runtime-ийн `playwright/index.mjs` зам, `BROWSER_CHANNEL`-д browser channel зааж болно. UI тест тусдаа түр browser profile, хиймэл API ашиглана. `live-smoke` нь тохируулсан Supabase-тай бодитоор холбогдож зөвхөн уншина. Browser тестүүд локал 4175/4176 портуудыг ашиглана.

`supabase/test-access.sql` нь хоёр оюутан, админы түр account үүсгэн PostgreSQL-ийн бодит role/RLS-ээр шалгаад бүх тестийн мөрийг ROLLBACK хийнэ. `finish-and-verify.sql` нь дутуу архивыг нөхөөд энэ тестийг ажиллуулна.

## Vercel-д байрлуулах

1. GitHub repository-гаа Vercel-д Import хийнэ.
2. Framework: **Vite**; build: `npm run build`; output: `dist`; root: repository-ийн үндэс.
3. `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`-г Production/Preview орчинд нэмнэ.
4. Deploy хийж, Supabase Auth → URL Configuration-д нийтийн domain-аа Site URL болон зөвшөөрөх redirect URL-д нэмнэ.
5. Нийтийн URL дээр бүртгэл, гаралт, бүтээл, gallery upload, capsule-аа шалгана.

`vercel.json` нь SPA rewrite-тэй. Нийтийн demo URL-ийг дээр оруулсан; environment өөрчилсний дараа Vite build-ийг Redeploy хийнэ.

## Агуулга ба хамгаалалт

10 багшийн мэдээллийг албан ёсны СЭЗИС-ийн профайлтай тулгасан. Б.Бат-Оргил багшийн заасан хичээлийг 2022 оны магадлан итгэмжлэлийн тайлангийн тухайн үеийн мэдээлэл гэж тэмдэглэсэн. Үзмэр нь уралдааны тайлан, СЭЗИС-ийн дипломын сангийн эх сурвалжтай. Зураг, хувийн мэдээллийн нийтлэх зөвшөөрлийг төслийг нийтийн хэрэглээнд өгөхийн өмнө эзэмшигч нь нягтална.

AI хэрэгсэл ашигласан тул хамгаалалтаар өөрийн нэмсэн шийдэл, React state/event, CRUD payload, PK/FK, RLS, Storage policy болон moderation урсгалаа кодоор тайлбарлана.
