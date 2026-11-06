import {useEffect,useRef,useState} from 'react';
import {useSettings,type Settings} from '../store/settings';
import {difficultyRanges,currentDifficulty,difficulties} from '../store/difficulty';
import {operations,validateRanges} from '../engine/generator';
import {themes,fonts} from '../themes';
type Entry={label:string,value?:string,run:()=>void};
export default function CommandPalette({close,change,running,finish,history,initialPath=''}:{initialPath?:string,close:()=>void,change:(p:Partial<Settings>)=>void,running:boolean,finish:()=>void,history:()=>void}) {
 const s=useSettings();const [path,setPath]=useState(initialPath),[query,setQuery]=useState(''),[selected,setSelected]=useState(0),[error,setError]=useState('');const input=useRef<HTMLInputElement>(null);
 function enter(p:string){setPath(p);setQuery('');setSelected(0);setError('');input.current?.focus()}
 function apply(p:Partial<Settings>){change(p);close()}
 const menu=(label:string,value?:string):Entry=>({label,value,run:()=>enter(label)});
 const choices=(values:readonly string[],key:keyof Settings):Entry[]=>values.map(v=>({label:v,value:s[key]===v?'✓':'',run:()=>apply({[key]:v})}));
 let entries:Entry[]=[];
 if(!path)entries=[menu('difficulty',currentDifficulty(s.ranges)),menu('mode',s.mode),menu('duration',`${s.duration}s`),menu('count',String(s.count)),menu('custom goal',s.customKind),menu('theme',s.theme),menu('font',s.font),menu('answer style',s.answerStyle),menu('problem size',`${s.size}rem`),...(['showTimer','showScore','showPace'] as const).map((k,i)=>({label:['live timer','live score','live pace'][i],value:s[k]?'on':'off',run:()=>apply({[k]:!s[k]})})),menu('operations and ranges'),{label:'profile / history / export',run:history},...(running?[{label:'finish test',run:finish}]:[])];
 else if(path==='difficulty')entries=Object.keys(difficulties).map(name=>({label:name,value:name===currentDifficulty(s.ranges)?'✓':'',run:()=>apply({ranges:difficultyRanges(name as keyof typeof difficulties,s.ranges)})}));
 else if(path==='mode')entries=choices(['time','count','zen','custom'],'mode');
 else if(path==='custom goal')entries=choices(['time','count'],'customKind');
 else if(path==='theme')entries=choices(Object.keys(themes),'theme');
 else if(path==='font')entries=choices(fonts,'font');
 else if(path==='answer style')entries=choices(['inline','stacked'],'answerStyle');
 else if(path==='operations and ranges')entries=operations.map(op=>menu(`operation ${op}`,s.ranges[op].enabled?'on':'off'));
 else if(path.startsWith('operation ')){const op=path.slice(-1) as typeof operations[number];const range=s.ranges[op];entries=[{label:range.enabled?'disable':'enable',run:()=>saveRange(op,{enabled:!range.enabled})},...(['minA','maxA','minB','maxB','weight'] as const).map(k=>menu(`${op} ${k}`,String(range[k])))];}
 const rangeMatch=path.match(/^([+−×÷-]) (minA|maxA|minB|maxB|weight)$/);
 const numeric=['duration','count','problem size'].includes(path)||!!rangeMatch;
 function saveRange(op:typeof operations[number],patch:object){const ranges={...s.ranges,[op]:{...s.ranges[op],...patch}};const issue=validateRanges(ranges);if(issue){setError(issue);return}apply({ranges})}
 function saveNumber(){const n=Number(query);if(!query.trim()||!Number.isFinite(n)){setError('Enter a number.');return}if(rangeMatch){saveRange(rangeMatch[1] as typeof operations[number],{[rangeMatch[2]]:n});return}if(path==='problem size'){if(n<2||n>8){setError('Use a size from 2 to 8.');return}apply({size:n})}else if(!Number.isInteger(n)||n<1||n>86400)setError('Use a whole number from 1 to 86400.');else apply({[path]:n})}
 const filtered=entries.filter(e=>e.label.toLowerCase().includes(query.toLowerCase()));
 useEffect(()=>{input.current?.focus()},[path]);
 useEffect(()=>{document.getElementById(`command-${selected}`)?.scrollIntoView({block:'nearest'})},[selected]);
 return <div className="palette-backdrop" onClick={close}><div className="command-terminal" role="dialog" aria-modal="true" aria-label="Settings commands" onClick={e=>e.stopPropagation()} onKeyDown={e=>{if(e.key==='Escape'){e.preventDefault();e.stopPropagation();path?enter(''):close()}if(e.key==='ArrowDown'||e.key==='ArrowUp'){e.preventDefault();setSelected(i=>filtered.length?(i+(e.key==='ArrowDown'?1:-1)+filtered.length)%filtered.length:0)}if(e.key==='Enter'){e.preventDefault();numeric?saveNumber():filtered[selected]?.run()}if(e.key==='Tab'){e.preventDefault();input.current?.focus()}}}>
 <div className="command-breadcrumb"><button onClick={()=>enter('')}>settings</button>{path&&<span> / {path}</span>}<button className="command-close" onClick={close}>esc</button></div>
 <div className="command-prompt"><span aria-hidden="true">&gt;</span><input ref={input} autoFocus value={query} aria-label={numeric?'Enter value':'Search settings'} placeholder={numeric?'type a value and press enter…':'type to search…'} onChange={e=>{setQuery(e.target.value);setSelected(0);setError('')}} aria-controls="commands" aria-activedescendant={!numeric&&filtered[selected]?`command-${selected}`:undefined}/></div>
 {error&&<p className="command-error" role="alert">{error}</p>}
 <div id="commands" className="command-list" role="listbox" aria-label={path||'Settings'}>{numeric?<button onClick={saveNumber}>apply value ↵</button>:filtered.map((e,i)=><button role="option" aria-selected={i===selected} id={`command-${i}`} key={e.label} className={i===selected?'selected':''} onMouseMove={()=>setSelected(i)} onClick={e.run}><span>{e.label}</span><span>{e.value||'↵'}</span></button>)}{!numeric&&!filtered.length&&<p>No matching commands.</p>}</div>
 <div className="command-help">↑ ↓ navigate · enter select · esc {path?'back':'close'}{running?' · test timer continues':''}</div>
 </div></div>
}
