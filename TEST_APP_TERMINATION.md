# App-Termination Test

## Test Plan

### Erwartetes Verhalten:
Timer soll stoppen wenn:
1. App in Hintergrund geht (.background)
2. App inaktiv wird (.inactive) 
3. App beendet wird (UIApplication.willTerminateNotification)

### Tatsächliche Implementation Probleme:

1. **ScenePhase Notification funktioniert möglicherweise nicht**
   - Notification wird in App gesendet, aber erreicht Engine nicht
   - NotificationCenter Subscription könnte falsch sein

2. **UIApplication.willTerminateNotification wird in iOS Simulator kaum ausgelöst**
   - Simulator "beendet" Apps nicht wie echtes Device
   - Force-Quit funktioniert anders

3. **Mögliche Race Conditions**
   - Engine wird erstellt bevor App lifecycle setup komplett ist
   - Subscriptions werden zu spät registriert

### Echte Tests die ich machen sollte:

1. **Unit Test für die Timer Engine Logik**
2. **Integration Test der NotificationCenter Verbindung**  
3. **Real Device Test** (nicht Simulator)

### Was ich als nächstes machen werde:

1. Erst mal prüfen ob meine Notifications überhaupt ankommen
2. Dann echtes Gerät testen
3. Dann sicherstellen dass die Logik stimmt