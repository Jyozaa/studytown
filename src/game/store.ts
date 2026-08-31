import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { SceneId } from './types';

type Screen='menu'|'loading'|'game';
interface Progress { totalFocusMinutes:number; completedSessions:number; focusPoints:number; }
interface GameState { screen:Screen; scene:SceneId|null; character:number; focusEnd:number|null; focusMinutes:number; activeSpot:string|null; completion:boolean; progress:Progress; setCharacter:(n:number)=>void; enterScene:(id:SceneId)=>void; finishLoading:()=>void; menu:()=>void; startFocus:(spot:string,minutes:number)=>void; endFocus:(completed?:boolean)=>void; clearCompletion:()=>void; reset:()=>void; }
const defaults:Progress={totalFocusMinutes:0,completedSessions:0,focusPoints:0};
export const useGameStore=create<GameState>()(persist((set,get)=>({screen:'menu',scene:null,character:0,focusEnd:null,focusMinutes:25,activeSpot:null,completion:false,progress:defaults,
  setCharacter:(character)=>set({character}),
  enterScene:(scene)=>set({scene,screen:'loading',completion:false}), finishLoading:()=>set({screen:'game'}), menu:()=>set({screen:'menu',focusEnd:null,activeSpot:null,completion:false}),
  startFocus:(activeSpot,focusMinutes)=>set({activeSpot,focusMinutes,focusEnd:Date.now()+focusMinutes*60_000,completion:false}),
  endFocus:(completed=false)=>{const s=get();set({focusEnd:null,activeSpot:null,completion:completed,progress:completed?{totalFocusMinutes:s.progress.totalFocusMinutes+s.focusMinutes,completedSessions:s.progress.completedSessions+1,focusPoints:s.progress.focusPoints+s.focusMinutes}:s.progress})},
  clearCompletion:()=>set({completion:false}),reset:()=>set({progress:defaults,character:0,focusEnd:null,activeSpot:null,completion:false})
}),{name:'studytown-save',partialize:(s)=>({character:s.character,progress:s.progress})}));
