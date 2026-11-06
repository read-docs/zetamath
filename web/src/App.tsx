import {lazy,Suspense,useEffect,useMemo,useState} from 'react';
import {useSession} from './hooks/useSession';
import CommandPalette from './components/CommandPalette';
import ModeBar from './components/ModeBar';
const LearnPage = lazy(() => import('./components/LearnPage'));
const Profile = lazy(() => import('./components/Profile'));
const Chart = lazy(() => import('./components/PaceChart'));
import SettingsPage from './components/SettingsPage';
import {BookIcon,GearIcon,KeyboardIcon,LogoMark,UserIcon} from './components/icons';
import {level} from './store/profile';

import {operations} from './engine/generator';
import {useSettings,type Settings} from './store/settings';
import {useHistory} from './store/history';
import {themes} from './themes';

export default function App(){
 const s=useSettings(),h=useHistory();
 const [page,setPage]=useState(location.pathname==='/history'?'/profile':location.pathname),[palette,setPalette]=useState<string|false>(false),[error,setError]=useState('');
 const {problem,input,elapsed,running,result,pb,score,field,config,restart,finish,answer,setResult}=useSession(setError);
 function go(p:string){if(running)finish();history.pushState({},'',p);setPage(p)}
 useEffect(()=>{void h.load();restart();const pop=()=>{finish();setPage(location.pathname==='/history'?'/profile':location.pathname)};window.addEventListener('popstate',pop);return()=>window.removeEventListener('popstate',pop)},[]);
 useEffect(()=>{const t=themes[s.theme]||themes.iceberg;Object.entries(t).forEach(([k,v])=>document.documentElement.style.setProperty('--'+k,v));document.documentElement.style.setProperty('--font',`"${s.font}", monospace`)},[s.theme,s.font]);

 useEffect(()=>{const key=(e:KeyboardEvent)=>{if(e.key==='Escape'||e.ctrlKey&&e.shiftKey&&e.key.toLowerCase()==='p'){e.preventDefault();setPalette(v=>v===false?'':false);requestAnimationFrame(()=>{if(palette!==false)field.current?.focus()})}if(e.key==='Enter'&&e.altKey&&page==='/'&&palette===false){e.preventDefault();restart()}};window.addEventListener('keydown',key);return()=>window.removeEventListener('keydown',key)});
 function applySettings(p:Partial<Settings>){const testChange=['mode','duration','count','customKind','ranges'].some(k=>k in p);if(testChange&&running)finish();s.update(p);if(testChange)restart()}
 const lvl=useMemo(()=>level(h.results).level,[h.results]);
 function update(p:Partial<Settings>){s.update(p);if(!running&&page==='/')restart()}

 const timed=s.mode==='time'||s.mode==='custom'&&s.customKind==='time';
 const r=result;const times=r?.logs.map(l=>l.timeMs)||[];const mean=times.reduce((a,b)=>a+b,0)/(times.length||1);const cv=mean?Math.sqrt(times.reduce((a,b)=>a+(b-mean)**2,0)/times.length)/mean*100:0;
 let accumulated=0;const completions=r?.logs.map(l=>({at:(accumulated+=l.timeMs)/1000,time:l.timeMs}))||[];const graph=r?Array.from({length:Math.max(1,Math.ceil(r.elapsedMs/1000))},(_,i)=>({second:i+1,ppm:completions.filter(x=>x.at<=i+1&&x.at>Math.max(0,i-9)).length*60/Math.min(i+1,10),slow:completions.some(x=>Math.ceil(x.at)===i+1&&x.time>mean*1.5)})):[];
 return <div className={running?'app practicing':'app'}><header className="top-bar"><a href="/" onClick={e=>{e.preventDefault();go('/')}} className="logo" aria-label="zetamath, practice"><LogoMark/><span className="logo-text"><small>count on it</small>zetamath</span></a><nav className="top-nav"><button aria-label="Practice" title="practice" className={page==='/'?'active':''} onClick={()=>go('/')}><KeyboardIcon/></button><button aria-label="Learn mental math" title="learn" className={page==='/learn'?'active':''} onClick={()=>go('/learn')}><BookIcon/></button><button aria-label="Settings" title="settings" className={page==='/settings'?'active':''} onClick={()=>go('/settings')}><GearIcon/></button></nav><button className={page==='/profile'?'account active':'account'} onClick={()=>go('/profile')} title="profile"><UserIcon/><span>{s.name.trim()||'guest'}</span><span className="level-badge">{lvl}</span></button></header><main>
 {error&&<p role="alert">{error}</p>}{h.error&&<p role="alert">{h.error}</p>}
 {page==='/'&&<><ModeBar disabled={running} onMode={m=>{s.update({mode:m});config.current={...s,mode:m};setTimeout(()=>restart(),0)}} onUpdate={update} onConfigure={path=>setPalette(path)}/>
 {!r?<section className="test-stage" onClick={()=>field.current?.focus()}>
 {s.showTimer&&<div className="session-timer" role="timer" aria-label={timed?'Seconds remaining':'Seconds elapsed'}>{timed?Math.ceil(Math.max(0,s.duration-elapsed/1000)):Math.floor(elapsed/1000)}</div>}
 {timed&&s.showTimer&&<div className="time-track" aria-hidden="true"><div style={{transform:`scaleX(${Math.max(0,1-elapsed/(s.duration*1000))})`}}/></div>}
 <div className={`answer-layout ${s.answerStyle==='inline'?'inline-answer':'stacked-answer'}`} style={{fontSize:`clamp(1.5rem, 7vw, ${s.size}rem)`}}>
 <div className="problem">{problem?<>{problem.a} <span className="operator">{problem.op==='-'?'−':problem.op}</span> {problem.b}{s.answerStyle==='inline'&&<span className="operator"> =</span>}</>:'configure your ranges'}</div>
 <input ref={field} className="answer-input" style={s.answerStyle==='inline'?{width:`${Math.max(1,input.length+.3)}ch`}:undefined} aria-label="Your answer" inputMode="numeric" autoComplete="off" value={input} onChange={e=>answer(e.target.value)} onFocus={()=>{if(!running)config.current={...s}}} placeholder={s.answerStyle==='inline'?'':'?'} disabled={!problem}/>
 </div><div className="live-stats">{s.showScore&&<span aria-label={`${score} solved`}>{score}</span>}{s.showPace&&<span>{elapsed?Math.round(score*60000/elapsed):0} ppm</span>}</div>
 <p className="hint">type an answer to begin</p></section>:<section><h1 className="page-title">A little sharper.</h1>{pb&&<p>✦ new personal best</p>}<div className="stats-grid"><div className="stat">solved<strong>{times.length}</strong></div><div className="stat">pace<strong>{Math.round(times.length*60000/(r.elapsedMs||1))} <small>ppm</small></strong></div><div className="stat">time<strong>{(r.elapsedMs/1000).toFixed(2)}s</strong></div><div className="stat">variation<strong>{cv.toFixed(1)}%</strong><small>lower is more consistent</small></div></div><Suspense fallback={<p>Loading chart…</p>}><Chart data={graph}/></Suspense><div className="settings-grid"><div className="panel"><h2>By operation</h2>{operations.map(op=>{const a=r.logs.filter(l=>l.problem.op===op).map(l=>l.timeMs).sort((a,b)=>a-b);return <p key={op}>{op} · {a.length} solved · avg {a.length?(a.reduce((a,b)=>a+b,0)/a.length/1000).toFixed(2):'—'}s · median {a.length?((a[Math.floor((a.length-1)/2)]+a[Math.floor(a.length/2)])/2000).toFixed(2):'—'}s</p>})}</div><div className="panel"><h2>Slowest problems</h2><ol className="slow-list">{[...r.logs].sort((a,b)=>b.timeMs-a.timeMs).slice(0,10).map((l,i)=><li key={i}>{l.problem.a} {l.problem.op} {l.problem.b} = {l.problem.answer}<span>{(l.timeMs/1000).toFixed(2)}s</span></li>)}</ol><button disabled={!times.length} onClick={()=>restart([...r.logs].sort((a,b)=>b.timeMs-a.timeMs).slice(0,10).map(l=>l.problem))}>drill these</button></div></div><div className="result-actions"><button onClick={()=>restart()}>try again ↵</button><button onClick={()=>go('/profile')}>view profile</button></div></section>}<p className="hint"><kbd>alt + enter</kbd> restart · <kbd>esc</kbd> quick settings</p></>}
 {page==='/learn'&&<Suspense fallback={<p>Loading lessons…</p>}><LearnPage practice={()=>{go('/');restart()}}/></Suspense>}
 {page==='/settings'&&<SettingsPage change={applySettings} onError={setError}/>}
 {page==='/profile'&&<Suspense fallback={<p>Loading profile…</p>}><Profile open={b=>{setResult(b);go('/')}}/></Suspense>}
 </main><footer>local practice. lasting progress. <span>all your data stays on this device</span></footer>{palette!==false&&<CommandPalette initialPath={palette} close={()=>{setPalette(false);requestAnimationFrame(()=>field.current?.focus())}} running={running} change={applySettings} finish={()=>{finish();setPalette(false)}} history={()=>{setPalette(false);go('/profile')}}/>}</div>
}
