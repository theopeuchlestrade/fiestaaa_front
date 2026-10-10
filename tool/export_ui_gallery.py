"""Refresh embedded review images after Flutter's UI_REVIEW_EXPORT run."""
import base64
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
folder = root / 'docs/ui-harmonization'
preview = folder / 'preview.html'
content = preview.read_text()
count = 0
for mobile in sorted((folder / 'renders').glob('*_360_light_fr.png')):
    screen = mobile.name.removesuffix('_360_light_fr.png')
    match = re.search(r'(<section id="' + re.escape(screen) + r'">)(.*?)(</section>)', content, re.S)
    if match is None:
        raise ValueError(f'Missing gallery section: {screen}')
    images = iter([mobile, mobile.with_name(screen + '_1440_dark_fr.png')])
    def replace_image(_):
        data = base64.b64encode(next(images).read_bytes()).decode()
        return f'src="data:image/png;base64,{data}"'
    block, replaced = re.subn(r'src="data:image/png;base64,[^"]+"', replace_image, match.group(2))
    if replaced != 2:
        raise ValueError(f'Expected two images: {screen}')
    content = content[:match.start(2)] + block + content[match.end(2):]
    count += 1
if count != 18:
    raise ValueError(f'Expected 18 screens, found {count}')
preview.write_text(content)
print(f'Refreshed {count * 2} embedded renders.')
