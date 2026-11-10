#!/usr/bin/env python3
"""Bundle Apache-2.0 Google Material icons for SF Symbols missing from Skip."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import shutil
import urllib.request
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
assets = root / 'Sources/Conjugation/Resources/Module.xcassets'
icons = {
    'arrow.clockwise': ('navigation', 'refresh'),
    'arrow.triangle.2.circlepath': ('navigation', 'refresh'),
    'book': ('maps', 'menu_book'),
    'circle': ('toggle', 'radio_button_unchecked'),
    'clock': ('device', 'access_time'),
    'dice': ('places', 'casino'),
    'doc.on.doc': ('content', 'content_copy'),
    'doc.text.magnifyingglass': ('action', 'find_in_page'),
    'ellipsis.circle': ('navigation', 'more_horiz'),
    'ellipsis.circle.fill': ('navigation', 'more_horiz'),
    'eyeglasses': ('action', 'visibility'),
    'headphones': ('hardware', 'headphones'),
    'keyboard.chevron.compact.down': ('hardware', 'keyboard_hide'),
    'list.number': ('editor', 'format_list_numbered'),
    'person.2': ('social', 'people_outline'),
    'shuffle': ('av', 'shuffle'),
    'slider.horizontal.3': ('image', 'tune'),
    'speaker.wave.2': ('av', 'volume_up'),
    'star': ('toggle', 'star_border'),
    'switch.2': ('action', 'swap_horiz'),
    'xmark.circle.fill': ('navigation', 'cancel'),
}
base = 'https://raw.githubusercontent.com/google/material-design-icons/master/'

def generate(item):
    name, (category, icon) = item
    folder = assets / f'android-{name}.symbolset'
    folder.mkdir(parents=True, exist_ok=True)
    svg = folder / f'{icon}.svg'
    old_folder = assets / f'android-{name}.imageset'
    old_svg = old_folder / svg.name
    if svg.exists():
        return name
    if old_svg.exists():
        original = old_svg.read_bytes()
    else:
        with urllib.request.urlopen(base + f'src/{category}/{icon}/materialicons/24px.svg', timeout=40) as response:
            original = response.read()
    # Skip sizes symbolset paths from the current font. Ordinary SVG images use
    # Coil's decoded size, which can expand to the entire viewport in a stack.
    document = ET.fromstring(original)
    paths = ''.join(ET.tostring(node, encoding='unicode').replace('ns0:', '').replace(':ns0', '')
                    for node in document.iter() if node.tag.endswith('}path') and node.get('fill') != 'none')
    svg.write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">'
                   '<g id="Symbols"><g id="Regular-M">' + paths + '</g></g></svg>')
    (folder / 'Contents.json').write_text(json.dumps({'symbols': [{'filename': svg.name, 'idiom': 'universal'}], 'info': {'author': 'xcode', 'version': 1}}, indent=2))
    if old_folder.exists(): shutil.rmtree(old_folder)
    return name

with ThreadPoolExecutor(max_workers=6) as pool:
    for name in pool.map(generate, icons.items()): print(name)
license_file = root / 'Sources/Conjugation/Resources/MaterialIcons-LICENSE.txt'
if not license_file.exists():
    with urllib.request.urlopen(base + 'LICENSE', timeout=40) as response:
        license_file.write_bytes(response.read())
(root / 'Sources/Conjugation/Resources/MaterialIcons-NOTICE.txt').write_text('Google Material Design Icons\nCopyright Google LLC\nLicensed under the Apache License, Version 2.0.\nhttps://github.com/google/material-design-icons\n')
