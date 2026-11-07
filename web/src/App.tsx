import { lazy, Suspense, useEffect, useMemo, useState } from "react";
import { useSession } from "./hooks/useSession";
import CommandPalette from "./components/CommandPalette";
import ModeBar from "./components/ModeBar";
const LearnPage = lazy(() => import("./components/LearnPage"));
const Profile = lazy(() => import("./components/Profile"));
import ResultsView from "./components/ResultsView";
import SettingsPage from "./components/SettingsPage";
import {
  BookIcon,
  GearIcon,
  KeyboardIcon,
  LogoMark,
  UserIcon,
} from "./components/icons";
import { level } from "./store/profile";

import { operations } from "./engine/generator";
import { useSettings, type Settings } from "./store/settings";
import { useHistory } from "./store/history";
import { themes } from "./themes";

const route = (path: string) =>
  path === "/history"
    ? "/profile"
    : ["/", "/profile", "/learn", "/settings"].includes(path)
      ? path
      : "/";

export default function App() {
  const s = useSettings(),
    h = useHistory();
  const [page, setPage] = useState(route(location.pathname)),
    [palette, setPalette] = useState<string | false>(false),
    [error, setError] = useState("");
  const {
    problem,
    input,
    elapsed,
    running,
    ready,
    begin,
    result,
    pb,
    score,
    field,
    config,
    restart,
    finish,
    answer,
    setResult,
  } = useSession(setError);
  function go(p: string) {
    if (running) finish();
    history.pushState({}, "", p);
    setPage(p);
  }
  useEffect(() => {
    void h.load();
    restart();
    const pop = () => {
      finish();
      setPage(route(location.pathname));
    };
    window.addEventListener("popstate", pop);
    return () => window.removeEventListener("popstate", pop);
  }, []);
  useEffect(() => {
    const t = themes[s.theme] || themes.iceberg;
    Object.entries(t).forEach(([k, v]) =>
      document.documentElement.style.setProperty("--" + k, v),
    );
    document.documentElement.style.setProperty(
      "--font",
      `"${s.font}", monospace`,
    );
  }, [s.theme, s.font]);

  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      if (
        e.key === "Escape" ||
        (e.ctrlKey && e.shiftKey && e.key.toLowerCase() === "p")
      ) {
        e.preventDefault();
        setPalette((v) => (v === false ? "" : false));
        requestAnimationFrame(() => {
          if (palette !== false) field.current?.focus();
        });
      }
      if (e.key === "Enter" && e.altKey && page === "/" && palette === false) {
        e.preventDefault();
        if (!running || window.confirm("Discard this session and restart? Use Finish to save it.")) {
          restart();
        }
      }
    };
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  });
  function applySettings(p: Partial<Settings>) {
    const testChange = [
      "mode",
      "duration",
      "count",
      "customKind",
      "ranges",
    ].some((k) => k in p);
    if (testChange && running) finish();
    s.update(p);
    if (testChange) restart();
  }
  const lvl = useMemo(() => level(h.results).level, [h.results]);
  function update(p: Partial<Settings>) {
    s.update(p);
    if (!running && page === "/") restart();
  }

  const timed =
    s.mode === "time" || (s.mode === "custom" && s.customKind === "time");
  const r = result;
  return (
    <div
      className={
        running ? `app practicing${s.focusMode ? " focus-mode" : ""}` : "app"
      }
    >
      <header className="top-bar">
        <a
          href="/"
          onClick={(e) => {
            e.preventDefault();
            go("/");
          }}
          className="logo"
          aria-label="zetamath, practice"
        >
          <LogoMark />
          <span className="logo-text">
            <small>count on it</small>zetamath
          </span>
        </a>
        <nav className="top-nav">
          <button
            aria-label="Practice"
            title="practice"
            className={page === "/" ? "active" : ""}
            onClick={() => go("/")}
          >
            <KeyboardIcon />
          </button>
          <button
            aria-label="Learn mental math"
            title="learn"
            className={page === "/learn" ? "active" : ""}
            onClick={() => go("/learn")}
          >
            <BookIcon />
          </button>
          <button
            aria-label="Settings"
            title="settings"
            className={page === "/settings" ? "active" : ""}
            onClick={() => go("/settings")}
          >
            <GearIcon />
          </button>
        </nav>
        <button
          className={page === "/profile" ? "account active" : "account"}
          onClick={() => go("/profile")}
          title="profile"
        >
          <UserIcon />
          <span>{s.name.trim() || "guest"}</span>
          <span className="level-badge">{lvl}</span>
        </button>
      </header>
      <main>
        {error && <p role="alert">{error}</p>}
        {h.error && <p role="alert">{h.error}</p>}
        {page === "/" && (
          <>
            <ModeBar
              disabled={running}
              onMode={(m) => {
                s.update({ mode: m });
                config.current = { ...s, mode: m };
                setTimeout(() => restart(), 0);
              }}
              onUpdate={update}
              onConfigure={(path) => setPalette(path)}
            />
            {running && (
              <div className="session-actions">
                <button onClick={() => finish()}>finish and save</button>
                <button onClick={() => setPalette("")}>quick settings</button>
              </div>
            )}
            {!r ? (
              <section
                className="test-stage"
                onClick={() => field.current?.focus()}
              >
                {s.showTimer && (
                  <div
                    className="session-timer"
                    role="timer"
                    aria-label={timed ? "Seconds remaining" : "Seconds elapsed"}
                  >
                    {timed
                      ? Math.ceil(Math.max(0, s.duration - elapsed / 1000))
                      : Math.floor(elapsed / 1000)}
                  </div>
                )}
                {timed && s.showTimer && (
                  <div className="time-track" aria-hidden="true">
                    <div
                      style={{
                        transform: `scaleX(${Math.max(0, 1 - elapsed / (s.duration * 1000))})`,
                      }}
                    />
                  </div>
                )}
                {ready && (
                  <div className="practice-ready">
                    <h1>Ready to practice?</h1>
                    <p>
                      The timer starts when you reveal the first problem.
                      Correct answers advance automatically.
                    </p>
                    <button onClick={begin}>Start practice</button>
                    <p>
                      New here? Try a short test or choose Zen for untimed
                      practice.
                    </p>
                  </div>
                )}
                {!ready && (
                  <div
                    className={`answer-layout ${s.answerStyle === "inline" ? "inline-answer" : "stacked-answer"}`}
                    style={{ fontSize: `clamp(1.5rem, 7vw, ${s.size}rem)` }}
                  >
                    <div
                      id="current-problem"
                      className="problem"
                      aria-live="polite"
                      aria-atomic="true"
                    >
                      {problem ? (
                        <>
                          {problem.a}{" "}
                          <span className="operator">
                            {problem.op === "-" ? "−" : problem.op}
                          </span>{" "}
                          {problem.b}
                          {s.answerStyle === "inline" && (
                            <span className="operator"> =</span>
                          )}
                        </>
                      ) : (
                        "configure your ranges"
                      )}
                    </div>
                    <input
                      ref={field}
                      className="answer-input"
                      style={
                        s.answerStyle === "inline"
                          ? { width: `${Math.max(1, input.length + 0.3)}ch` }
                          : undefined
                      }
                      aria-label="Your answer"
                      aria-describedby="current-problem"
                      inputMode="numeric"
                      autoComplete="off"
                      value={input}
                      onChange={(e) => answer(e.target.value)}
                      onFocus={() => {
                        if (!running) config.current = { ...s };
                      }}
                      placeholder={s.answerStyle === "inline" ? "" : "?"}
                      disabled={!running || !problem}
                    />
                  </div>
                )}
                <div className="live-stats">
                  {s.showScore && (
                    <span aria-label={`${score} solved`}>{score}</span>
                  )}
                  {s.showPace && (
                    <span>
                      {elapsed ? Math.round((score * 60000) / elapsed) : 0} ppm
                    </span>
                  )}
                </div>
                <p className="hint">
                  Correct answers advance automatically. Finish saves your
                  session; restart discards it.
                </p>
              </section>
            ) : (
              <ResultsView
                result={r}
                personalBest={pb}
                restart={restart}
                profile={() => go("/profile")}
              />
            )}
            <p className="hint">
              <kbd>alt + enter</kbd> restart · <kbd>esc</kbd> quick settings
            </p>
          </>
        )}
        {page === "/learn" && (
          <Suspense fallback={<p>Loading lessons…</p>}>
            <LearnPage
              practice={(op) => {
                if (op) {
                  const ranges = structuredClone(s.ranges);
                  operations.forEach((key) => {
                    ranges[key].enabled = key === op;
                    if (key === op)
                      ranges[key].weight = Math.max(1, ranges[key].weight);
                  });
                  s.update({ ranges, mode: "zen" });
                }
                go("/");
                restart();
              }}
            />
          </Suspense>
        )}
        {page === "/settings" && (
          <SettingsPage change={applySettings} onError={setError} />
        )}
        {page === "/profile" && (
          <Suspense fallback={<p>Loading profile…</p>}>
            <Profile
              open={(b) => {
                setResult(b);
                go("/");
              }}
            />
          </Suspense>
        )}
      </main>
      <footer>
        local practice. lasting progress.{" "}
        <span>all your data stays on this device</span>
      </footer>
      {palette !== false && (
        <CommandPalette
          initialPath={palette}
          close={() => {
            setPalette(false);
            requestAnimationFrame(() => field.current?.focus());
          }}
          running={running}
          change={applySettings}
          finish={() => {
            finish();
            setPalette(false);
          }}
          history={() => {
            setPalette(false);
            go("/profile");
          }}
        />
      )}
    </div>
  );
}
