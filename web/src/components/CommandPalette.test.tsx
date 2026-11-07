// @vitest-environment jsdom
import { act } from "react";
import { createRoot } from "react-dom/client";
import { expect, it, vi } from "vitest";
import CommandPalette from "./CommandPalette";
(
  globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT: boolean }
).IS_REACT_ACT_ENVIRONMENT = true;
it("allows normal Tab traversal and wraps only at dialog boundaries", async () => {
  Element.prototype.scrollIntoView = vi.fn();
  const host = document.createElement("div");
  document.body.append(host);
  const root = createRoot(host);
  try {
    await act(async () =>
      root.render(
        <CommandPalette
          close={() => {}}
          change={() => {}}
          running={false}
          finish={() => {}}
          history={() => {}}
        />,
      ),
    );
    const input = host.querySelector("input")!;
    expect(input.getAttribute("role")).toBe("combobox");
    const tab = new KeyboardEvent("keydown", {
      key: "Tab",
      bubbles: true,
      cancelable: true,
    });
    await act(async () => input.dispatchEvent(tab));
    expect(tab.defaultPrevented).toBe(false);
    const buttons = host.querySelectorAll("button");
    buttons[buttons.length - 1].focus();
    const lastTab = new KeyboardEvent("keydown", {
      key: "Tab",
      bubbles: true,
      cancelable: true,
    });
    await act(async () => buttons[buttons.length - 1].dispatchEvent(lastTab));
    expect(lastTab.defaultPrevented).toBe(true);
    expect(document.activeElement).toBe(buttons[0]);
  } finally {
    await act(async () => root.unmount());
    host.remove();
  }
});
