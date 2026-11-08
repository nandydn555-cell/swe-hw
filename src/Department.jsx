import React from 'react';
import { ArrowUpRight, Mail, MapPin } from 'lucide-react';

const programs = [
  { name: '“Мэдээллийн систем”-ийн магистрын хөтөлбөр', href: 'https://www.ufe.edu.mn/c/6/Магистр/i/80/Мэдээллийн системийн менежмент' },
  { name: '“Мэдээллийн систем”-ийн бакалаврын үндсэн хөтөлбөр', href: 'https://www.ufe.edu.mn/c/7/Бакалавр/i/61/Мэдээллийн систем' },
  { name: '“Дата аналитик” олон улсын диплом олгох BTEC хөтөлбөр' },
  { name: '“Мэдээллийн систем”-ийн олон улсын хамтарсан 2+2 хөтөлбөр' }
];

const research = [
  'Өгөгдлийн менежмент ба агуулах, өгөгдөл олборлолт',
  'Процесс менежмент ба загварчлал',
  'Байгууллагын бизнес процессын шинжилгээ',
  'Мэдээллийн системийн стратеги',
  'Мэдээллийн технологийн засаглал',
  'Байгууллагын мэдлэгийн менежмент',
  'Цахим сургалт, мобайлд суурилсан үйлчилгээ',
  'Интернэт худалдаа, цахим бизнес',
  'Удирдлагын мэдээллийн систем',
  'Бизнесийн тандан шинжилгээ, өгөгдлийн агуулах'
];

export default function Department() {
  return <section className="department section" id="department" aria-labelledby="department-title">
    <div className="section-top"><div>
      <div className="eyebrow muted">ISM / ТЭНХИМИЙН ТАНИЛЦУУЛГА</div>
      <h2 id="department-title">Мэдээллийн системийн<br/><em>менежментийн тэнхим.</em></h2>
      <p className="section-intro">Технологийн дэвшлээр хөгжлийг хурдасгана.</p>
    </div></div>
    <img className="department-image" src="/department.jpg" alt="Мэдээллийн системийн менежментийн тэнхимийн танилцуулгын зураг" loading="lazy"/>
    <div className="department-purpose">
      <article><h3>Эрхэм зорилго</h3><p>Салбартаа хүлээн зөвшөөрөгдсөн, сургалт, судалгаа шинжилгээний энтрепренер их сургууль болсон байна.</p></article>
      <article><h3>Алсын хараа</h3><p>Өндөр түвшний технологийн үйлдвэрлэл, менежментээр олон улсад үнэлэгдэхүйц манлайлагчдыг бэлтгэх замаар нийгмийн эерэг шинэчлэл, хөгжилд хувь нэмэр оруулна.</p></article>
    </div>
    <div className="department-details">
      <article><div className="eyebrow muted">01 / СУРГАЛТ</div><h3>Хөтөлбөрүүд</h3><ul className="department-programs">{programs.map(program => <li key={program.name}>{program.href ? <a href={program.href} target="_blank" rel="noreferrer">{program.name}<ArrowUpRight size={17}/></a> : <span>{program.name}</span>}</li>)}</ul></article>
      <article><div className="eyebrow muted">02 / СУДАЛГАА</div><h3>Судалгааны ажлын тэргүүлэх чиглэл</h3><ul className="department-research">{research.map(area => <li key={area}>{area}</li>)}</ul></article>
    </div>
    <address className="department-contact">
      <h3>Холбоо барих</h3>
      <span><MapPin size={17}/>С байрны 2-р давхар, 205 тоот</span>
      <a href="mailto:ism_dpt@ufe.edu.mn"><Mail size={17}/>ism_dpt@ufe.edu.mn</a>
      <div className="social-links"><a href="https://www.instagram.com/ufe_ismd/" target="_blank" rel="noreferrer">IG · ufe_ismd <ArrowUpRight size={13}/></a><a href="https://www.facebook.com/profile.php?id=61576135060864" target="_blank" rel="noreferrer">FB · Мэдээллийн систем хөтөлбөр <ArrowUpRight size={13}/></a></div>
    </address>
  </section>;
}
