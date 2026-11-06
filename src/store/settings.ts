import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { defaultRanges, type RangeConfig } from '../engine/generator';

export interface Settings {
  mode: 'time' | 'count' | 'zen' | 'custom';
  duration: number;
  count: number;
  customKind: 'time' | 'count';
  ranges: RangeConfig;
  theme: string;
  font: string;
  size: number;
  showTimer: boolean;
  showScore: boolean;
  showPace: boolean;
  focusMode: boolean;
}
export const defaultSettings: Settings = {
  mode: 'time', duration: 120, count: 25, customKind: 'time', ranges: defaultRanges,
  theme: 'iceberg', font: 'JetBrains Mono', size: 4,
  showTimer: true, showScore: true, showPace: true, focusMode: false,
};
export const useSettings = create<Settings & {
  update: (patch: Partial<Settings>) => void;
  reset: () => void;
}>()(persist((set) => ({
  ...defaultSettings,
  update: (patch) => set(patch),
  reset: () => set(structuredClone(defaultSettings)),
}), { name: 'zetamath-settings', version: 1 }));
