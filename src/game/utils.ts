import type { Vec3 } from './types';
export const yawForMovement=(x:number,z:number)=>Math.atan2(x,z);
export const clampDuration=(minutes:number)=>Math.max(1,Math.min(180,Math.round(minutes)));
export const remainingMs=(endTimestamp:number,now=Date.now())=>Math.max(0,endTimestamp-now);
export const focusReward=(minutes:number)=>Math.max(1,Math.round(minutes));
export const distanceXZ=(a:Vec3,b:Vec3)=>Math.hypot(a[0]-b[0],a[2]-b[2]);
export const formatTime=(ms:number)=>{const total=Math.ceil(ms/1000);return `${String(Math.floor(total/60)).padStart(2,'0')}:${String(total%60).padStart(2,'0')}`};
