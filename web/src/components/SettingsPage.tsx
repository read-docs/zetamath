import {useEffect,useState,type ReactNode} from 'react';
import {operations,validateRanges,type Operation,type OperationRange} from '../engine/generator';
import {useSettings,defaultSettings,type Settings} from '../store/settings';
import {useHistory} from '../store/history';
import {currentDifficulty,difficulties,difficultyRanges} from '../store/difficulty';
import {themes,fonts} from '../themes';
import {countOptions,timeOptions} from './ModeBar';
import {BarsIcon,CalculatorIcon,ChevronIcon,ClockIcon,DownloadIcon,EyeIcon,HashIcon,ResetIcon,ResizeIcon,ReturnIcon,TrashIcon,TypeIcon,UploadIcon,UserIcon,WrenchIcon} from './icons';

type Change = (patch: Partial<Settings>) => void;
const opNames: Record<Operation, [string, string]> = {
  '+': ['addition', 'a + b'],
  '-': ['subtraction', 'shown as (a + b) − b, so the answer is never negative'],
  '×': ['multiplication', 'a × b'],
  '÷': ['division', 'shown as (a × b) ÷ b, so the answer is always whole'],
};

function NumberInput({value, onCommit, label, min = 1, max = 86400, step = 1}:{value: number, onCommit: (n: number) => string | null | void, label: string, min?: number, max?: number, step?: number}) {
  const [draft, setDraft] = useState(String(value)), [error, setError] = useState('');
  useEffect(() => setDraft(String(value)), [value]);
  function commit() {
    const n = Number(draft);
    if (draft.trim() === '' || !Number.isFinite(n) || n < min || n > max || (step === 1 && !Number.isInteger(n))) {
      setError(`Use ${step === 1 ? 'a whole number' : 'a number'} from ${min} to ${max}.`); return;
    }
    if (n === value) { setError(''); return; }
    const issue = onCommit(n);
    setError(issue || '');
    if (issue) setDraft(String(value));
  }
  return <span className="number-input">
    <input type="number" aria-label={label} value={draft} min={min} max={max} step={step} onChange={e => setDraft(e.target.value)} onBlur={commit} onKeyDown={e => { if (e.key === 'Enter') commit(); }}/>
    {error && <small role="alert">{error}</small>}
  </span>;
}

function Row({icon, title, description, children, wide}:{icon: ReactNode, title: string, description: ReactNode, children: ReactNode, wide?: boolean}) {
  return <div className={wide ? 'setting wide' : 'setting'}>
    <div className="setting-title">{icon}{title}</div>
    <div className="setting-text">{description}</div>
    <div className="setting-controls">{children}</div>
  </div>;
}

function Choice<T extends string | number | boolean>({options, value, onChange, label}:{options: readonly T[], value: T, onChange: (v: T) => void, label?: (v: T) => string}) {
  return <>{options.map(o => <button key={String(o)} className={o === value ? 'active' : ''} onClick={() => onChange(o)}>{label ? label(o) : String(o)}</button>)}</>;
}

const toggle = (value: boolean, onChange: (v: boolean) => void) => <Choice options={[false, true]} value={value} onChange={onChange} label={v => v ? 'on' : 'off'}/>;

function Section({id, title, children}:{id: string, title: string, children: ReactNode}) {
  const [open, setOpen] = useState(true);
  return <section id={id} className={open ? 'settings-section' : 'settings-section closed'}>
    <button className="section-title" aria-expanded={open} onClick={() => setOpen(o => !o)}><ChevronIcon/>{title}</button>
    {open && <div className="section-body">{children}</div>}
  </section>;
}

const sections = [['test','test'],['operations','operations'],['input','input'],['appearance','appearance'],['theme','theme'],['data','data'],['danger','danger zone']] as const;

export default function SettingsPage({change, onError}:{change: Change, onError: (message: string) => void}) {
  const s = useSettings(), h = useHistory();
  const difficulty = currentDifficulty(s.ranges);

  function saveRange(op: Operation, patch: Partial<OperationRange>): string | null {
    const ranges = {...s.ranges, [op]: {...s.ranges[op], ...patch}};
    const issue = validateRanges(ranges);
    if (!issue) change({ranges});
    return issue;
  }
  function exportJSON() {
    const url = URL.createObjectURL(new Blob([h.exportJSON()], {type: 'application/json'}));
    const a = document.createElement('a'); a.href = url; a.download = 'zetamath-history.json'; a.click(); URL.revokeObjectURL(url);
  }

  return <div className="settings-page">
    <nav className="settings-jump" aria-label="Settings sections">
      {sections.map(([id, label]) => <button key={id} onClick={() => document.getElementById(id)?.scrollIntoView({behavior: 'smooth', block: 'start'})}>{label}</button>)}
    </nav>

    <Section id="test" title="test">
      <Row icon={<ClockIcon/>} title="mode" description="Time runs for a set number of seconds. Count ends after a set number of problems. Zen runs until you stop it. Custom lets you pick any goal.">
        <Choice options={['time','count','zen','custom'] as const} value={s.mode} onChange={mode => change({mode})}/>
      </Row>
      <Row icon={<ClockIcon/>} title="time limit" description="Length of time and custom-time tests, in seconds.">
        <Choice options={timeOptions} value={s.duration} onChange={duration => change({duration})}/>
        <NumberInput label="Custom time limit" value={s.duration} onCommit={duration => change({duration})}/>
      </Row>
      <Row icon={<HashIcon/>} title="problem count" description="How many problems a count or custom-count test asks.">
        <Choice options={countOptions} value={s.count} onChange={count => change({count})}/>
        <NumberInput label="Custom problem count" value={s.count} onCommit={count => change({count})}/>
      </Row>
      <Row icon={<WrenchIcon/>} title="custom goal" description="Whether custom mode ends on the time limit or the problem count.">
        <Choice options={['time','count'] as const} value={s.customKind} onChange={customKind => change({customKind})}/>
      </Row>
      <Row icon={<BarsIcon/>} title="difficulty" description={<>Presets for every operation's number range. Editing a range by hand makes this <span className="highlight">custom</span>. Personal bests are tracked per range setup.</>}>
        <Choice options={Object.keys(difficulties) as (keyof typeof difficulties)[]} value={difficulty as keyof typeof difficulties} onChange={name => change({ranges: difficultyRanges(name, s.ranges)})}/>
        <button className={difficulty === 'custom' ? 'active' : ''} disabled={difficulty !== 'custom'} tabIndex={-1}>custom</button>
      </Row>
    </Section>

    <Section id="operations" title="operations">
      {operations.map(op => {
        const r = s.ranges[op], [name, form] = opNames[op];
        return <Row key={op} wide icon={<CalculatorIcon/>} title={`${name} ${op}`} description={<>{form}. Weight sets how often it appears compared with the others.</>}>
          <div className="op-controls">
            <span className="op-field"><label>enabled</label><span className="button-row">{toggle(r.enabled, enabled => saveRange(op, {enabled}))}</span></span>
            <span className="op-field"><label>weight</label><NumberInput label={`${name} weight`} value={r.weight} min={0} max={1000} step={0.1} onCommit={weight => saveRange(op, {weight})}/></span>
            <span className="op-field"><label>a from</label><NumberInput label={`${name} a minimum`} value={r.minA} max={1000000} onCommit={minA => saveRange(op, {minA})}/></span>
            <span className="op-field"><label>a to</label><NumberInput label={`${name} a maximum`} value={r.maxA} max={1000000} onCommit={maxA => saveRange(op, {maxA})}/></span>
            <span className="op-field"><label>b from</label><NumberInput label={`${name} b minimum`} value={r.minB} max={1000000} onCommit={minB => saveRange(op, {minB})}/></span>
            <span className="op-field"><label>b to</label><NumberInput label={`${name} b maximum`} value={r.maxB} max={1000000} onCommit={maxB => saveRange(op, {maxB})}/></span>
          </div>
        </Row>;
      })}
    </Section>

    <Section id="input" title="input">
      <Row icon={<ReturnIcon/>} title="answer style" description="Inline puts the answer right after the equals sign. Stacked puts it in a box under the problem.">
        <Choice options={['inline','stacked'] as const} value={s.answerStyle} onChange={answerStyle => change({answerStyle})}/>
      </Row>
    </Section>

    <Section id="appearance" title="appearance">
      <Row icon={<ResizeIcon/>} title="problem size" description="Size of the problem text, in rem. It shrinks to fit on small screens.">
        <Choice options={[3,4,5,6]} value={s.size} onChange={size => change({size})}/>
        <NumberInput label="Custom problem size" value={s.size} min={2} max={8} step={0.25} onCommit={size => change({size})}/>
      </Row>
      <Row icon={<TypeIcon/>} title="font family" description="Typeface for the whole app." wide>
        <div className="font-grid">{fonts.map(f => <button key={f} style={{fontFamily: `"${f}", monospace`}} className={s.font === f ? 'active' : ''} onClick={() => change({font: f})}>{f}</button>)}</div>
      </Row>
      <Row icon={<EyeIcon/>} title="live timer" description="Show the countdown and progress bar during a test.">{toggle(s.showTimer, showTimer => change({showTimer}))}</Row>
      <Row icon={<EyeIcon/>} title="live score" description="Show how many problems you have solved during a test.">{toggle(s.showScore, showScore => change({showScore}))}</Row>
      <Row icon={<EyeIcon/>} title="live pace" description="Show problems per minute during a test.">{toggle(s.showPace, showPace => change({showPace}))}</Row>
    </Section>

    <Section id="theme" title="theme">
      <div className="theme-presets">{Object.entries(themes).map(([name, t]) =>
        <button key={name} className={s.theme === name ? 'active' : ''} style={{background: t.bg, color: t.main, outlineColor: t.main}} onClick={() => change({theme: name})}>
          <span>{name}</span>
          <span className="swatches" aria-hidden="true">{[t.main, t.sub, t.text].map(c => <i key={c} style={{background: c}}/>)}</span>
        </button>)}
      </div>
    </Section>

    <Section id="data" title="data">
      <Row icon={<UserIcon/>} title="profile name" description="Shown in the top bar and on your profile.">
        <input className="text-setting" aria-label="Profile name" value={s.name} placeholder="guest" maxLength={24} onChange={e => change({name: e.target.value})}/>
      </Row>
      <Row icon={<DownloadIcon/>} title="export history" description={`Download all ${h.results.length} results as a JSON file. It is your backup, and it moves your history to another browser.`}>
        <button disabled={!h.results.length} onClick={exportJSON}>export</button>
      </Row>
      <Row icon={<UploadIcon/>} title="import history" description="Merge a zetamath JSON export into this browser. Results you already have are kept.">
        <label className="button-like">import<input type="file" accept="application/json" onChange={async e => {
          try { const file = e.target.files?.[0]; if (file) await h.importJSON(await file.text()); }
          catch (error) { onError(String(error)); }
          e.target.value = '';
        }}/></label>
      </Row>
    </Section>

    <Section id="danger" title="danger zone">
      <Row icon={<TrashIcon/>} title="clear history" description="Delete every saved result from this browser. This cannot be undone, so export first.">
        <button className="danger" disabled={!h.results.length} onClick={() => { if (confirm(`Delete all ${h.results.length} results?`)) void h.clear().catch(error => onError(String(error))); }}>clear history</button>
      </Row>
      <Row icon={<ResetIcon/>} title="reset settings" description="Put every setting back to its default. Your history is not touched.">
        <button className="danger" onClick={() => { if (confirm('Reset all settings?')) change({...structuredClone(defaultSettings), name: s.name}); }}>reset settings</button>
      </Row>
    </Section>
  </div>;
}
