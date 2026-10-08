import runpy
from copy import deepcopy
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import re

env = runpy.run_path('.opencode/omnirush/format_repomind.py')
ET, ns, tag = env['ET'], env['ns'], env['tag']
props, setprop = env['props'], env['setprop']
files, doc = env['files'], env['doc']
body = doc.find('w:body', ns)
def txt(p): return ''.join(t.text or '' for t in p.findall('.//w:t', ns))
original_text = ''.join(txt(p) for p in doc.findall('.//w:p', ns))
def formatp(p, align='both', size=24, bold=False, first=0, before=0, after=160, line=360):
    pp = props(p, 'pPr')
    for name in ['tabs', 'ind', 'spacing', 'jc', 'rPr']:
        for e in list(pp):
            if e.tag == tag(name): pp.remove(e)
    setprop(pp, 'ind', {'left': 0, 'right': 0, 'firstLine': first})
    setprop(pp, 'spacing', {'before': before, 'after': after, 'line': line, 'lineRule': 'auto'})
    setprop(pp, 'jc', {'val': align})
    setprop(pp, 'widowControl', {})
    for run in p.findall('.//w:r', ns):
        rp = props(run, 'rPr')
        setprop(rp, 'rFonts', {'ascii': 'Times New Roman', 'hAnsi': 'Times New Roman', 'eastAsia': 'Times New Roman', 'cs': 'Times New Roman'})
        setprop(rp, 'sz', {'val': size}); setprop(rp, 'szCs', {'val': size})
        for name in ['spacing', 'w', 'position']:
            for e in list(rp):
                if e.tag == tag(name): rp.remove(e)
        if bold: setprop(rp, 'b', {})
    return pp

front = {'ACKNOWLEDGEMENT', 'ABSTRACT', 'LIST OF FIGURES', 'LIST OF ABBREVIATIONS', 'TABLE OF CONTENTS', 'REFERENCES'}
cover = True
# Use the reference's name/register tabbed-row layout instead of a table.
cover_table = body.find('w:tbl', ns)
index = list(body).index(cover_table)
for ri, row in enumerate(cover_table.findall('w:tr', ns)):
    new = ET.Element(tag('p'))
    cells = row.findall('w:tc', ns)
    for ci, cell in enumerate(cells):
        if ci:
            run = ET.SubElement(new, tag('r')); ET.SubElement(run, tag('tab'))
        for p in cell.findall('w:p', ns):
            for run in p.findall('w:r', ns): new.append(deepcopy(run))
    pp = formatp(new, 'left', 24, True, 0, 0, 120, 276)
    setprop(pp, 'ind', {'left':600, 'right':0, 'firstLine':0})
    tabs = setprop(pp, 'tabs', {})
    setprop(tabs, 'tab', {'val':'right', 'pos':10200})
    body.insert(index+ri, new)
body.remove(cover_table)
for p in body.findall('w:p', ns):
    t = txt(p).strip()
    pp = props(p, 'pPr'); st = pp.find('w:pStyle', ns)
    sid = st.get(tag('val')) if st is not None else ''
    num = pp.find('w:numPr', ns)
    chapter = t.startswith('CHAPTER ')
    heading = sid.startswith('Heading') and len(t)<150
    caption = t.startswith('Figure ')
    centered = cover or chapter or t in front or t.startswith('APPENDIX ')
    formatp(p, 'center' if centered or caption else 'left' if heading or num is not None else 'both',
            34 if sid=='Title' else 28 if heading or chapter or t in front else 24,
            heading or chapter or t in front, 720 if not centered and not heading and num is None and len(t)>180 else 0,
            120 if heading or chapter else 0, 120 if centered or heading else 160, 276 if cover else 360)
    if heading or chapter or caption: setprop(pp, 'keepNext', {})
    if chapter or t in front: setprop(pp, 'pageBreakBefore', {})
    if num is not None:
        setprop(pp, 'ind', {'left': 720, 'right': 0, 'hanging': 360})
    section = pp.find('w:sectPr', ns)
    if section is not None: cover = False

for p in body.findall('w:p', ns):
    if p.find('.//w:tab', ns) is not None and 'REGISTER' in txt(p):
        text = txt(p); name, register = text.split('REGISTER', 1)
        for child in list(p): p.remove(child)
        run = ET.SubElement(p, tag('r')); t = ET.SubElement(run, tag('t'))
        t.set('{http://www.w3.org/XML/1998/namespace}space','preserve')
        t.text = name + ' ' * max(50, 94-len(name)) + 'REGISTER' + register
        formatp(p, 'center', 24, True, 0, 0, 120, 276)

# Eliminate extracted page geometry and spurious newspaper-style columns.
for section in doc.findall('.//w:sectPr', ns):
    setprop(section, 'pgSz', {'w': 12240, 'h': 15840})
    setprop(section, 'pgMar', {'top': 1080, 'bottom': 1080, 'left': 720, 'right': 720, 'header': 432, 'footer': 504, 'gutter': 0})
    setprop(section, 'cols', {'num': 1, 'space': 720})
    setprop(section, 'type', {'val': 'continuous'})

# Match Sage's wide name/register-number rows; format every table cell,
# rather than letting old direct formatting override the new styles.
tables = body.findall('w:tbl', ns)
for ti, table in enumerate(tables):
    tp = props(table, 'tblPr')
    setprop(tp, 'jc', {'val': 'center'})
    setprop(tp, 'tblInd', {'w': 0, 'type': 'dxa'})
    grid = table.find('w:tblGrid', ns)
    columns = list(grid) if grid is not None else []
    oldwidths = [int(c.get(tag('w'), '1')) for c in columns]
    width = 10800 if ti in [2, 4] else min(10800, max(9000, sum(oldwidths)))
    setprop(tp, 'tblW', {'w': width, 'type': 'dxa'})
    total = sum(oldwidths) or 1
    widths = [round(width*x/total) for x in oldwidths]
    if widths: widths[-1] += width-sum(widths)
    for c, w in zip(columns, widths): c.set(tag('w'), str(w))
    margins = setprop(tp, 'tblCellMar', {})
    for side in ['top','bottom','left','right']: setprop(margins, side, {'w': 60 if side in ['top','bottom'] else 100, 'type':'dxa'})
    for ri, row in enumerate(table.findall('w:tr', ns)):
        trp = props(row, 'trPr')
        for height in trp.findall('w:trHeight', ns): trp.remove(height)
        setprop(trp, 'cantSplit', {})
        for ci, cell in enumerate(row.findall('w:tc', ns)):
            cp = props(cell, 'tcPr')
            if ci<len(widths): setprop(cp, 'tcW', {'w': widths[ci], 'type':'dxa'})
            setprop(cp, 'vAlign', {'val':'center'})
            for p in cell.findall('w:p', ns):
                formatp(p, 'left', 24, False, 0, 0, 80, 276)

def split_cover(p, markers):
    text = txt(p)
    offsets = sorted([text.index(m) for m in markers if m in text])
    chunks = [text[a:b] for a,b in zip([0]+offsets, offsets+[len(text)])]
    idx = list(body).index(p)
    body.remove(p)
    for offset, chunk in enumerate(chunks):
        new = ET.Element(tag('p'))
        run = ET.SubElement(new, tag('r')); t = ET.SubElement(run, tag('t'))
        t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve'); t.text = chunk
        formatp(new, 'center', 24, True, 0, 0, 120, 276)
        if ' BONAFIDE CERTIFICATE' in markers and offset == 0:
            setprop(props(new, 'pPr'), 'pageBreakBefore', {})
            setprop(props(new, 'pPr'), 'keepNext', {})
        body.insert(idx+offset, new)

for p in list(body.findall('w:p', ns))[:20]:
    text = txt(p)
    if 'DEPARTMENT OF ARTIFICIAL' in text and ' SRI MANAKULA' in text:
        split_cover(p, [' SRI MANAKULA'])
    elif '(An Autonomous Institution)' in text:
        split_cover(p, [' MADAGADIPET', ' OCTOBER'])
for p in body.findall('w:p', ns):
    t = txt(p).strip()
    if 'BONAFIDE CERTIFICATE' in t:
        split_cover(p, [' BONAFIDE CERTIFICATE'])
    if t in ['UNDER THE GUIDANCE OF', 'in partial fulfillment of the requirements for the degree of']:
        setprop(props(p, 'pPr'), 'spacing', {'before': 240, 'after':120, 'line':276, 'lineRule':'auto'})
    if t=='PROJECT REPORT – PHASE I': formatp(p, 'center', 24, True, 0, 0, 120, 276)
    if t=='Mr. R. Rajan': formatp(p, 'center', 28, True, 0, 0, 120, 276)

for p in body.findall('w:p', ns):
    t = txt(p).strip()
    if t=='DEPARTMENT OF ARTIFICIAL INTELLIGENCE AND DATA SCIENCE' and list(body).index(p)>20:
        setprop(props(p, 'pPr'), 'pageBreakBefore', {})
        setprop(props(p, 'pPr'), 'keepNext', {})
    if t=='BONAFIDE CERTIFICATE':
        setprop(props(p, 'pPr'), 'spacing', {'before':360, 'after':360, 'line':360, 'lineRule':'auto'})
    if t.startswith('REPOMIND:'):
        setprop(props(p, 'pPr'), 'spacing', {'before':240, 'after':120, 'line':276, 'lineRule':'auto'})

# The source places BACKGROUND before the chapter title. Keep all words,
# but put that heading after the title where it belongs.
children = list(body)
for i, p in enumerate(children):
    if txt(p).strip().startswith('CHAPTER 1'):
        preceding = next((q for q in reversed(children[:i]) if txt(q).strip()), None)
        if preceding is not None and txt(preceding).strip()=='BACKGROUND':
            body.remove(preceding)
            body.insert(list(body).index(p)+1, preceding)
        break

from collections import Counter
newtext = ''.join(txt(p) for p in doc.findall('.//w:p', ns))
assert Counter(c for c in original_text if not c.isspace()) == Counter(c for c in newtext if not c.isspace()), 'Report content changed'
files['word/document.xml'] = ET.tostring(doc, encoding='utf-8', xml_declaration=True)
output = Path('RepoMind_Sage_Format_v2.docx')
with ZipFile(output, 'w', ZIP_DEFLATED) as z:
    for name, data in files.items(): z.writestr(name, data)
with ZipFile(output) as z:
    assert z.testzip() is None
    for name in z.namelist():
        if name.endswith('.xml'): ET.fromstring(z.read(name))
print(f'Created {output}; content token counts preserved; {len(tables)} tables repaired; all sections single-column.')
