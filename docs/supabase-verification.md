# Supabase шалгалтын үр дүн

Project: `nnozmuiqklcogyjxmtli`. Энэ нь тухайн шалгалтын үеийн snapshot; тохиргоо цааш өөрчлөгдөж болно.

## Баталгаажсан

- `npm run build` амжилттай: Vite 6.4.5, 1618 modules, 7.84 секунд.
- `.env.local`-ийн URL болон publishable key-ээр Auth, Data API-д бодитоор холбогдсон. Key-г тайланд хадгалаагүй.
- Auth: email provider идэвхтэй, `disable_signup = false`, `mailer_autoconfirm = true`. Одоогоор шинэ email account автоматаар баталгаажна.
- Data API-аар 7 хүснэгт бүгд уншигдсан. `exhibition_categories` 5 мөртэй. `profiles`, `teachers`, `events`, `exhibits`, `event_photos`, `time_capsules` нь anonymous хүсэлтэд 0 мөр буцаасан.
- `profiles.bio`, `profiles.role`, `exhibits.category_id` баганууд API-аар уншигдсан.
- `profiles`-ийг `role=admin` шүүлтүүрээр уншихад 0 мөр. Одоогийн schema-ийн public SELECT policy мөрдөгдөж байгаа бол админ профайл байхгүй гэсэн үг.
- Anonymous `is_admin()` RPC `false` буцаасан.
- `museum-media` public object probe нь `NoSuchKey / Object not found` буцаасан. Энэ нь bucket public route ажиллаж байгааг илтгэнэ; bucket-ийн хэмжээ, MIME болон бичих policy-г үүгээр батлахгүй.

## Үлдсэн ажил

- `teachers`, `events`-ийн public SELECT policy одоогийн schema-тай таарч байгаа бол seed серверт ороогүй. README-ийн дарааллаар seed-ийг ажиллуулаад 3 багш, 2 үйл явдлыг дахин шалгана.
- Publishable key нь SQL ажиллуулах, `auth.users`, trigger, policy тодорхойлолт, migration history-г унших эрхгүй. Supabase CLI/psql эсвэл Supabase MCP холболт энэ орчинд байхгүй. Иймээс migration яг ямар дарааллаар серверт ажилласныг, Auth хэрэглэгч байгаа эсэхийг батлаагүй.
- `supabase/verify-setup.sql`-ийг SQL Editor-д ажиллуулж серверийн trigger, RLS, grants, seed болон Auth/profile холбоог шалгана. Энэ файл зөвхөн уншина; одоогоор сервер дээр ажиллуулаагүй.
- README-ийн **Эхний админ** алхмыг сонгосон account-даа хэрэгжүүлнэ. Энэ шалгалтаар account үүсгээгүй, админ эрх олгоогүй, серверийн өгөгдөл өөрчлөөгүй.
- Админаар нэвтрэн бүтээл нэмэх/нийтлэх, зураг upload хийх болон энгийн хэрэглэгч эрхээ ахиулж чадахгүйг runtime түвшинд туршиж байж бичих эрхийг бүрэн батална.

Auth/profile trigger-ийн загварыг [Supabase User Management](https://supabase.com/docs/guides/auth/managing-user-data), оношлогоог [Supabase Observability](https://supabase.com/docs/guides/observability)-тай тулгав.
