import csv, datetime, json, math, os, statistics, subprocess, sys, threading, time
from pathlib import Path
BASE=Path(__file__).parent
label=sys.argv[1]
out=BASE/(label+'-'+datetime.datetime.now().strftime('%Y%m%dT%H%M%S'))
out.mkdir()
proc=Path('/proc')
def find_processes():
 groups={k:[] for k in ['shell','hyprland','floorp']}
 for p in proc.glob('[0-9]*'):
  try: exe=str((p/'exe').resolve())
  except OSError: continue
  key='shell' if 'quickshell' in exe else 'hyprland' if 'Hyprland' in exe else 'floorp' if 'floorp' in exe else None
  if key: groups[key].append(int(p.name))
 return groups
groups=find_processes()
assert groups['shell'] and groups['hyprland'] and groups['floorp'],groups
env=dict(os.environ)
for item in (proc/str(groups['shell'][0])/'environ').read_bytes().split(b'\0'):
 if b'=' in item:
  k,v=item.split(b'=',1); env[k.decode()]=v.decode()
hypr='/run/current-system/sw/bin/hyprctl'
shell='/etc/profiles/per-user/hutao/bin/caelestia-shell'
def run(args):
 r=subprocess.run(args,env=env,capture_output=True,text=True,timeout=8)
 if r.returncode: raise RuntimeError(str(args)+': '+r.stderr+r.stdout)
 return r.stdout.strip()
def hjson(name):return json.loads(run([hypr,'-j',name]))
monitors=hjson('monitors'); clients=hjson('clients')
focus=next(m for m in monitors if m['focused']); original=focus['activeWorkspace']['id']
occupied={w['id'] for w in hjson('workspaces')}
spare=next(w for w in range(1,10) if w not in occupied)
for drawer in ['launcher','dashboard']:
 assert run([shell,'ipc','call','drawers','isOpen',drawer])=='0', 'Close '+drawer+' before measuring'
metadata={'label':label,'started':datetime.datetime.now().astimezone().isoformat(),'groups':groups,'monitors':monitors,'clients':[{k:c.get(k) for k in ['class','workspace','monitor']} for c in clients], 'graphics_env':{k:v for k,v in env.items() if k.startswith(('QSG_','QT_QUICK','QT_QPA'))},'original_workspace':original,'spare_workspace':spare,'sampling_seconds':0.5,'cpu_units':'percent of one logical CPU; 100 = one full core','note':'No video capture; counters do not measure frame times. Same background apps required for comparison.'}
metadata['shell_graphics_libraries']=sorted({l.split()[-1] for l in (proc/str(groups['shell'][0])/'maps').read_text().splitlines() if any(k in l for k in ['libEGL','libgallium','libvulkan','libQt6OpenGL'])})
(out/'metadata.json').write_text(json.dumps(metadata,indent=2))
gpu=Path('/sys/class/drm/card1/device'); hwmon=next((gpu/'hwmon').glob('hwmon*'))
def val(path,scale=1):
 try:return float(path.read_text().strip())/scale
 except (OSError,ValueError):return None
hz=os.sysconf('SC_CLK_TCK'); page=os.sysconf('SC_PAGE_SIZE')
def stats(pids):
 ticks=0; rss=0
 for pid in pids:
  try:
   s=(proc/str(pid)/'stat').read_text().rsplit(')',1)[1].split()
   ticks+=int(s[11])+int(s[12]); rss+=int(s[21])*page
  except OSError:pass
 return ticks,rss/1048576
phase='idle_before'; stop=threading.Event(); samples=[]; actions=[]; start=time.monotonic()
def sampler():
 previous={k:stats(pids)[0] for k,pids in groups.items()}; last=time.monotonic()
 with (out/'samples.csv').open('w') as f:
  fields=['elapsed_s','phase','shell_cpu_pct','hyprland_cpu_pct','floorp_cpu_pct','shell_rss_mib','hyprland_rss_mib','floorp_rss_mib','gpu_busy_pct','vram_mib','gtt_mib','gpu_power_w','gpu_temp_c']
  writer=csv.DictWriter(f,fieldnames=fields); writer.writeheader()
  while not stop.wait(0.5):
   now=time.monotonic(); dt=now-last; row={'elapsed_s':round(now-start,3),'phase':phase}
   for k,pids in groups.items():
    ticks,rss=stats(pids); row[k+'_cpu_pct']=round((ticks-previous[k])/hz/dt*100,3); row[k+'_rss_mib']=round(rss,3); previous[k]=ticks
   last=now
   for name,path,scale in [('gpu_busy_pct',gpu/'gpu_busy_percent',1),('vram_mib',gpu/'mem_info_vram_used',1048576),('gtt_mib',gpu/'mem_info_gtt_used',1048576),('gpu_power_w',hwmon/'power1_average',1e6),('gpu_temp_c',hwmon/'temp1_input',1000)]:row[name]=val(path,scale)
   writer.writerow(row); f.flush(); samples.append(row)
def action(args,description):
 t=time.monotonic(); result=run(args); actions.append({'elapsed_s':round(t-start,3),'action':description,'response':result})
thread=threading.Thread(target=sampler); thread.start()
print('Recording',out,flush=True)
try:
 time.sleep(10)
 for drawer in ['launcher','dashboard']:
  phase=drawer
  for _ in range(6):
   action([shell,'ipc','call','drawers','toggle',drawer],drawer+' toggle'); time.sleep(2)
 phase='workspaces'
 for w in [spare,original]*3:
  action([hypr,'dispatch',f'hl.dsp.focus({{ workspace = {w} }})'],f'workspace {w}'); time.sleep(2)
 phase='idle_after'; time.sleep(10)
finally:
 stop.set();thread.join()
 for drawer in ['launcher','dashboard']:
  if run([shell,'ipc','call','drawers','isOpen',drawer])=='1':run([shell,'ipc','call','drawers','toggle',drawer])
 run([hypr,'dispatch',f'hl.dsp.focus({{ workspace = {original} }})'])
 (out/'actions.json').write_text(json.dumps(actions,indent=2))
summary={}
for ph in dict.fromkeys(s['phase'] for s in samples):
 rows=[s for s in samples if s['phase']==ph]; summary[ph]={'samples':len(rows)}
 for k in rows[0]:
  if k in ['elapsed_s','phase']:continue
  vs=sorted(r[k] for r in rows if r[k] is not None)
  if vs: summary[ph][k]={'mean':round(statistics.mean(vs),3),'p95':round(vs[math.ceil(len(vs)*.95)-1],3),'max':round(max(vs),3)}
(out/'summary.json').write_text(json.dumps(summary,indent=2))
print(json.dumps({'directory':str(out),'summary':summary},indent=2),flush=True)
