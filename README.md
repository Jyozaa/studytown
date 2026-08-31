# StudyTown

StudyTown is a cozy browser-based 3D focus game. Pick one of three original study buddies, visit a dense library, a flower-filled garden, or a scenic train, then settle into an authored study spot and let the focus timer run over calm cinematic shots.

## Run it

```bash
npm install
npm run dev
```

Open the printed local URL. Use **WASD** to stroll, **E** to study, **F** to wave, and **Escape** to return to the destination menu. Add `?dev=1` for anchors, colliders, save reset, and the 10-second timer.

## Checks

```bash
npm run typecheck
npm run lint
npm run test
npm run build
```

## Assets

The live scenes use a lightweight procedural React Three Fiber kit so furniture can be composed and recoloured efficiently. The same visual rules are represented in the Blender factory, which exports reusable GLBs:

```bash
npm run assets:generate
```

See [ART_DIRECTION.md](ART_DIRECTION.md), [ASSET_PIPELINE.md](ASSET_PIPELINE.md), and [ARCHITECTURE.md](ARCHITECTURE.md).
