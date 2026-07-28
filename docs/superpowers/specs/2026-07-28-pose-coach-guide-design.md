# Pose Coach Guide (方案 B) Design

**Date:** 2026-07-28  
**Status:** Approved (user: B)

## Goal
Fullscreen landscape pose coaching with white stage frame + exercise silhouette + live skeleton alignment feedback; BMI-based camera exercise prescription.

## Architecture
- `ExercisePage` owns camera services; on start detection → lock landscape → push `PoseCoachPage`.
- Live stats via `ValueNotifier`s (landmarks, reps, feedback, combo, stamina).
- On pop / stop → stop detection, restore portrait orientations.
- `PoseCoachGuideOverlay` paints vignette + white frame + stick silhouette; alignment tint from landmarks vs frame.

## Files
- Create: `lib/widgets/exercise/pose_coach_guide.dart`
- Create: `lib/pages/pose_coach_page.dart`
- Create: `lib/services/exercise_prescription.dart`
- Modify: `lib/pages/exercise_page.dart`
- Spec: this file
