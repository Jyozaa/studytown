import { describe,expect,it } from 'vitest';
import { clampDuration,focusReward,remainingMs,yawForMovement } from './utils';
describe('StudyTown logic',()=>{
  it('clamps durations',()=>{expect(clampDuration(0)).toBe(1);expect(clampDuration(222)).toBe(180)});
  it('uses timestamps',()=>expect(remainingMs(10_000,7_500)).toBe(2_500));
  it('awards a point per focus minute',()=>expect(focusReward(50)).toBe(50));
  it('orients to all eight movement directions',()=>{const dirs=[[0,1,0],[1,0,Math.PI/2],[0,-1,Math.PI],[-1,0,-Math.PI/2],[1,1,Math.PI/4],[-1,1,-Math.PI/4],[1,-1,Math.PI*3/4],[-1,-1,-Math.PI*3/4]];dirs.forEach(([x,z,y])=>expect(yawForMovement(x,z)).toBeCloseTo(y))});
});
