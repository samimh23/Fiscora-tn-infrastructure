const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../../../accounting-frontend/node_modules/playwright');

// Deliberately laid out as a vector drawing: long labels remain editable and sharp.
const W = 2200, H = 1660;
const out = __dirname;
const esc = s => String(s).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
const parts = [];
const C = { ink: '#142c3d', muted: '#557083', line: '#d5e2ea', blue: '#1765a5', purple: '#7550ad', teal: '#087f82' };
function text(x, y, s, size = 20, color = C.ink, weight = 400, anchor = 'start') {
  parts.push(`<text x="${x}" y="${y}" font-size="${size}" fill="${color}" font-weight="${weight}" text-anchor="${anchor}">${esc(s)}</text>`);
}
function rect(x,y,w,h,fill='#fff',stroke=C.line,r=16) {
  parts.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}" stroke="${stroke}" stroke-width="1.6"/>`);
}
function group(x,y,w,h,title,sub,fill,stroke) {
  rect(x,y,w,h,fill,stroke,22);
  text(x+24,y+36,title,25,stroke,700);
  if(sub) text(x+24,y+63,sub,17,C.muted);
}
function box(id,x,y,w,h,title,lines=[],accent=C.blue) {
  parts.push(`<g data-box="${id}">`);
  rect(x,y,w,h,'#fff',C.line,14);
  parts.push(`<path d="M${x+2} ${y+15} V${y+h-15}" stroke="${accent}" stroke-width="5" stroke-linecap="round"/>`);
  text(x+20,y+32,title,21,C.ink,700);
  lines.forEach((line,i)=>text(x+20,y+60+i*24,line,17,C.muted));
  parts.push('</g>');
}
function edge(d,kind='data',arrow=true) {
  const color = kind==='auth'?C.purple:kind==='deploy'?C.muted:C.teal;
  const dash = kind==='auth'?' stroke-dasharray="5 7"':kind==='deploy'?' stroke-dasharray="10 6"':'';
  parts.push(`<path d="${d}" fill="none" stroke="${color}" stroke-width="2.5" stroke-linejoin="round"${dash}${arrow?` marker-end="url(#${kind})"`:''}/>`);
}
function tag(x,y,s,kind='data',width) {
  const color=kind==='auth'?C.purple:kind==='deploy'?C.muted:C.teal;
  const w=width||s.length*8.5+24;
  rect(x-w/2,y-18,w,27,'#f8fbfd','none',7);
  text(x,y+1,s,15,color,600,'middle');
}

parts.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"><defs>${['data','auth','deploy'].map(k=>`<marker id="${k}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 Z" fill="${k==='data'?C.teal:k==='auth'?C.purple:C.muted}"/></marker>`).join('')}</defs><style>text{font-family:Arial,Helvetica,sans-serif}</style>`);
rect(0,0,W,H,'#f4f7fa','none',0);
text(40,58,'Architecture de déploiement de Fiscora',38,C.ink,700);
text(40,93,'Environnement staging · application web, services cloud et chaîne de livraison',22,C.muted);
edge('M1485 68 H1535','data'); text(1550,74,'Données / requêtes',17);
edge('M1770 68 H1820','auth'); text(1835,74,'DNS / authentification',17);
text(40,150,'1  APPLICATION ET SERVICES',18,C.muted,700);

group(400,180,1110,860,'Microsoft Azure','', '#eaf3fc',C.blue);
group(1540,180,620,705,'Google Cloud','Services IA : endpoints HTTPS avec accès IAM.','#f2edf9',C.purple);
group(435,360,630,640,'Réseau virtuel Azure (VNet)','Sous-réseaux distincts pour Container Apps et PostgreSQL.','#f3f8fd','#6c8eaa');
group(460,405,580,350,'Sous-réseau Container Apps','Environnement Azure Container Apps','#e5eff8','#7394ad');
rect(478,482,544,247,'#f8fbff','#92aabe',15);
text(498,511,'Container App · API + sidecar',19,C.muted,700);
group(460,790,580,190,'Sous-réseau PostgreSQL','Sous-réseau délégué + DNS privé','#e5eff8','#7394ad');

// Browser execution and DNS are distinct from the hosting service.
box('browser',40,222,310,162,'Navigateur utilisateur',['Client · Collaborateur','Comptable · Administrateur','React s’exécute ici.']);
box('swa',435,220,305,105,'Azure Static Web Apps',['Fichiers React + Vite','Domaine : app.fiscora.me']);
box('dns',40,780,310,105,'Namecheap · DNS',['Registrar / zone parente','Résolution app et API'],C.purple);
box('email-dns',1130,220,320,105,'Azure DNS · e-mails',['Sous-domaine : inbox.fiscora.me','MX / DKIM / vérification Brevo'],C.purple);
edge('M350 260 H435'); tag(392,244,'HTTPS', 'data',75);
edge('M195 384 V573 H500'); tag(343,554,'HTTPS REST + WSS / Socket.IO','data',276);
edge('M40 330 H20 V740 H195 V780','auth'); tag(190,739,'Résolution DNS','auth',155);
edge('M350 835 H380 V335 H1290 V325','auth'); tag(905,335,'Délégation NS du sous-domaine entrant','auth',355);

box('api',500,535,500,98,'API NestJS · REST + Socket.IO',['Logique métier, recherche et orchestration RAG']);
box('clam',500,668,260,53,'ClamAV · sidecar',[],C.blue);
box('postgres',480,877,540,78,'PostgreSQL 16 · Flexible Server',['Données métier + pgvector · accès réseau privé']);
box('blob',1120,410,330,107,'Azure Blob Storage',['Pièces comptables','Accès via identité managée']);
box('vault',1120,560,330,107,'Azure Key Vault',['Secrets applicatifs','Accès via identité managée']);
box('monitoring',1120,710,330,107,'Supervision Azure',['Application Insights','Log Analytics']);
edge('M625 633 V668'); tag(811,652,'TCP localhost:3310','data',175);
edge('M805 633 V772 H990 V861 H805 V877'); tag(899,862,'PostgreSQL / TLS','data',170);
edge('M1000 555 H1080 V463 H1120'); tag(1053,446,'Documents','data',105);
edge('M1000 584 H1095 V613 H1120'); tag(1062,607,'Secrets','data',80);
edge('M1000 614 H1080 V763 H1120'); tag(1060,745,'Télémétrie','data',110);

// The vertical rail denotes independent direct API calls, not an extra proxy.
box('vertex',1620,287,500,110,'Vertex AI · Gemini + embeddings',['Réponses de l’assistant et vecteurs de recherche','Pas de moteur Vertex RAG géré'],C.purple);
box('nuextract',1620,427,500,110,'Cloud Run GPU · NuExtract3 + vLLM',['Extraction structurée : factures et relevés','Service d’extraction configuré par défaut'],C.purple);
box('qwen',1620,567,500,110,'Cloud Run GPU · Qwen3.5 + vLLM',['Extraction des catégories génériques','Service distinct de NuExtract3'],C.purple);
box('ocr',1620,707,500,110,'Cloud Run CPU · PaddleOCR PP-OCRv6',['OCR, coordonnées et rendu des pages PDF','Pas de GPU pour ce service'],C.purple);
edge('M1000 555 H1050 V352 H1580 V762','data',false);
[342,482,622,762].forEach(y=>edge(`M1580 ${y} H1620`));
edge('M1580 352 V342','data',false);
tag(1310,380,'Appels directs API → IA · HTTPS + jeton IAM','data',410);
text(1562,855,'IAM obligatoire ; ingress public, sans accès anonyme.',17,C.purple);

// Email traffic has two directions and uses two different protocols.
box('brevo',1540,928,620,112,'Brevo · e-mails',['Sortant : envoi SMTP depuis l’API','Entrant : parsing + webhook HTTPS vers l’API'],C.teal);
edge('M1450 295 H1524 V900 H1810 V928','auth');
tag(1755,904,'MX / DNS e-mails entrants','auth',235);
edge('M1000 601 H1107 V972 H1540'); tag(1315,969,'SMTP / STARTTLS','data',185);
edge('M1540 1015 H1089 V626 H1000'); tag(1305,1013,'Webhook HTTPS sécurisé','data',240);
text(1120,872,'Les documents originaux restent dans Azure.',17,C.muted);
text(1120,899,'L’IA reçoit les données nécessaires à l’inférence.',17,C.muted);

text(40,1090,'2  AUTHENTIFICATION AZURE → GOOGLE (SANS CLÉ GOOGLE PERMANENTE)',18,C.muted,700);
rect(40,1110,2120,160,'#fff',C.line,18);
box('mi',60,1140,315,100,'Identité managée Azure',['Identité utilisée par l’API','Jeton Microsoft Entra ID'],C.purple);
box('wif',450,1140,390,100,'Google STS + WIF',['Échange du jeton Azure','Workload Identity Federation'],C.purple);
box('iam',915,1140,410,100,'Compte de service Google / IAM',['Jeton d’identité pour Cloud Run','Jeton d’accès pour Vertex AI'],C.purple);
edge('M375 1190 H450','auth'); edge('M840 1190 H915','auth');
edge('M1325 1190 H1390','auth');
text(1410,1177,'L’API utilise ces jetons pour ses appels HTTPS.',21,C.ink,700);
text(1410,1208,'WIF authentifie : il ne relaie pas les documents.',19,C.muted);
text(1410,1235,'Même identité Azure pour Blob Storage et Key Vault.',17,C.muted);

text(40,1320,'3  CONSTRUCTION, DÉPLOIEMENT ET PROVISIONNEMENT',18,C.muted,700);
rect(40,1340,2120,242,'#fff',C.line,18);
text(60,1370,'APPLICATION AZURE',17,C.blue,700);
text(1200,1370,'CONTENEURS IA GOOGLE CLOUD',17,C.purple,700);
box('github',60,1390,270,115,'GitHub Actions · CI/CD',['Authentification Azure OIDC','Build frontend et backend']);
box('publish',405,1390,305,115,'Publication Azure',['Frontend → Static Web Apps','Backend → Azure ACR']);
box('revision',785,1390,300,115,'Révision Container App',['Image backend depuis ACR','API déployée sur Azure']);
edge('M330 1447 H405','deploy'); edge('M710 1447 H785','deploy');
box('build',1200,1390,265,115,'Google Cloud Build',['Lancé par les scripts gcloud','Build des images IA'],C.purple);
box('registry',1530,1390,265,115,'Artifact Registry',['Images Qwen / NuExtract','Image PaddleOCR'],C.purple);
box('run',1860,1390,275,115,'Services Cloud Run',['Révisions CPU / GPU','Images référencées par digest'],C.purple);
edge('M1465 1447 H1530','deploy'); edge('M1795 1447 H1860','deploy');
text(60,1547,'Terraform',21,C.ink,700);
text(200,1547,'provisionne les ressources Azure / Google Cloud et configure Cloud Run ; ce n’est pas un flux utilisateur.',19,C.muted);
text(40,1621,'Lecture : traits pleins = flux applicatifs ; pointillés violets = DNS / identité ; tirets gris = chaîne de livraison.',17,C.muted);
text(40,1646,'Schéma fondé sur la configuration des dépôts. L’état, la disponibilité et les révisions réellement déployées ne sont pas audités ici.',16,C.muted);
parts.push('</svg>');

(async()=>{
  fs.writeFileSync(path.join(out,'fiscora-deployment-staging.svg'),parts.join('\n'));
  const browser=await chromium.launch({headless:true});
  try {
    const page=await browser.newPage({viewport:{width:W,height:H},deviceScaleFactor:2});
    await page.setContent(`<style>body{margin:0}svg{display:block}</style>${parts.join('\n')}`);
    const checks=await page.locator('svg text').evaluateAll(nodes=>nodes.map(n=>{
      const b=n.getBBox(); const p=n.closest('[data-box]'); const r=p?.querySelector('rect');
      return {text:n.textContent,x:b.x,y:b.y,w:b.width,h:b.height,box:r?{x:+r.getAttribute('x'),y:+r.getAttribute('y'),w:+r.getAttribute('width'),h:+r.getAttribute('height')}:null};
    }));
    const clipped=checks.filter(b=>b.x<0||b.y<0||b.x+b.w>W||b.y+b.h>H||(b.box&&(b.x<b.box.x||b.x+b.w>b.box.x+b.box.w-10||b.y+b.h>b.box.y+b.box.h)));
    if(clipped.length) throw Error(`Clipped labels: ${JSON.stringify(clipped)}`);
    await page.screenshot({path:path.join(out,'fiscora-deployment-staging.png'),fullPage:true});
    console.log(`Generated SVG and 4400 × 3320 PNG; ${checks.length} labels checked for clipping.`);
  } finally {await browser.close();}
})().catch(err=>{console.error(err);process.exitCode=1;});
