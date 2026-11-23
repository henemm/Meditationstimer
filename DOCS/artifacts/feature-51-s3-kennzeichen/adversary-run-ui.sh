#!/bin/zsh
cd /Users/hem/Developer/Meditationstimer/Meditationstimer/.claude/worktrees/cosmic-humming-steele
D=docs/artifacts/feature-51-s3-kennzeichen
for m in ClaudeKennzeichenUITests/testWorkoutRowShowsClaudeBadgeAndInfoShowsPackageAndWhy ClaudeKennzeichenUITests/testBuiltinProgramHasNoClaudeBadge ClaudeKennzeichenUITests/testBreathRowShowsClaudeBadgeAndInfo ClaudeKennzeichenUITests/testBreathMinimalDeliveryStillHasInfoButton ClaudeKennzeichenUITests/testClaudeExerciseInfoShowsTextsOnFirstTap ClaudeKennzeichenUITests/testEditedClaudeProgramShowsAngepasst ClaudeKennzeichenUITests/testClaudeBadgeIsLocalizedInEnglish WorkoutHintUITests/test_infoButton_forPresetPlanke_showsContent; do
  n=${m#*/}
  ./Scripts/run-uitests.sh $m > $D/adversary-ui-$n.txt 2>&1
  echo "$n done"
done
echo ALLDONE
