export type Vec3 = [number, number, number];
export type SceneId = 'library' | 'garden' | 'train';
export type StudyAnimation = 'typing' | 'reading';
export interface StudySpot { id:string; label:string; standingPosition:Vec3; standingRotation:number; sittingPosition:Vec3; sittingRotation:number; animation:StudyAnimation; cameraTarget:Vec3; cinematicProfile:string; }
export interface CinematicShot { position:Vec3; target:Vec3; duration:number; transitionDuration:number; endPosition?:Vec3; }
export interface SceneDefinition { id:SceneId; name:string; subtitle:string; loading:string; explorationCamera:{position:Vec3;target:Vec3}; playerSpawn:Vec3; bounds:{x:[number,number];z:[number,number]}; studySpots:StudySpot[]; cinematicShots:CinematicShot[]; }
