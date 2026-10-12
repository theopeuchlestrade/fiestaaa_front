import { chromium } from 'playwright';
import { writeFile } from 'node:fs/promises';
const [url, output] = process.argv.slice(2);
if (!url || !output || !/^http:\/\/127\.0\.0\.1:/.test(url)) throw new Error('Use a loopback fixture URL and output path');
const browser = await chromium.launch({channel:'chrome'});
try {
  const page = await browser.newPage({viewport:{width:390,height:844}});
  const result = new Promise((resolve,reject)=> {
    const timeout = setTimeout(()=>reject(new Error('Benchmark timeout')),120000);
    page.on('console',msg=> {
      if(msg.text().startsWith('FIESTAAA_BENCHMARK ')) {clearTimeout(timeout);resolve(JSON.parse(msg.text().slice('FIESTAAA_BENCHMARK '.length)));}
      if(msg.text().startsWith('FIESTAAA_BENCHMARK_ERROR')) {clearTimeout(timeout);reject(new Error(msg.text()));}
    });
    page.on('pageerror',error=>{clearTimeout(timeout);reject(error);});
  });
  page.on('console', msg => { if (msg.type() === 'error') console.error(msg.text()); });
  page.on('requestfailed', req => console.error('request failed:', req.url()));
  await page.goto(url);
  const data=await result;
  await writeFile(output,JSON.stringify({...data,platform:'headless Chromium',mode:'Flutter web release',viewport:'390x844'},null,2)+'\n');
  for(const flow of [...new Set(data.samples.map(s=>s.flow))]) {
    const rows=data.samples.filter(s=>s.flow===flow);
    const sorted=rows.map(s=>s.microseconds/1000).sort((a,b)=>a-b);
    console.log(flow,JSON.stringify({n:rows.length,p50:sorted[Math.ceil(rows.length*.5)-1],p95:sorted[Math.ceil(rows.length*.95)-1],requests:rows.map(s=>s.requestCount)}));
  }
} finally {await browser.close();}
