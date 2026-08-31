import type { SceneDefinition, SceneId } from './types';

const shots = (scene:SceneId) => {
  if(scene==='library') return [
    [[10,9,13],[0,1,0]], [[4,3.5,7],[-1,1,-1]], [[-5,4,5],[1,1,-1]],
    [[-7,3,0],[0,1,-1]], [[6,3,-2],[0,1,1]], [[0,5,-8],[0,1,0]],
  ];
  if(scene==='garden') return [
    [[10,8,12],[0,1,0]], [[5,3,7],[0,1,-1]], [[-7,3,5],[0,1,0]],
    [[-5,2,-3],[1,1,0]], [[3,3,-7],[0,1,1]], [[0,6,10],[0,1,0]],
  ];
  return [
    [[10,7,13],[0,1,0]], [[5,3,5],[0,1,-1]], [[-4,3,4],[1,1,0]],
    [[0,2,-6],[0,1,0]], [[9,4,-2],[0,1,-4]], [[-9,5,-3],[0,1,-4]], [[2,8,12],[0,0,0]],
  ];
};

const makeShots=(id:SceneId)=>shots(id).map(([position,target],i)=>({position:position as [number,number,number],target:target as [number,number,number],duration:18+i*2,transitionDuration:3,endPosition:[position[0]+(i%2?.7:-.5),position[1]+.2,position[2]] as [number,number,number]}));
export const scenes:Record<SceneId,SceneDefinition> = {
  library:{id:'library',name:'The Lantern Library',subtitle:'Warm & quiet',loading:'Stacking the books…',explorationCamera:{position:[11,10,14],target:[0,0,-1]},playerSpawn:[0,0,4.2],bounds:{x:[-6.2,6.2],z:[-4.5,5]},studySpots:[
    {id:'library-desk',label:'Study at the oak desk',standingPosition:[2.2,0,2.8],standingRotation:Math.PI,sittingPosition:[2.2,.54,1.95],sittingRotation:Math.PI,animation:'typing',cameraTarget:[2.2,1.2,1.6],cinematicProfile:'desk'},
    {id:'library-chair',label:'Read by the fire',standingPosition:[-2.2,0,.2],standingRotation:-Math.PI/2,sittingPosition:[-3.05,.52,.2],sittingRotation:-Math.PI/2,animation:'reading',cameraTarget:[-3,1.2,.2],cinematicProfile:'fire'},
  ],cinematicShots:makeShots('library')},
  garden:{id:'garden',name:'Sunpetal Garden',subtitle:'Fresh & peaceful',loading:'Watering the flowers…',explorationCamera:{position:[12,10,15],target:[0,0,0]},playerSpawn:[0,0,4],bounds:{x:[-6.6,6.6],z:[-4.8,5]},studySpots:[
    {id:'garden-table',label:'Study under the tree',standingPosition:[2,0,.9],standingRotation:Math.PI,sittingPosition:[2,.52,.1],sittingRotation:Math.PI,animation:'typing',cameraTarget:[2,1.1,0],cinematicProfile:'tree'},
    {id:'garden-blanket',label:'Read on the picnic blanket',standingPosition:[-3,0,2.3],standingRotation:Math.PI,sittingPosition:[-3,.12,1.7],sittingRotation:Math.PI,animation:'reading',cameraTarget:[-3,.8,1.5],cinematicProfile:'picnic'},
  ],cinematicShots:makeShots('garden')},
  train:{id:'train',name:'The Daydream Line',subtitle:'Study on the move',loading:'Waiting for the train…',explorationCamera:{position:[10,7,13],target:[0,.4,0]},playerSpawn:[0,0,3.1],bounds:{x:[-5.7,5.7],z:[-2.4,3.8]},studySpots:[
    {id:'train-table',label:'Study by the window',standingPosition:[2.2,0,.8],standingRotation:Math.PI,sittingPosition:[2.2,.55,.05],sittingRotation:Math.PI,animation:'typing',cameraTarget:[2.2,1.2,-.1],cinematicProfile:'window'},
    {id:'train-seat',label:'Read in the window seat',standingPosition:[-2.5,0,1],standingRotation:Math.PI,sittingPosition:[-2.5,.56,.15],sittingRotation:Math.PI,animation:'reading',cameraTarget:[-2.5,1.2,0],cinematicProfile:'journey'},
  ],cinematicShots:makeShots('train')},
};
