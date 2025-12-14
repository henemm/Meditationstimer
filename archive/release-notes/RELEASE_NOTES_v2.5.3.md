# Release Notes v2.5.3

## 🐛 Bugfixes

### Atem Tab
- **Touch Areas**: Edit buttons ("...") now have proper touch targets (44x44pt instead of 32x32pt) for better accessibility
- **Dynamic Island**: Fixed arrows getting stuck pointing down after breathing rounds by optimizing Live Activity update performance

### Workouts Tab
- **Dynamic Island**: Fixed arrow direction updates getting stuck
- **Audio**: Restored sound playback functionality that was affected by Live Activity changes
- **Performance**: Removed serialization bottleneck that slowed down Live Activity updates

## 🔧 Technical Improvements
- Optimized Live Activity update timing by removing unnecessary serialization
- Enhanced debug logging for sound systems and Live Activity updates
- Improved audio session configuration reliability

## 📱 Compatibility
- iOS 16.1+ (Live Activities)
- All existing features preserved

## 🧪 Testing
- Verified touch areas meet iOS accessibility guidelines
- Confirmed Dynamic Island arrows update correctly during sessions
- Validated all workout sounds play properly
- Live Activity updates work reliably across both Atem and Workouts tabs

---

*Released: 25. Oktober 2025*