export type Theme = { bg: string; main: string; sub: string; text: string; error: string };
export const themes: Record<string, Theme> = {
  iceberg: { bg: '#161821', main: '#84a0c6', sub: '#6b7089', text: '#c6c8d1', error: '#e27878' },
  monochrome: { bg: '#161616', main: '#eeeeee', sub: '#818181', text: '#c5c5c5', error: '#aaaaaa' },
  nord: { bg: '#2e3440', main: '#88c0d0', sub: '#8b95a6', text: '#eceff4', error: '#bf616a' },
  rose: { bg: '#211b24', main: '#ebbcba', sub: '#9b819b', text: '#e0def4', error: '#eb6f92' },
  forest: { bg: '#18221e', main: '#a7c080', sub: '#859289', text: '#d3c6aa', error: '#e67e80' },
  ocean: { bg: '#10252f', main: '#6ed6db', sub: '#7596a3', text: '#d4e8ef', error: '#f48b8b' },
  lavender: { bg: '#232136', main: '#c4a7e7', sub: '#908caa', text: '#e0def4', error: '#eb6f92' },
  amber: { bg: '#24201a', main: '#e5b567', sub: '#a09581', text: '#e9dfce', error: '#e17e76' },
  terminal: { bg: '#101710', main: '#80d880', sub: '#729572', text: '#c4dfc4', error: '#e28b7a' },
  midnight: { bg: '#0e1525', main: '#82aaff', sub: '#7b8ba9', text: '#c8d3f5', error: '#ff757f' },
  plum: { bg: '#2a1c30', main: '#dba6e8', sub: '#aa88ad', text: '#eee0ef', error: '#ff8f9c' },
  coffee: { bg: '#28221f', main: '#d6ae88', sub: '#a49486', text: '#e2d7cb', error: '#e28779' },
  paper: { bg: '#f4f1e8', main: '#7a5737', sub: '#81786c', text: '#37332d', error: '#b43c3c' },
  snow: { bg: '#f0f4f8', main: '#396ba5', sub: '#69788a', text: '#273548', error: '#bd3a52' },
  mint: { bg: '#e9f1eb', main: '#356e52', sub: '#677d6e', text: '#283e30', error: '#b63f49' },
};
export const fonts = ['JetBrains Mono','Roboto Mono','Fira Code','IBM Plex Mono','Space Mono','Lexend Deca'];
