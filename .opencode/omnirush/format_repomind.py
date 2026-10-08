from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from copy import deepcopy
import xml.etree.ElementTree as ET
import io

base = Path('.opencode/omnirush/inbox/chat-attachments/ses_ef457fadaffeq1sD6OwS2XMC4J')
source = next(base.glob('*RepoMind*'))
reference = next(base.glob('*Sage*'))
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
ns = {'w': W}
def tag(name): return '{' + W + '}' + name
def parse(data):
    for _, pair in ET.iterparse(io.BytesIO(data), events=['start-ns']):
        prefix, uri = pair
        if not prefix.startswith('ns'): ET.register_namespace(prefix, uri)
    return ET.fromstring(data)
def setprop(parent, name, attrs):
    for old in list(parent):
        if old.tag == tag(name): parent.remove(old)
    el = ET.SubElement(parent, tag(name))
    for k, v in attrs.items(): el.set(tag(k), str(v))
    return el
def props(parent, name):
    result = parent.find('w:' + name, ns)
    if result is None:
        result = ET.Element(tag(name)); parent.insert(0, result)
    return result
def text(root): return [x.text for x in root.iter(tag('t'))]

with ZipFile(source) as z: files = {i.filename: z.read(i.filename) for i in z.infolist()}
with ZipFile(reference) as z:
    refdoc = parse(z.read('word/document.xml'))
    refstyles = parse(z.read('word/styles.xml'))
doc = parse(files['word/document.xml'])
before = text(doc)
styles = parse(files['word/styles.xml'])
ids = {s.get(tag('styleId')): s for s in styles.findall('w:style', ns)}
for s in refstyles.findall('w:style', ns):
    sid = s.get(tag('styleId'))
    if sid in ids: styles.remove(ids[sid]); styles.append(deepcopy(s))
defaults = styles.find('w:docDefaults', ns)
if defaults is not None: styles.remove(defaults)
styles.insert(0, deepcopy(refstyles.find('w:docDefaults', ns)))
refsections = refdoc.findall('.//w:sectPr', ns)
geometry = refsections[0]
bodygeometry = refsections[-1]
for i, section in enumerate(doc.findall('.//w:sectPr', ns)):
    template = geometry if i == 0 else bodygeometry
    for name in ['pgSz', 'pgMar']:
        existing = section.find('w:' + name, ns)
        if existing is not None: section.remove(existing)
        section.append(deepcopy(template.find('w:' + name, ns)))

cover = True
for p in doc.findall('w:body/w:p', ns):
    pp = props(p, 'pPr')
    value = ''.join(x.text or '' for x in p.findall('.//w:t', ns)).strip()
    st = pp.find('w:pStyle', ns)
    sid = st.get(tag('val')) if st is not None else 'Normal'
    heading = sid.startswith('Heading') or sid == 'Title'
    islist = pp.find('w:numPr', ns) is not None
    special = bool(p.findall('.//w:drawing', ns)) or '\t' in value
    for name in ['spacing', 'ind', 'jc']:
        for el in list(pp):
            if el.tag == tag(name) and not special: pp.remove(el)
    if not special:
        setprop(pp, 'spacing', {'before': 120 if heading else 0, 'after': 120 if heading or cover else 160, 'line': 276 if cover else 360, 'lineRule': 'auto'})
        setprop(pp, 'jc', {'val': 'center' if cover or sid in ['Heading1', 'Title'] else ('left' if heading else 'both')})
        setprop(pp, 'ind', {'left': 720 if islist else 0, 'right': 0, **({'hanging': 360} if islist else {'firstLine': 720 if not heading and not cover and len(value)>180 else 0})})
    size = 34 if sid == 'Title' else 28 if heading else 24
    for rp in [props(pp, 'rPr')] + [props(r, 'rPr') for r in p.findall('.//w:r', ns)]:
        setprop(rp, 'rFonts', {'ascii': 'Times New Roman', 'hAnsi': 'Times New Roman', 'eastAsia': 'Times New Roman', 'cs': 'Times New Roman'})
        setprop(rp, 'sz', {'val': size}); setprop(rp, 'szCs', {'val': size})
        for name in ['spacing', 'w', 'position']:
            for el in list(rp):
                if el.tag == tag(name): rp.remove(el)
        if heading: setprop(rp, 'b', {})
    if pp.find('w:sectPr', ns) is not None: cover = False
assert before == text(doc), 'Content changed'
files['word/document.xml'] = ET.tostring(doc, encoding='utf-8', xml_declaration=True)
files['word/styles.xml'] = ET.tostring(styles, encoding='utf-8', xml_declaration=True)
output = Path('RepoMind_Sage_Format.docx')
with ZipFile(output, 'w', ZIP_DEFLATED) as z:
    for name, data in files.items(): z.writestr(name, data)
with ZipFile(output) as z:
    assert z.testzip() is None
    assert text(parse(z.read('word/document.xml'))) == before
    for name, data in files.items():
        if name.endswith('.xml'): ET.fromstring(z.read(name))
print(f'Created {output}; verified {len(before)} text nodes unchanged and DOCX archive/XML integrity.')
