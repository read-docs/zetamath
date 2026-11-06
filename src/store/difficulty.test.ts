import {describe,it,expect} from 'vitest';
import {defaultRanges} from '../engine/generator';
import {difficultyRanges,currentDifficulty} from './difficulty';
describe('difficulty presets',()=>{
 it.each([['easy',20,5,20],['normal',100,12,100],['hard',1000,20,200]] as const)('sets %s operand ranges',(name,sum,a,b)=>{
 const ranges=difficultyRanges(name,defaultRanges);
 for(const op of ['+','-'] as const)expect(ranges[op]).toMatchObject({minA:2,minB:2,maxA:sum,maxB:sum});
 for(const op of ['×','÷'] as const)expect(ranges[op]).toMatchObject({minA:2,minB:2,maxA:a,maxB:b});
 expect(currentDifficulty(ranges)).toBe(name);
 });
 it('preserves operation selection and weights and detects custom ranges',()=>{
 const ranges=difficultyRanges('easy',{...defaultRanges,'+':{...defaultRanges['+'],enabled:false,weight:3}});
 expect(ranges['+']).toMatchObject({enabled:false,weight:3});
 ranges['+'].maxA=99;expect(currentDifficulty(ranges)).toBe('custom');
 });
});
