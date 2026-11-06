import type {ReactNode} from 'react';
import {useSettings,type Settings} from '../store/settings';
import {ClockIcon,HashIcon,MountainIcon,SlidersIcon,WrenchIcon} from './icons';

type Mode = Settings['mode'];
export const timeOptions = [15,30,60,120];
export const countOptions = [10,25,50,100];
const modes: {id:Mode,icon:ReactNode}[] = [
  {id:'time',icon:<ClockIcon/>},
  {id:'count',icon:<HashIcon/>},
  {id:'zen',icon:<MountainIcon/>},
  {id:'custom',icon:<WrenchIcon/>},
];

export default function ModeBar({disabled,onMode,onUpdate,onConfigure}:{
  disabled:boolean,
  onMode:(mode:Mode)=>void,
  onUpdate:(patch:Partial<Settings>)=>void,
  onConfigure:(path:string)=>void,
}) {
  const s = useSettings();
  let options: ReactNode = null;
  if (s.mode==='time'||s.mode==='count') {
    const timed = s.mode==='time', values = timed?timeOptions:countOptions, current = timed?s.duration:s.count;
    const preset = values.includes(current);
    options = <>
      {values.map(n=><button key={n} disabled={disabled} className={current===n?'active':''} onClick={()=>onUpdate(timed?{duration:n}:{count:n})}>{n}</button>)}
      <button disabled={disabled} className={preset?'':'active'} aria-label={timed?'Custom duration':'Custom count'} title={timed?'custom duration':'custom count'} onClick={()=>onConfigure(timed?'duration':'count')}><SlidersIcon/>{!preset&&<span>{current}</span>}</button>
    </>;
  } else if (s.mode==='custom') {
    const timed = s.customKind==='time';
    options = <>
      {(['time','count'] as const).map(kind=><button key={kind} disabled={disabled} className={s.customKind===kind?'active':''} onClick={()=>onUpdate({customKind:kind})}>{kind}</button>)}
      <button disabled={disabled} title={timed?'set duration':'set count'} onClick={()=>onConfigure(timed?'duration':'count')}>{timed?`${s.duration}s`:s.count}</button>
      <button disabled={disabled} aria-label="Operations and ranges" title="operations and ranges" onClick={()=>onConfigure('operations and ranges')}><SlidersIcon/></button>
    </>;
  }
  return <div className="mode-bar">
    <div className="mode-group" role="group" aria-label="Mode">
      {modes.map(m=><button key={m.id} disabled={disabled} className={s.mode===m.id?'active':''} onClick={()=>onMode(m.id)}>{m.icon}<span>{m.id}</span></button>)}
    </div>
    {options&&<div className="mode-group" role="group" aria-label="Length">{options}</div>}
  </div>;
}
