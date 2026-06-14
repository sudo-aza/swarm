import ZAI from 'z-ai-web-dev-sdk';
import fs from 'fs';
import path from 'path';

const PROMPT = `This is a page from a LaTeX document compiled with swarmwrap, a package that should make body text wrap AROUND figures (like newspaper layout - text flows around the figure's shape).
CRITICALLY evaluate this page:
1) Is text actually wrapping around figures, or are figures just floating separately?
2) Any text overlaps, text printed on top of figures, or ugly gaps?
3) Is the typography good - consistent spacing, proper alignment, professional look?
4) Rate visual quality 1-10. Be BRUTALLY honest. If it looks amateurish, say so.`;

async function main() {
  const zai = await ZAI.create();
  
  const files = [
    '50-page-p0001.png', '50-page-p0005.png', '50-page-p0010.png',
    '50-page-p0015.png', '50-page-p0020.png', '50-page-p0025.png',
    '50-page-p0027.png', '50-page-p0030.png', '50-page-p0035.png',
    '50-page-p0040.png', '50-page-p0045.png', '50-page-p0050.png',
  ];

  const results = [];

  for (const f of files) {
    const fp = path.join('/home/z/my-project/download/pdf-pages', f);
    const imgBuf = fs.readFileSync(fp);
    const b64 = imgBuf.toString('base64');
    
    try {
      const resp = await zai.chat.completions.createVision({
        messages: [{
          role: 'user',
          content: [
            { type: 'text', text: PROMPT },
            { type: 'image_url', image_url: { url: `data:image/png;base64,${b64}` } }
          ]
        }],
        thinking: { type: 'disabled' }
      });
      const content = resp.choices[0]?.message?.content || 'NO RESPONSE';
      results.push({ file: f, analysis: content });
      console.log(`\n=== ${f} ===`);
      console.log(content);
    } catch (e) {
      results.push({ file: f, error: e.message });
      console.error(`${f}: ERROR - ${e.message}`);
    }
  }

  // Save results
  fs.writeFileSync('/home/z/my-project/download/pdf-pages/vlm-50page-results.json', JSON.stringify(results, null, 2));
  console.log('\n\nResults saved to vlm-50page-results.json');
}

main().catch(console.error);
