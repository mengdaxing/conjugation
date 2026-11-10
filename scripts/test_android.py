#!/usr/bin/env python3
"""Smoke-test the packaged Swift app on an explicitly selected Android emulator."""
import argparse
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

parser=argparse.ArgumentParser()
parser.add_argument('--serial',required=True)
parser.add_argument('--core',action='store_true',help='Run native Swift core/persistence checks in a debug APK')
args=parser.parse_args()
if not args.serial.startswith('emulator-'): raise SystemExit('Use a disposable emulator for these UI tests.')
app='com.personal.frenchconjugation'
activity=app+'/conjugation.module.MainActivity'
root=Path(__file__).resolve().parents[1]
shots=root/'docs/android';shots.mkdir(parents=True,exist_ok=True)

def adb(*cmd,binary=False,timeout=40):
    result=subprocess.run(['adb','-s',args.serial,*cmd],capture_output=True,text=not binary,check=True,timeout=timeout)
    return result.stdout

def launch(*extra):
    adb('shell','am','force-stop',app)
    adb('shell','am','start','-W','-n',activity,*extra)

def hierarchy():
    adb('shell','uiautomator','dump','/sdcard/french-verbs-window.xml')
    return ET.fromstring(adb('exec-out','cat','/sdcard/french-verbs-window.xml'))

def find(identifier=None,text=None,description=None):
    for node in hierarchy().iter('node'):
        if identifier is not None and node.get('resource-id')!=identifier: continue
        if text is not None and node.get('text')!=text: continue
        if description is not None and node.get('content-desc')!=description: continue
        return node
    return None

def wait(identifier=None,text=None,description=None,seconds=30):
    deadline=time.monotonic()+seconds
    while time.monotonic()<deadline:
        node=find(identifier,text,description)
        if node is not None: return node
        time.sleep(0.5)
    raise AssertionError(f'Missing UI element: {identifier or text or description}')

def tap(identifier=None,text=None,description=None):
    node=wait(identifier,text,description)
    bounds=[int(value) for value in re.findall(r'\d+',node.get('bounds',''))]
    assert len(bounds)==4,bounds
    x1,y1,x2,y2=bounds
    assert x2>x1 and y2>y1,f'Element is outside the viewport: {identifier or text or description}'
    adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))

def screenshot(name):
    (shots/name).write_bytes(adb('exec-out','screencap','-p',binary=True))

# ATD images disable drawing by default; enable it for visual verification.
adb('shell','setprop','debug.hwui.drawing_enabled','true')
adb('shell','input','keyevent','KEYCODE_WAKEUP')
adb('shell','wm','dismiss-keyguard')

if args.core:
    for phase,expected in [('write','PASS write: 16 checks'),('read','PASS read: 24 checks')]:
        adb('logcat','-c')
        launch('--es','verifyCore',phase)
        deadline=time.monotonic()+30
        while time.monotonic()<deadline:
            logs=adb('logcat','-d','-s','FrenchVerbsVerification:I','*:S')
            if 'FAIL ' in logs: raise AssertionError(logs)
            if expected in logs:
                print(expected,flush=True)
                break
            time.sleep(1)
        else: raise AssertionError('Native verification did not finish: '+logs)
else:
    launch()

wait(identifier='verbSearch')
screenshot('01-home.png')
tap(identifier='verbSearch')
adb('shell','input','text','perdre')
tap(identifier='search.perdre')
wait(identifier='practiceVerb')
screenshot('02-reference.png')
tap(identifier='favoriteVerb')
tap(identifier='practiceVerb')
print('PASS Android search, reference and favorite',flush=True)
tap(identifier='answer.0')
adb('shell','input','text','perds')
tap(identifier='replicateAnswer')
screenshot('03a-keyboard-replicate.png')
assert 'mInputShown=true' in adb('shell','dumpsys','input_method'), 'Software keyboard did not appear'
tap(description='收起键盘')
for person in range(6):
    field=wait(identifier=f'answer.{person}')
    assert field.get('text')=='perds',(person,field.attrib)
screenshot('03-input-replicate.png')
print('PASS Android six inputs, replicate and software keyboard',flush=True)
tap(identifier='checkAnswers')
wait(identifier='correct.0')
wait(identifier='correct.1')
for person,expected in [(2,'perd'),(3,'perdons'),(4,'perdez'),(5,'perdent')]:
    correction=wait(identifier=f'correction.{person}')
    assert correction.get('text')==expected,correction.attrib
screenshot('04-feedback.png')
print('PASS Android scoring and four corrections',flush=True)
tap(identifier='retryQuestion')
field=wait(identifier='answer.0')
assert field.get('text')=='',field.attrib
tap(identifier='answer.0')
adb('shell','input','text','perds')
tap(identifier='replicateAnswer')
tap(description='收起键盘')
tap(identifier='checkAnswers')
tap(identifier='nextQuestion')
wait(text='本轮练习完成')
screenshot('05-complete.png')
print('PASS Android UI: search, reference, favorite, six inputs, replicate, scoring, corrections, retry, finish',flush=True)
# A process restart must retain the score and favorite from the UI flow.
launch()
wait(identifier='verbSearch')
tap(identifier='settings')
wait(text='累计正确')
assert find(text='2 次') is not None,'Retry was double-counted or score was not persisted'
assert find(text='1 个动词') is not None,'Favorite was not persisted'
screenshot('06-settings-after-restart.png')
print('PASS Android cold restart: score 2, favorite 1, retry does not add score',flush=True)
