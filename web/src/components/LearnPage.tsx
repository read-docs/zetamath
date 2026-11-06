import {lessons, sources, type Technique} from '../content/lessons';

function TechniqueCard({technique, index}: {technique: Technique; index: number}) {
  const source = sources[technique.source];
  return <article className="learn-card">
    <span className="learn-eyebrow">technique {index + 1}</span>
    <h3>{technique.title}</h3>
    <p className="learn-when">{technique.when}</p>
    <p>{technique.tip}</p>
    <div className="learn-example">
      <strong>{technique.example}</strong>
      <ol>{technique.steps.map(step => <li key={step}>{step}</li>)}</ol>
    </div>
    <div className="learn-try">
      <p>Try it mentally <strong>{technique.question}</strong></p>
      <details>
        <summary>Show solution</summary>
        <p>{technique.solution}</p>
      </details>
    </div>
    <a className="learn-source" href={source.url} target="_blank" rel="noreferrer">{source.label} ↗</a>
  </article>;
}

export default function LearnPage({practice}: {practice: () => void}) {
  return <div className="learn-page">
    <header className="learn-heading">
      <span className="learn-eyebrow">the mental math toolkit</span>
      <h1>Make the numbers easier.</h1>
      <p>Learn a shortcut, work through an example, then try it yourself.
        Choose the method that fits the numbers. Accuracy first; speed comes with practice.</p>
    </header>
    <nav className="learn-nav" aria-label="Learning topics">
      {lessons.map(lesson => <a href={'#learn-' + lesson.id} key={lesson.id}>
        <span aria-hidden="true">{lesson.symbol}</span> {lesson.title}
      </a>)}
    </nav>
    {lessons.map(lesson => <section key={lesson.id} id={'learn-' + lesson.id} aria-labelledby={'heading-' + lesson.id}>
      <div className="learn-section-heading">
        <span className="learn-symbol" aria-hidden="true">{lesson.symbol}</span>
        <div><h2 id={'heading-' + lesson.id}>{lesson.title}</h2><p>{lesson.intro}</p></div>
      </div>
      <div className="learn-grid">
        {lesson.techniques.map((technique, index) => <TechniqueCard key={technique.title} technique={technique} index={index}/>)}
      </div>
    </section>)}
    <section className="learn-next">
      <div><h2>Turn a technique into a habit.</h2>
        <p>Try a few problems slowly. Say the intermediate steps in your head.
          Check division by multiplying back, and subtraction by adding back.
          When a method feels comfortable, try it in a practice session.</p></div>
      <button onClick={practice}>Start practicing →</button>
    </section>
    <p className="learn-credit">Further reading is linked on each card. Explanations and worked examples are written for Zetamath.</p>
  </div>;
}
