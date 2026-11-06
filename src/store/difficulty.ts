import {operations, type RangeConfig} from '../engine/generator';
export const difficulties = {easy:[20,5,20],normal:[100,12,100],hard:[1000,20,200]} as const;
export function difficultyRanges(name:keyof typeof difficulties, ranges:RangeConfig):RangeConfig {
 const [sum,mulA,mulB]=difficulties[name];
 return Object.fromEntries(operations.map(op=>[op,{...ranges[op],minA:2,minB:2,maxA:op==='+'||op==='-'?sum:mulA,maxB:op==='+'||op==='-'?sum:mulB}])) as RangeConfig;
}
export function currentDifficulty(ranges:RangeConfig):string {
 return Object.keys(difficulties).find(name=>{const preset=difficultyRanges(name as keyof typeof difficulties,ranges);return operations.every(op=>['minA','maxA','minB','maxB'].every(k=>ranges[op][k as 'minA']===preset[op][k as 'minA']))})||'custom';
}
