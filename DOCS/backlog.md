# Backlog

## Streaks Feature
Implement streak rewards for consistent activity.

### Concept
- **Workout Streaks**: 7 consecutive days of any workout → earn 1 purple flame (max 3 flames)
- **Meditation Streaks**: 7 consecutive days of any meditation → earn 1 light blue lotus flower (max 3 flowers)
- **Decay**: Missing a day removes 1 flame/flower, but streak continues
- **Reset**: Streak breaks only when all flames/flowers are gone and another day is missed

### Implementation Notes
- Track streaks in HealthKit or local storage
- Display flames/lotus in calendar or profile
- Consider UI placement when designing calendar visuals