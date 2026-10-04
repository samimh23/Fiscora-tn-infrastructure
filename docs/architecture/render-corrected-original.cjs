const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../../../accounting-frontend/node_modules/playwright');

// Compact vector recreation of the original overview, with corrected topology.
const W=2760, H=1140, a=[];
const c={bg:'#171b20',panel:'#252d36',node:'#083855',stroke:'#28658b',text:'#e5f0f7',muted:'#a4bdcf',data:'#82c5ed',auth:'#c4a6e5',deploy:'#9aaebb'};
const escape=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;');
function t(x,y,s,size=19,color=c.text,weight=400,anchor='middle'){a.push(`<text x="${x}" y="${y}" font-family="Arial,Helvetica,sans-serif" font-size="${size}" font-weight="${weight}" fill="${color}" text-anchor="${anchor}">${escape(s)}</text>`);}
function r(x,y,w,h,fill=c.node,stroke=c.stroke,rad=14){a.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rad}" fill="${fill}" stroke="${stroke}" stroke-width="1.5"/>`);}
function box(id,x,y,w,h,lines){a.push(`<g data-box="${id}">`);r(x,y,w,h); const start=y+h/2-(lines.length-1)*13+6;lines.forEach((s,i)=>t(x+w/2,start+i*26,s,i===0?20:18,i===0?c.text:c.muted,i===0?700:400));a.push('</g>');}
function group(x,y,w,h,label){r(x,y,w,h,c.panel,'#4b5b69',16);t(x+w/2,y+31,label,21,c.text,700);}
function e(d,k='data',both=false,arrow=true){a.push(`<path d="${d}" fill="none" stroke="${c[k]}" stroke-width="2.1" stroke-linejoin="round"${k==='data'?'':` stroke-dasharray="${k==='auth'?'4 7':'9 6'}"`}${arrow?` marker-end="url(#m-${k})"`:''}${both?` marker-start="url(#m-${k})"`:''}/>`);}
function tag(x,y,s,k='data',w){const width=w||s.length*9+24;r(x-width/2,y-20,width,30,c.bg,'none',10);t(x,y,s,16,c[k],600);}
a.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"><defs>${['data','auth','deploy'].map(k=>`<marker id="m-${k}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0L10 5L0 10Z" fill="${c[k]}"/></marker>`).join('')}</defs>`);
r(0,0,W,H,c.bg,'none',0);
t(40,40,'Fiscora — architecture physique de déploiement (staging)',30,c.text,700,'start');

group(630,190,1190,635,'Microsoft Azure');
group(1060,375,360,290,'Azure Container Apps');
r(1075,409,330,237,'#202933','#456275',13);
t(1240,435,'Container App : API + sidecar',17,c.muted);
group(1880,280,850,780,'Google Cloud');

box('browser',40,75,230,105,['Users / browser','Client · Accountant','Employee · Administrator']);
box('dns',370,75,230,105,['Namecheap','Domain and DNS']);
box('brevo',1880,75,280,105,['Brevo','SMTP + inbound parsing']);
box('frontend',690,365,250,100,['Azure Static Web Apps','React + Vite frontend']);
box('acr',690,550,250,100,['Azure Container Registry','Backend images']);
box('api',1090,455,290,95,['NestJS API','REST + Socket.IO','RAG orchestration']);
box('clam',1090,575,290,62,['ClamAV sidecar']);
box('db',1500,275,275,100,['Azure PostgreSQL 16','Flexible Server + pgvector','Private subnet']);
box('blob',1500,425,275,95,['Azure Blob Storage','Accounting documents']);
box('vault',1500,565,275,95,['Azure Key Vault','Secrets and keys']);
box('monitoring',1500,705,275,95,['Application Insights','Log Analytics']);

box('wif',1910,335,270,95,['Workload Identity','Federation + Google IAM','Authentication only']);
box('vertex',2360,335,335,100,['Vertex AI','Gemini + embeddings']);
box('qwen',2360,475,335,100,['IAM-authenticated Cloud Run','GPU · Qwen3.5 + vLLM']);
box('ocr',2360,615,335,100,['IAM-authenticated Cloud Run','CPU · PaddleOCR PP-OCRv6']);
box('nuextract',2360,755,335,100,['IAM-authenticated Cloud Run','GPU · NuExtract3 + vLLM']);
box('registry',1910,740,270,100,['Google Artifact Registry','AI container images']);
box('cloudbuild',1910,955,270,90,['Google Cloud Build','AI image build / push']);
box('github',320,520,230,105,['GitHub Actions','Azure CI/CD + OIDC']);
box('terraform',320,725,230,100,['Terraform','Infrastructure as Code']);

// DNS is a lookup, not an HTTPS application proxy.
e('M270 103 H370','auth');tag(320,90,'DNS','auth',58);
e('M600 110 H1805 V95 H1880','auth');tag(1210,110,'Email DNS records · delegated Azure DNS zone','auth',425);
// Files are hosted by SWA; application API requests originate in the browser.
e('M155 180 V265 H610 V415 H690');tag(505,415,'HTTPS · web files','data',168);
e('M270 160 H295 V330 H1235 V455');tag(860,329,'Browser → API · HTTPS / REST / WebSocket','data',410);
e('M1235 550 V575');
e('M1380 470 H1435 V325 H1500');tag(1435,295,'PostgreSQL / TLS','data',160);
e('M1380 497 H1500');tag(1440,482,'Managed identity','data',160);
e('M1380 519 H1450 V612 H1500');tag(1450,594,'Managed identity','data',160);
e('M1380 540 H1435 V752 H1500');tag(1450,737,'Telemetry','data',105);

// One data rail represents direct authenticated API calls to the four AI services.
e('M1380 470 H1465 V249 H2310 V785','data',false,false);
[385,505,645,785].forEach(y=>e(`M2310 ${y} H2360`));
tag(2050,248,'Direct API calls · HTTPS + IAM token','data',360);
// WIF is a separate token acquisition path, never a document relay.
e('M1380 534 H1400 V882 H2210 V383 H2180','auth',true);
tag(1765,882,'Azure identity → Google tokens (no permanent key)','auth',455);

// Distinct outbound SMTP and inbound HTTPS webhook routes.
e('M1380 484 H1482 V205 H2020 V180');tag(1710,204,'SMTP / STARTTLS','data',165);
e('M1880 120 H1845 V450 H1394 V510 H1380');tag(1837,430,'HTTPS webhook','data',154);

// Original Azure delivery flow is preserved. AI builds are Google Cloud Build.
e('M550 551 H655 V449 H690','deploy');tag(617,482,'Build frontend','deploy',142);
e('M550 595 H690','deploy');tag(620,581,'Push image','deploy',110);
e('M940 601 H1015 V498 H1090','deploy');tag(1013,583,'Deploy revision','deploy',147);
e('M550 770 H630','deploy');tag(590,755,'Azure','deploy',68);
e('M435 825 V1068 H1850 V874 H1880','deploy');tag(1200,1068,'Provision Azure and Google Cloud','deploy',327);
e('M2045 955 V840','deploy');tag(2045,936,'Build / push AI images','deploy',218);
e('M2180 790 H2265 V545','deploy',false,false);
e('M2265 790 V825','deploy',false,false);
[545,685,825].forEach(y=>e(`M2265 ${y} H2360`,'deploy'));
t(2045,706,'Image deployment',16,c.deploy,600);

t(40,1120,'Repository configuration, not a live cloud audit.  Solid: application traffic · Dotted: DNS / authentication · Dashed: build / deployment.',17,c.muted,400,'start');
a.push('</svg>');

(async()=>{
  const svg=a.join('\n');
  fs.writeFileSync(path.join(__dirname,'fiscora-architecture-corrected-original.svg'),svg);
  const browser=await chromium.launch({headless:true});
  try{
    const page=await browser.newPage({viewport:{width:W,height:H},deviceScaleFactor:2});
    await page.setContent(`<style>body{margin:0}svg{display:block}</style>${svg}`);
    const bad=await page.locator('svg text').evaluateAll(nodes=>nodes.flatMap(n=>{
      const b=n.getBBox();const parent=n.closest('[data-box]');const rect=parent?.querySelector('rect');
      const x=rect?+rect.getAttribute('x'):0, y=rect?+rect.getAttribute('y'):0;
      const w=rect?+rect.getAttribute('width'):2760, h=rect?+rect.getAttribute('height'):1140;
      return b.x<x||b.x+b.width>x+w||b.y<y||b.y+b.height>y+h?[n.textContent]:[];
    }));
    if(bad.length)throw Error(`Clipped labels: ${JSON.stringify(bad)}`);
    await page.screenshot({path:path.join(__dirname,'fiscora-architecture-corrected-original.png'),fullPage:true});
    console.log('Corrected original overview exported: SVG + 5520 × 2280 PNG. Text bounds verified.');
  }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
