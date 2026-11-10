#!/usr/bin/env python3
"""Build an offline lexicon from the curated Chinese glossary + Verbiste 0.1.49.
No machine-learning prediction or runtime network calls are used.
"""
import json
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMPLATES = {x.attrib['name']: x for x in ET.parse(ROOT / 'vendor/conjugation-fr.xml').getroot()}
VERBS = {x.findtext('i'): x.findtext('t') for x in ET.parse(ROOT / 'vendor/verbs-fr.xml').getroot()}
SIMPLE = {
    'present': 'indicative/present', 'imperfect': 'indicative/imperfect',
    'future': 'indicative/future', 'simplePast': 'indicative/simple-past',
    'conditionalPresent': 'conditional/present', 'subjunctivePresent': 'subjunctive/present',
    'subjunctiveImperfect': 'subjunctive/imperfect', 'imperativePresent': 'imperative/imperative-present',
}
COMPOUND = {
    'perfect': 'present', 'pluperfect': 'imperfect', 'futurePerfect': 'future',
    'pastAnterior': 'simplePast', 'conditionalPast': 'conditionalPresent',
    'subjunctivePast': 'subjunctivePresent', 'subjunctivePluperfect': 'subjunctiveImperfect',
    'imperativePast': 'imperativePresent',
}
ETRE = set('aller venir revenir devenir parvenir intervenir survenir advenir arriver partir repartir sortir ressortir rentrer entrer retourner monter remonter descendre redescendre tomber retomber rester passer repasser naître renaître mourir décéder apparaître réapparaître convenir'.split())
# These verbs also take avoir in their transitive sense (e.g. j'ai sorti la voiture).
BOTH = set('sortir ressortir rentrer retourner monter remonter descendre redescendre passer repasser apparaître réapparaître convenir'.split())
COUNTS = {'basic':21, 'beginner':66, 'intermediate1':68, 'intermediate2':162, 'advanced':459}


def raw_forms(verb, path):
    template = VERBS[verb]
    ending = template.split(':')[1]
    stem = verb[:-len(ending)] if ending else verb
    node = TEMPLATES[template].find(path)
    if node is None:
        return []
    return [[stem + (i.text or '') for i in p.findall('i')] for p in node.findall('p')]


def forms(verb):
    result = {}
    for key, path in SIMPLE.items():
        slots = raw_forms(verb, path)
        if key == 'imperativePresent':
            slots = [[], slots[0], [], slots[1], slots[2], []]
        result[key] = slots
    participles = raw_forms(verb, 'participle/past-participle')
    for tense, aux_tense in COMPOUND.items():
        slots = []
        for person in range(6):
            candidates = []
            # Respect defective and impersonal verbs, including falloir and pleuvoir.
            if not result['present'][person] or (aux_tense == 'imperativePresent' and person not in (1,3,4)):
                slots.append([])
                continue
            auxiliaries = ['être'] if verb in ETRE else ['avoir']
            if verb in BOTH:
                auxiliaries.append('avoir')
            for auxiliary in auxiliaries:
                aux_slots = raw_forms(auxiliary, SIMPLE[aux_tense])
                if aux_tense == 'imperativePresent':
                    aux_slots = [[],aux_slots[0],[],aux_slots[1],aux_slots[2],[]]
                if auxiliary == 'avoir':
                    pp = participles[0]
                else:
                    indices = (0,2) if person < 3 else ((0,1,2,3) if person == 4 else (1,3))
                    pp = [p for i in indices for p in participles[i]]
                for a in aux_slots[person]:
                    candidates.extend(a + ' ' + p for p in pp)
            slots.append(list(dict.fromkeys(candidates)))
        result[tense] = slots
    return result


def main():
    levels = {key: [] for key in COUNTS}
    curated = []
    seen = set()
    section = None
    for line in (ROOT / 'scripts/lexicon.txt').read_text().splitlines():
        if line.startswith('#') or not line.strip():
            continue
        if line.startswith('['):
            section = line[1:-1]
            continue
        for item in line.split(';'):
            if '=' not in item:
                continue
            infinitive, meaning = item.strip().split('=', 1)
            if infinitive in seen or infinitive not in VERBS or infinitive in ('abstenir','enfuir','méfier','exclamer'):
                continue
            seen.add(infinitive)
            template = VERBS[infinitive]
            if infinitive.endswith('er') and infinitive not in ('aller','envoyer','renvoyer'):
                group = 'er'
            elif template == 'fin:ir':
                group = 'ir'
            elif template == 'ten:dre':
                group = 're'
            else:
                group = 'irregular'
            curated.append({'id': infinitive, 'meaning': meaning,
                                    'group': group, 'forms': forms(infinitive)})
    offset = 0
    for key, count in COUNTS.items():
        levels[key] = [dict(v, level=key) for v in curated[offset:offset+count]]
        offset += count
    for key, expected in COUNTS.items():
        assert len(levels[key]) == expected, (key,len(levels[key]))
    all_verbs = [v for level in levels.values() for v in level]
    assert len({v['id'] for v in all_verbs}) == 776
    for v in all_verbs:
        assert len(v['forms']) == 16
        assert all(len(slots) == 6 for slots in v['forms'].values()), v['id']
    path = ROOT / 'Sources/Conjugation/Resources/verbs.json'
    path.write_text(json.dumps(all_verbs, ensure_ascii=False, separators=(',',':')))
    print(f'Generated {len(all_verbs)} verbs, 16 tenses, {path.stat().st_size:,} bytes')
    for key, values in levels.items():
        print(f'  {key}: {len(values)}')

if __name__ == '__main__':
    main()
