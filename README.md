# ISM Digital Museum

ISM-ийн түүх, багш нар, арга хэмжээ, оюутны бүтээлийг танилцуулах responsive дижитал музей. React + JavaScript, Vite, Supabase ашиглана. Одоогийн preview нь Supabase тохируулаагүй үед demo өгөгдлөөр ажиллана.

## Эхлүүлэх

```bash
npm install
cp .env.example .env.local
npm run dev
```

`.env.local` файлдаа Supabase project-ийн URL болон **anon/publishable** key-гээ оруулна. Service role key-ийг frontend-д хэзээ ч бүү оруул.

### SQL ажиллуулах дараалал

SQL Editor дээр файлуудыг доорх дарааллаар тус тус ажиллуулна. Эдгээр нь SQL Editor-д зориулсан скриптүүд; `supabase db push` нь `schema.sql`, `admin-migration.sql`, storage болон seed файлуудыг автоматаар ажиллуулахгүй.

| Алхам | Шинэ, хоосон project | Өмнө schema үүсгэсэн project |
| --- | --- | --- |
| 1 | `supabase/schema.sql` | `supabase/migrations/20261106_category_relation.sql` |
| 2 | `supabase/admin-migration.sql` (schema-д мөн багтсан; дахин ажиллуулахад аюулгүй) | `supabase/admin-migration.sql` |
| 3 | `supabase/setup-storage.sql` | `supabase/setup-storage.sql` |
| 4 | `supabase/seed-verified-content.sql` | `supabase/seed-verified-content.sql` |
| 5 | `supabase/verify-setup.sql` | `supabase/verify-setup.sql` |

`schema.sql`-ийг хуучин project дээр дахин ажиллуулахгүй: `CREATE TABLE IF NOT EXISTS` нь хуучин багануудыг шинэчлэхгүй, харин давхардсан policy дээр алдаа гарна. Category migration нь `profiles.bio`, `exhibits.category_id`, FK болон category trigger-ийг нэмдэг; үндсэн хүснэгтүүд өмнө нь үүссэн байх ёстой. Storage setup нь `public.is_admin()`-аас хамаардаг. Seed нь `teachers`, `events` хүснэгтүүд үүссэний дараа ажиллана. Seed-ийг дараалан дахин ажиллуулахад нэр/гарчгаар таарсан мөрүүдийг шинэчилнэ; өмнө байсан давхардлыг устгахгүй.

`verify-setup.sql` нь зөвхөн уншина. 7 хүснэгт бүгд RLS-тэй, 3 trigger идэвхтэй, seed-ийн 5 мөр тус бүр `matches = 1`, `invalid_category_references = 0`, `museum-media` нь public / 8388608 bytes / JPG, PNG, WebP байхыг шалгана. Policy-ийн `USING`/`WITH CHECK`, `anon`/`authenticated` table grants-ийг хамт нягтална. Админ үүсгэсний дараа `confirmed_email_admins >= 1`, `users_missing_profiles = 0` байх ёстой. Энэ query-г хараахан сервер дээр ажиллуулаагүй бол trigger, RLS болон админ бичих эрхийг бүрэн баталгаажсан гэж үзэхгүй.

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

Бүртгүүлсэн хэрэглэгчийг Supabase Auth-д баталгаажуулна. Шинэ бүтээл `pending` төлөвтэй орно; нийтэд харагдуулахын тулд админ `profiles.role`-ийг `admin` болгон тохируулж, бүтээлийн `status`-ийг `published` болгоно.

### Бүтээл илгээхэд `exhibits_creator_id_fkey` алдаа гарвал

Auth account байгаа ч `public.profiles` дахь холбогдох профайл дутсан байна. Supabase Dashboard → SQL Editor дээр `supabase/repair-missing-profiles.sql` файлыг бүхэлд нь `postgres` эрхээр ажиллуулна. Скрипт хуучин account-уудын дутуу профайлыг нөхөж, шинэ account үүсэх trigger-ийг сэргээнэ; байгаа профайл, админ эрхийг өөрчлөхгүй. Үр дүнд `users_missing_profiles = 0`, `profile_trigger_enabled = true` гарсны дараа сайтаа refresh хийгээд бүтээлээ дахин илгээнэ. Дараа нь шинэ энгийн хэрэглэгчээр бүртгүүлж, бүтээл нь `pending` төлөвтэй хадгалагдахыг шалгана.

Trigger-ийн загвар: [Supabase User Management](https://supabase.com/docs/guides/auth/managing-user-data).

## Үндсэн боломж

- Үзмэрийн хайлт, ангиллын шүүлтүүр, бүтээлийн дэлгэрэнгүй
- Бүтээл бүрийн demo болон GitHub холбоос
- Supabase Auth бүртгэл, нэвтрэх, гарах
- Бүтээл илгээх; өөрийн бүтээлийг засах/устгах эрхийг RLS хамгаална
- ISM-ийн түүхийн timeline, дэлгэрэнгүй багшийн профайл, бүтээлтэй холбогдсон оюутны танилцуулга
- Арга хэмжээ бүрийн тайлбартай зургийн цомог; админ цомогт зураг нэмж, устгаж болно
- Digital Time Capsule: хэрэглэгч захиа үлдээнэ, админ хянана, зөвшөөрсөн захианууд нийтэд харагдах хананд гарна
- Жижиг дэлгэцэд тохирох layout болон empty state

Demo горимд бүтээл зөвхөн тухайн хөтчийн дэлгэцэнд түр харагдана; Supabase тохируулбал бодит хадгалалт, эрхийн хамгаалалт ажиллана. Тэнхимийн хэсэгт хэрэглэгчийн өгсөн эрхэм зорилго, алсын хараа, уриа, 4 хөтөлбөр, судалгааны 10 чиглэл, хаяг болон имэйлийг оруулсан. Багш нарын хэсэгт өгсөн дарааллын дагуу 10 багшийн нэр, албан тушаал, албан ёсны холбоосоос татсан хөргийг, үүнд Н.Хөгжилт багшийн зургийг нэмсэн. Хөргүүд `public/teachers/` дотор хадгалагдана. Өмнө баталгаажуулсан 3 багшийн дэлгэрэнгүй болон 2 үйл явдлын мэдээллийг хадгалсан; `supabase/seed-verified-content.sql` нь өмнөх 3 багшийн seed хэвээр. Серверийн багшийн өгөгдлийг нэрээр тааруулж нэгтгэдэг тул хоосон эсвэл хэсэгчилсэн хүснэгт нь үндсэн 10 багшийн жагсаалтыг арилгахгүй. Instagram, Facebook холбоосыг хэрэглэгч өгсөн. Бусад demo бүтээл, timeline-ийн он цагийг нийтлэхийн өмнө нягтална.

Шинэ бүтээл нэмэхэд demo, GitHub, зургийн URL заавал шаардлагагүй. Зургийг JPG/PNG/WebP файлаар (8 MB хүртэл) шууд сонгож болно. Холбоос оруулах талбарууд нэмэлт дэлгэгддэг хэсэгт байрлана. Demo горимд сонгосон зураг зөвхөн тухайн хөтчийн түр сессэд харагдана.

## Өгөгдлийн загвар

- `profiles.id` нь `auth.users.id`-тэй ижил UUID; нэр, зураг, танилцуулгыг хадгалж, нэг хэрэглэгчийн профайл болон олон бүтээлийг холбоно.
- `exhibits.creator_id` нь `profiles.id`, `exhibits.category_id` нь `exhibition_categories.id`-ийн гадаад түлхүүр. `category` текст талбар нь одоогийн апптай нийцэхийн тулд үлдсэн; database trigger FK-г автоматаар тааруулна. `status` нь хүлээгдэж буй, нийтлэгдсэн, татгалзсан төлөвийг хадгална.
- `events.id`-ээс `event_photos.event_id` рүү нэгээс-олон холбоос үүснэ.
- `exhibition_categories` нь үзмэрийн ангиллын лавлах.
- `teachers` нь багшийн танилцуулгыг бие даан хадгална. `time_capsules.user_id` нэвтэрсэн хэрэглэгчийн профайлыг зааж болно.

RLS policy-ууд нийтэд зөвхөн нийтлэгдсэн бүтээл харуулж, бүтээгчид өөрийн өгөгдөлд хүрэх, админд хяналт хийх эрх олгоно. Storage-д файл хэрэглэгчийн UUID нэртэй хавтас дотор байрлана. Service role key шаардлагагүй.

## Бүтээлч шийдэл

Үйл явдлын архивт хэрэглэгчийн өгсөн 2026.03.26-ны “Бүтээлийн уралдаан” (50 оюутан, 13 баг, 4С танхим) болон 2026.03.20-ны “Програмчлалын олимпиад”-ын мэдээг нэмсэн. М банкны ивээн тэтгэлэг, шалгарсан 3 баг, олимпиадын 4 оюутны нэр/оноо, 3-р байрны ижил дүнг тус тус хадгалсан. Хоёр мэдээнд нийт 4 зурагтай; давхардсан бүтээлийн уралдааны нүүр зургийг нэг удаа ашигласан. `public/events/` дахь зургуудыг хэрэглэгчийн өгсөн UFE холбоосуудаас татаж хэмжээг багасгасан. Архив шинэ огнооноос эхэлж эрэмбэлэгдэнэ. Эдгээр мэдээ локал архивт багтдаг тул серверт SQL ажиллуулах шаардлагагүй.

Хэрэглэгчийн өгсөн СЭЗИС-ийн магадлан итгэмжлэлийн мэдээнд тулгуурлан timeline-д 2005 оны хөтөлбөрийн эхлэл, 2022.06.29-ний 5 жилийн хугацаатай магадлан итгэмжлэлийг оруулсан. Баталгаагүй 1999, 2008, 2016 оны demo мөрүүдийг хассан. Мэдээ нь үйл явдлын архивт нүүр зураг, дэлгэрэнгүй тайлбар, Бакалавр 2.0-ийн 5 шинэчлэл, эх сурвалжийн нэртэй харагдана. Энэ нь 2022 оны түүхэн мэдээ; өнөөгийн магадлан итгэмжлэлийн төлөвийг батлахгүй. Зургийг өгсөн албан ёсны холбоосоос татаж `public/events/accreditation-2022.jpg` болгон вебэд тохируулсан. Серверийн үйл явдлуудыг локал архивтай гарчгаар нэгтгэдэг тул энэ мэдээ серверийн хоосон/хэсэгчилсэн жагсаалтаас болж алга болохгүй. Серверийн seed файл өмнөх 2 үйл явдалтай хэвээр; шинэ мэдээнд SQL ажиллуулах шаардлагагүй.

Он цагийн түүхийг timeline болгон харуулахын зэрэгцээ “Digital Time Capsule” хэсэгт ирээдүйн оюутнуудад мессеж үлдээх санааг нэмсэн. Админ хянасны дараа захианууд “Захианы хана”-д гарна. Бүтээлийн demo болон GitHub холбоос нь үзмэрийг харахаас туршиж үзэх алхам руу хөтөлнө.

ERD, wireframe болон 5–7 минутын demo-ийн танилцуулгын дараалал: [`docs/architecture-and-demo.md`](docs/architecture-and-demo.md).

## Байршуулалт

Vercel-д Git repository холбоод автоматаар deploy хийж болно. Тохиргоо: Framework preset `Vite`, Build command `npm run build`, Output directory `dist`. Root directory нь энэ төслийн хавтас байна. `vercel.json` нь React SPA-ийн route-уудыг `index.html` рүү буцаах rewrite агуулна.

Vercel Project Settings → Environment Variables хэсэгт доорхыг **Production, Preview, Development** орчинд нэмээд дахин deploy хийнэ:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-publishable-key
```

Зөвхөн Supabase publishable/anon key ашиглана; `service_role` key-г frontend эсвэл Vercel-ийн browser environment-д бүү хий. Дээрх **SQL ажиллуулах дараалал**-ыг дагана.

### Эхний админ

1. Аппын **Бүртгүүлэх** хэсэг эсвэл Supabase Dashboard → Authentication → Users-ээр өөрийн account-ийг үүсгэнэ. Email confirmation идэвхтэй бол имэйлээ баталгаажуулна. Нууц үгийг SQL файлд хадгалахгүй.
2. SQL Editor-ийг `postgres` эрхээр нээж, доорх имэйлийг өөрийн бүртгэлийн имэйлээр солиод ажиллуулна. Account байхгүй эсвэл имэйл баталгаажаагүй үед тодорхой алдаа өгнө; профайл дутсан бол нөхөж, зөвхөн сонгосон хэрэглэгчид админ эрх олгоно.

```sql
do $$
declare
  target_email text := 'your-email@example.com';
  target_user auth.users%rowtype;
begin
  select * into strict target_user from auth.users where email = target_email;
  if target_user.email_confirmed_at is null then
    raise exception 'Confirm the account email before granting admin';
  end if;
  insert into public.profiles (id, display_name)
  values (target_user.id, coalesce(nullif(target_user.raw_user_meta_data->>'display_name', ''), split_part(target_user.email, '@', 1)))
  on conflict (id) do nothing;
  update public.profiles set role = 'admin' where id = target_user.id;
end $$;
```

3. `supabase/verify-setup.sql`-ийг дахин ажиллуулж, админы төлөвийг нягтална. Аппаас гарч дахин нэвтрээд **Удирдлага** цэсийг шалгана. Апп `profiles.role`-ийг нэвтрэх үед уншдаг.

Нэвтэрсний дараа **Удирдлага** цэс нээгдэж, бүтээл, багш, үйл явдлыг нэмэх, засах, устгах болон JPG/PNG/WebP зураг оруулах боломжтой.

Vercel dashboard-ийн Git integration-д GitHub/GitLab/Bitbucket repository холбоно. Одоогийн workspace Git remote-гүй; CLI нэвтэрсний дараа локал хавтсаас шууд deploy хийх хувилбар бас бий.
