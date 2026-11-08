# Шалгалтын үр дүн — 2026-11-08

## Бодит серверээс баталгаажсан

Төслийн publishable key-ээр Supabase Data API-д холбогдож уншсан. Түлхүүрийг энэ тайланд хадгалаагүй.

| Хүснэгт | Нийтэд уншигдсан мөр |
|---|---:|
| exhibits | 7, бүгд published, бүгд creator_name-тай |
| teachers | 10, бүгд bio болон courses-тай |
| events | 5 |
| event_photos | 7 |
| profiles | 2 |
| time_capsules | 1 |
| exhibition_categories | 5 |

`complete-existing-project.sql` болон `finish-and-verify.sql`-ийг хэрэглэгч Supabase SQL Editor-д ажиллуулж, сүүлийн шалгалт PASS болсон гэж баталгаажуулсан. Үүний дараа 10 багшийн дутуу талбар 0 болсныг Data API-аар тусад нь дахин нягталсан.

## Тестүүд

- `npm test`: 6 unit/regression тест PASS. Өөрийн/бусдын бүтээлийн эрх, устгасан агуулга дахин гарч ирэхгүй байх, массивтай форм, хадгалсан зохиогч, хайлт, validation.
- `npm run build`: production build PASS.
- `tests/ui-smoke.mjs`: тусдаа headless Edge, хиймэл Supabase API. Browse, search, modal, админы массивтай бүтээл засвар, багш устгаад refresh хийх, оюутны published бүтээл засахад pending болох, устгах, архив import/retry, 360/390/768/1440 px халилт, browser exception шалгасан.
- `tests/live-smoke.mjs`: **бодит Supabase-тай**, зөвхөн унших browser smoke. Серверийн бүтээл, 10 багш, арга хэмжээ, цомгийн зураг ачаалалт, зочны UI, дөрвөн дэлгэцийн өргөн PASS.
- `supabase/test-access.sql`: PostgreSQL-ийн authenticated/anon role болон хэрэглэгчийн JWT subject-ийг сольж Auth/profile trigger, зөвшөөрөлгүй нийтлэл, owner солих, role ахиулах, бусдын draft харах/өөрчлөх/устгах, админ нийтлэх, owner revision, Storage-ийн UUID хавтасны хамгаалалтыг шалгана. Түр account/мөрүүд ROLLBACK хийгддэг. Энэ тестийн серверийн PASS үр дүнг хэрэглэгч баталгаажуулсан.

UI-ийн хиймэл API тест нь production RLS-ийн баталгаа биш; бодит role/RLS шалгалт нь тусдаа SQL тест юм. SQL-ийн Storage тест нь metadata-ийн policy-г шалгана; жинхэнэ binary файл upload-ыг нийтийн demo дээр account-аар нэвтэрч шалгах шаардлагатай.

## Байршуулалтын эцсийн шалгалт

Нийтийн demo: https://swe-hw-9f89.vercel.app/ . Production environment variables нэмээд Redeploy хийсний дараа `BASE_URL`-тай live smoke тест PASS болсон.

- Нүүр хуудас authentication шаардахгүйгээр HTTP 200.
- `teachers`, `exhibits`, `events`, `time_capsules`, `event_photos` Data API хүсэлтүүд бүгд HTTP 200.
- Серверийн 7 бүтээл, 10 багш, 5 арга хэмжээ харагдсан; цомгийн зураг decode амжилттай.
- Хайлтын илэрцгүй төлөв, дэлгэрэнгүй цонх, зочинд удирдах товч харагдахгүй байх шалгалт PASS.
- 360/390/768/1440 px өргөнд хөндлөн халилтгүй; browser exception 0.

Нэвтэрсэн хэрэглэгчийн CRUD, gallery upload, profile, capsule moderation урсгалууд хиймэл API-тай browser регрессийн тестээр, эрхийн дүрмүүд серверийн SQL тестээр шалгагдсан. Нийтийн domain дээр хэрэглэгчийн account-аар binary upload болон email recovery урсгалыг энэ read-only тест хийгээгүй. Supabase Site URL/redirect domain нь email холбоос ашиглах үед нийтийн URL-тай таарах ёстой.
