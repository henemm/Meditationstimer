//
//  ExerciseDatabase.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 06.11.25.
//

import Foundation

/// Centralized database of all workout exercise information
struct ExerciseDatabase {
    /// Look up exercise information by name
    /// Automatically strips left/right suffixes for bilateral exercises
    static func info(for exerciseName: String) -> ExerciseInfo? {
        // Direct match first
        if let exercise = exercises[exerciseName] {
            return exercise
        }

        // Try removing left/right suffixes for bilateral exercises
        let suffixes = [" links", " rechts", " Left", " Right", " left", " right"]
        for suffix in suffixes {
            if exerciseName.hasSuffix(suffix) {
                let baseName = String(exerciseName.dropLast(suffix.count))
                if let exercise = exercises[baseName] {
                    return exercise
                }
            }
        }

        return nil
    }

    /// All available exercises indexed by name
    private static let exercises: [String: ExerciseInfo] = {
        var dict: [String: ExerciseInfo] = [:]
        for exercise in allExercises {
            dict[exercise.name] = exercise
        }
        return dict
    }()

    /// Complete list of all documented exercises, in the order of
    /// Contracts/catalog/builtin-exercises.json (append-only)
    private static let allExercises: [ExerciseInfo] = [
        // MARK: - Cardio / Full Body

        ExerciseInfo(
            id: "builtin.burpees",
            name: "Burpees",
            category: .fullBody,
            effect: NSLocalizedString("exercise.burpees.effect", value: "Ganzkörper-Übung, die nahezu alle Muskelgruppen aktiviert: Beine, Core, Brust, Schultern, Arme. Verbessert Ausdauer, Explosivkraft und kardiovaskuläre Fitness. Hohe Kalorienverbrennung durch kombinierte Kraft- und Cardio-Belastung.", comment: "Effect description for Burpees exercise"),
            instructions: NSLocalizedString("exercise.burpees.instructions", value: "1) Stehe aufrecht 2) Gehe in die Hocke und setze Hände auf den Boden 3) Springe mit den Füßen nach hinten in die Planke 4) Optional: Liegestütz 5) Springe mit den Füßen zurück zur Hocke 6) Springe explosiv nach oben mit gestreckten Armen. Achte auf eine kontrollierte Landung und stabile Core-Spannung während der gesamten Bewegung.", comment: "Instructions for Burpees exercise")
        ),

        ExerciseInfo(
            id: "builtin.mountain-climbers",
            name: "Mountain Climbers",
            category: .cardio,
            effect: NSLocalizedString("exercise.mountainClimbers.effect", value: "Trainiert Core-Stabilität, Schultern und Beinmuskulatur. Verbessert Koordination und kardiovaskuläre Ausdauer. Aktiviert schräge Bauchmuskulatur durch Rotationsbewegung.", comment: "Effect description for Mountain Climbers exercise"),
            instructions: NSLocalizedString("exercise.mountainClimbers.instructions", value: "1) Starte in der Planke-Position mit gestreckten Armen 2) Ziehe abwechselnd das rechte und linke Knie zur Brust 3) Halte die Hüfte tief und den Core angespannt 4) Bewege dich im Lauftempo. Achte darauf, dass die Hüfte nicht nach oben wandert und die Schultern über den Handgelenken bleiben.", comment: "Instructions for Mountain Climbers exercise")
        ),

        ExerciseInfo(
            id: "builtin.high-knees",
            name: "High Knees",
            category: .cardio,
            effect: NSLocalizedString("exercise.highKnees.effect", value: "Stärkt Hüftbeuger, Quadrizeps und Waden. Verbessert Laufökonomie und Fußgelenk-Mobilität. Erhöht Herzfrequenz schnell für effektives Cardio-Training.", comment: "Effect description for High Knees exercise"),
            instructions: NSLocalizedString("exercise.highKnees.instructions", value: "1) Stehe aufrecht mit hüftbreiten Füßen 2) Hebe abwechselnd die Knie so hoch wie möglich (idealerweise auf Hüfthöhe) 3) Bewege die Arme aktiv mit 4) Lande auf dem Vorfuß und federe ab. Halte den Oberkörper aufrecht und den Core angespannt. Tempo progressiv steigern.", comment: "Instructions for High Knees exercise")
        ),

        ExerciseInfo(
            id: "builtin.hampelmaenner",
            name: "Hampelmänner",
            category: .cardio,
            effect: NSLocalizedString("exercise.jumpingJacks.effect", value: "Klassische Cardio-Übung zur Aktivierung des gesamten Körpers. Verbessert Koordination, Ausdauer und dient als effektives Warm-up. Mobilisiert Schultern und Hüften.", comment: "Effect description for Jumping Jacks exercise"),
            instructions: NSLocalizedString("exercise.jumpingJacks.instructions", value: "1) Stehe aufrecht mit geschlossenen Beinen und Armen an den Seiten 2) Springe und spreize gleichzeitig die Beine schulterbreit 3) Führe die Arme über den Kopf zusammen 4) Springe zurück zur Ausgangsposition. Lande weich auf den Vorfüßen und halte eine gleichmäßige Atmung.", comment: "Instructions for Jumping Jacks exercise")
        ),

        ExerciseInfo(
            id: "builtin.butt-kicks",
            name: "Butt Kicks",
            category: .cardio,
            effect: NSLocalizedString("exercise.buttKicks.effect", value: "Aktiviert Hamstrings und Gesäßmuskulatur. Verbessert Beinrückseiten-Flexibilität und Lauftechnik. Ideal als dynamisches Warm-up vor dem Laufen.", comment: "Effect description for Butt Kicks exercise"),
            instructions: NSLocalizedString("exercise.buttKicks.instructions", value: "1) Stehe aufrecht 2) Laufe auf der Stelle und bringe die Fersen so nah wie möglich zum Gesäß 3) Bewege die Arme aktiv im Laufrhythmus mit. Halte den Oberkörper aufrecht und vermeide nach vorne Lehnen. Kurzer Bodenkontakt mit dem Vorfuß.", comment: "Instructions for Butt Kicks exercise")
        ),

        ExerciseInfo(
            id: "builtin.marschieren-auf-der-stelle",
            name: "Marschieren auf der Stelle",
            category: .warmup,
            effect: NSLocalizedString("exercise.marchingInPlace.effect", value: "Sanftes Aufwärmen, das Herzfrequenz erhöht und Beinmuskulatur aktiviert. Mobilisiert Hüftgelenke und bereitet den Körper auf intensivere Belastung vor.", comment: "Effect description for Marching in Place exercise"),
            instructions: NSLocalizedString("exercise.marchingInPlace.instructions", value: "1) Stehe aufrecht 2) Hebe abwechselnd die Knie etwa auf Hüfthöhe 3) Schwinge die Arme natürlich mit 4) Halte einen kontrollierten Rhythmus. Atme gleichmäßig und halte den Core leicht angespannt. Ideal als Einstieg für Anfänger.", comment: "Instructions for Marching in Place exercise")
        ),

        ExerciseInfo(
            id: "builtin.jump-kniebeugen",
            name: "Jump-Kniebeugen",
            category: .legs,
            effect: NSLocalizedString("exercise.jumpSquats.effect", value: "Plyometrische Übung für explosive Beinkraft. Trainiert Quadrizeps, Gesäß und Waden intensiv. Verbessert Sprungkraft und Schnellkraft.", comment: "Effect description for Jump Squats exercise"),
            instructions: NSLocalizedString("exercise.jumpSquats.instructions", value: "1) Stehe mit hüftbreiten Füßen 2) Gehe in eine tiefe Kniebeuge (Oberschenkel parallel zum Boden) 3) Springe explosiv nach oben 4) Lande weich zurück in die Kniebeuge. Achte auf eine kontrollierte Landung mit gebeugten Knien. Knie bleiben über den Füßen, nicht nach innen knicken.", comment: "Instructions for Jump Squats exercise")
        ),

        // MARK: - Core

        ExerciseInfo(
            id: "builtin.planke",
            name: "Planke",
            category: .core,
            effect: NSLocalizedString("exercise.plank.effect", value: "Die ultimative Core-Übung. Trainiert die gesamte Rumpfmuskulatur (gerade und schräge Bauchmuskeln, unterer Rücken), Schultern und Gesäß. Verbessert Körperspannung und Haltung.", comment: "Effect description for Plank exercise"),
            instructions: NSLocalizedString("exercise.plank.instructions", value: "1) Gehe in die Unterarmstütz-Position mit Ellenbogen unter den Schultern 2) Halte den Körper in einer geraden Linie von Kopf bis Fersen 3) Spanne Core und Gesäß aktiv an 4) Blick zum Boden, Nacken neutral. Vermeide ein Durchhängen der Hüfte oder ein Hochschieben des Gesäßes. Atme gleichmäßig weiter.", comment: "Instructions for Plank exercise")
        ),

        ExerciseInfo(
            id: "builtin.planke-knie",
            name: "Planke (Knie)",
            category: .core,
            effect: NSLocalizedString("exercise.plankKnees.effect", value: "Vereinfachte Planken-Variante für Anfänger. Trainiert Core-Stabilität mit reduzierter Belastung. Ideal zum Aufbau der Grundkraft.", comment: "Effect description for Knee Plank exercise"),
            instructions: NSLocalizedString("exercise.plankKnees.instructions", value: "1) Gehe in die Unterarmstütz-Position 2) Lege die Knie auf dem Boden ab 3) Halte den Körper von Kopf bis Knie in einer geraden Linie 4) Spanne Core und Gesäß an. Der Fokus liegt auf der Körperspannung, nicht der Dauer. Progressiv zur normalen Planke steigern.", comment: "Instructions for Knee Plank exercise")
        ),

        ExerciseInfo(
            id: "builtin.seitliche-planke-links",
            name: "Seitliche Planke links",
            category: .core,
            effect: NSLocalizedString("exercise.sidePlankLeft.effect", value: "Fokussiert auf schräge Bauchmuskulatur und seitliche Core-Stabilität. Stärkt Schultern und verbessert Balance. Wichtig für Rotationskraft und Verletzungsprävention.", comment: "Effect description for Left Side Plank exercise"),
            instructions: NSLocalizedString("exercise.sidePlankLeft.instructions", value: "1) Liege auf der linken Seite, stütze dich auf den linken Unterarm 2) Hebe die Hüfte, bis der Körper eine gerade Linie bildet 3) Stapel die Füße übereinander oder stelle den oberen Fuß vor den unteren 4) Halte die Position. Der rechte Arm kann auf der Hüfte ruhen oder nach oben gestreckt werden.", comment: "Instructions for Left Side Plank exercise")
        ),

        ExerciseInfo(
            id: "builtin.seitliche-planke-rechts",
            name: "Seitliche Planke rechts",
            category: .core,
            effect: NSLocalizedString("exercise.sidePlankRight.effect", value: "Wie 'Seitliche Planke links', trainiert die rechte Körperseite. Wichtig für symmetrische Core-Entwicklung.", comment: "Effect description for Right Side Plank exercise"),
            instructions: NSLocalizedString("exercise.sidePlankRight.instructions", value: "1) Liege auf der rechten Seite, stütze dich auf den rechten Unterarm 2) Hebe die Hüfte, bis der Körper eine gerade Linie bildet 3) Stapel die Füße übereinander oder stelle den oberen Fuß vor den unteren 4) Halte die Position. Der linke Arm kann auf der Hüfte ruhen oder nach oben gestreckt werden.", comment: "Instructions for Right Side Plank exercise")
        ),

        ExerciseInfo(
            id: "builtin.fahrrad-crunches",
            name: "Fahrrad-Crunches",
            category: .core,
            effect: NSLocalizedString("exercise.bicycleCrunches.effect", value: "Dynamische Core-Übung, die gerade und schräge Bauchmuskeln gleichzeitig trainiert. Verbessert Rotationskraft und Koordination.", comment: "Effect description for Bicycle Crunches exercise"),
            instructions: NSLocalizedString("exercise.bicycleCrunches.instructions", value: "1) Liege auf dem Rücken, Hände hinter dem Kopf 2) Hebe Schulterblätter und Beine vom Boden 3) Führe den rechten Ellenbogen zum linken Knie, während das rechte Bein gestreckt wird 4) Wechsel die Seite rhythmisch. Unterer Rücken bleibt am Boden. Atme aus bei der Drehung.", comment: "Instructions for Bicycle Crunches exercise")
        ),

        ExerciseInfo(
            id: "builtin.beinheben",
            name: "Beinheben",
            category: .core,
            effect: NSLocalizedString("exercise.legRaises.effect", value: "Trainiert den unteren Bauch intensiv. Stärkt Hüftbeuger und verbessert Core-Stabilität. Wichtig für eine ausgewogene Rumpfmuskulatur.", comment: "Effect description for Leg Raises exercise"),
            instructions: NSLocalizedString("exercise.legRaises.instructions", value: "1) Liege auf dem Rücken, Arme neben dem Körper 2) Hebe beide Beine gestreckt an, bis sie senkrecht stehen 3) Senke die Beine langsam ab, ohne dass sie den Boden berühren 4) Wiederhole. Halte den unteren Rücken am Boden gedrückt. Bei Schwierigkeiten: Knie leicht beugen oder geringeren Bewegungsumfang wählen.", comment: "Instructions for Leg Raises exercise")
        ),

        ExerciseInfo(
            id: "builtin.russian-twists",
            name: "Russian Twists",
            category: .core,
            effect: NSLocalizedString("exercise.russianTwists.effect", value: "Trainiert schräge Bauchmuskeln und Rotationskraft. Verbessert Balance und Core-Stabilität. Relevant für Sportarten mit Drehbewegungen.", comment: "Effect description for Russian Twists exercise"),
            instructions: NSLocalizedString("exercise.russianTwists.instructions", value: "1) Sitze mit angewinkelten Beinen, lehne den Oberkörper leicht zurück 2) Hebe die Füße vom Boden (fortgeschritten) oder lasse sie am Boden 3) Drehe den Oberkörper abwechselnd nach rechts und links 4) Berühre optional den Boden neben der Hüfte. Halte den Core angespannt und vermeide runden Rücken.", comment: "Instructions for Russian Twists exercise")
        ),

        // MARK: - Legs

        ExerciseInfo(
            id: "builtin.kniebeugen",
            name: "Kniebeugen",
            category: .legs,
            effect: NSLocalizedString("exercise.squats.effect", value: "Die Königsübung für die Beine. Trainiert Quadrizeps, Gesäß, Hamstrings und Core. Verbessert funktionelle Kraft, Mobilität und Knochendichte.", comment: "Effect description for Squats exercise"),
            instructions: NSLocalizedString("exercise.squats.instructions", value: "1) Stehe mit hüftbreiten Füßen, Zehen leicht nach außen 2) Beuge die Knie und schiebe das Gesäß nach hinten, als würdest du dich setzen 3) Gehe so tief, wie deine Mobilität es erlaubt (ideal: Oberschenkel parallel zum Boden) 4) Drücke dich über die Fersen nach oben. Knie bleiben über den Füßen, Brust bleibt aufrecht.", comment: "Instructions for Squats exercise")
        ),

        ExerciseInfo(
            id: "builtin.ausfallschritte",
            name: "Ausfallschritte",
            category: .legs,
            effect: NSLocalizedString("exercise.lunges.effect", value: "Unilaterale Beinübung, die Balance und Koordination verbessert. Trainiert Quadrizeps, Gesäß und Hamstrings. Korrigiert Muskel-Dysbalancen zwischen linkem und rechtem Bein.", comment: "Effect description for Lunges exercise"),
            instructions: NSLocalizedString("exercise.lunges.instructions", value: "1) Stehe aufrecht 2) Mache einen großen Schritt nach vorne 3) Senke das hintere Knie Richtung Boden, bis beide Knie etwa 90° gebeugt sind 4) Drücke dich über die vordere Ferse zurück in den Stand. Das vordere Knie bleibt über dem Fußgelenk. Wechsel die Beine.", comment: "Instructions for Lunges exercise")
        ),

        ExerciseInfo(
            id: "builtin.reverse-ausfallschritte",
            name: "Reverse-Ausfallschritte",
            category: .legs,
            effect: NSLocalizedString("exercise.reverseLunges.effect", value: "Wie normale Ausfallschritte, aber mit Schritt nach hinten. Schonender für die Knie und bessere Balance. Fokussiert stärker auf Gesäßmuskulatur.", comment: "Effect description for Reverse Lunges exercise"),
            instructions: NSLocalizedString("exercise.reverseLunges.instructions", value: "1) Stehe aufrecht 2) Mache einen Schritt nach hinten 3) Senke das hintere Knie Richtung Boden 4) Drücke dich über die vordere Ferse zurück. Diese Variante ist leichter zu kontrollieren und knie-freundlicher als vorwärts gerichtete Ausfallschritte.", comment: "Instructions for Reverse Lunges exercise")
        ),

        ExerciseInfo(
            id: "builtin.ausfallschritte-gehend",
            name: "Ausfallschritte gehend",
            category: .legs,
            effect: NSLocalizedString("exercise.walkingLunges.effect", value: "Dynamische Variante, die Koordination und Gleichgewicht zusätzlich herausfordert. Ideal als Warm-up für Läufer.", comment: "Effect description for Walking Lunges exercise"),
            instructions: NSLocalizedString("exercise.walkingLunges.instructions", value: "1) Führe einen Ausfallschritt aus 2) Statt zurückzukehren, bringe das hintere Bein nach vorne in den nächsten Ausfallschritt 3) 'Gehe' so vorwärts. Halte den Oberkörper aufrecht und die Core-Spannung. Konzentriere dich auf eine gleichmäßige Schrittlänge.", comment: "Instructions for Walking Lunges exercise")
        ),

        ExerciseInfo(
            id: "builtin.glute-bridges",
            name: "Glute Bridges",
            category: .legs,
            effect: NSLocalizedString("exercise.gluteBridges.effect", value: "Isoliert Gesäßmuskulatur und Hamstrings. Aktiviert oft vernachlässigte Muskeln, die beim Sitzen schwach werden. Reduziert untere Rückenschmerzen.", comment: "Effect description for Glute Bridges exercise"),
            instructions: NSLocalizedString("exercise.gluteBridges.instructions", value: "1) Liege auf dem Rücken, Knie gebeugt, Füße hüftbreit aufgestellt 2) Hebe die Hüfte, bis Knie, Hüfte und Schultern eine Linie bilden 3) Spanne das Gesäß am oberen Punkt aktiv an 4) Senke die Hüfte kontrolliert ab. Drücke durch die Fersen, nicht durch die Zehen.", comment: "Instructions for Glute Bridges exercise")
        ),

        ExerciseInfo(
            id: "builtin.einbeiniges-kreuzheben-links",
            name: "Einbeiniges Kreuzheben links",
            category: .legs,
            effect: NSLocalizedString("exercise.singleLegDeadliftLeft.effect", value: "Trainiert Hamstrings, Gesäß und unteren Rücken unilateral. Verbessert Balance, Stabilität und Koordination. Korrigiert Asymmetrien.", comment: "Effect description for Left Single Leg Deadlift exercise"),
            instructions: NSLocalizedString("exercise.singleLegDeadliftLeft.instructions", value: "1) Stehe auf dem linken Bein, rechtes Bein leicht gebeugt nach hinten 2) Beuge dich in der Hüfte nach vorne, strecke das rechte Bein nach hinten aus 3) Senke den Oberkörper, bis er parallel zum Boden ist (oder so weit wie möglich) 4) Kehre kontrolliert zurück. Halte den Rücken gerade und Core angespannt.", comment: "Instructions for Left Single Leg Deadlift exercise")
        ),

        ExerciseInfo(
            id: "builtin.einbeiniges-kreuzheben-rechts",
            name: "Einbeiniges Kreuzheben rechts",
            category: .legs,
            effect: NSLocalizedString("exercise.singleLegDeadliftRight.effect", value: "Wie 'Einbeiniges Kreuzheben links', trainiert die rechte Körperseite. Wichtig für symmetrische Beinentwicklung.", comment: "Effect description for Right Single Leg Deadlift exercise"),
            instructions: NSLocalizedString("exercise.singleLegDeadliftRight.instructions", value: "1) Stehe auf dem rechten Bein, linkes Bein leicht gebeugt nach hinten 2) Beuge dich in der Hüfte nach vorne, strecke das linke Bein nach hinten aus 3) Senke den Oberkörper, bis er parallel zum Boden ist (oder so weit wie möglich) 4) Kehre kontrolliert zurück. Halte den Rücken gerade und Core angespannt.", comment: "Instructions for Right Single Leg Deadlift exercise")
        ),

        ExerciseInfo(
            id: "builtin.bulgarische-split-kniebeugen-links",
            name: "Bulgarische Split-Kniebeugen links",
            category: .legs,
            effect: NSLocalizedString("exercise.bulgarianSplitSquatLeft.effect", value: "Fortgeschrittene unilaterale Beinübung mit erhöhtem hinteren Fuß. Intensive Aktivierung von Quadrizeps und Gesäß. Verbessert Balance und Flexibilität.", comment: "Effect description for Left Bulgarian Split Squat exercise"),
            instructions: NSLocalizedString("exercise.bulgarianSplitSquatLeft.instructions", value: "1) Stelle den rechten Fuß auf eine erhöhte Fläche hinter dir (Bank, Stuhl) 2) Stehe auf dem linken Bein 3) Senke dich in eine tiefe Kniebeuge 4) Drücke dich über die linke Ferse nach oben. Das vordere Knie bleibt über dem Fußgelenk. Oberkörper bleibt aufrecht.", comment: "Instructions for Left Bulgarian Split Squat exercise")
        ),

        ExerciseInfo(
            id: "builtin.bulgarische-split-kniebeugen-rechts",
            name: "Bulgarische Split-Kniebeugen rechts",
            category: .legs,
            effect: NSLocalizedString("exercise.bulgarianSplitSquatRight.effect", value: "Wie 'Bulgarische Split-Kniebeugen links', trainiert das rechte Bein. Wichtig für symmetrische Kraftentwicklung.", comment: "Effect description for Right Bulgarian Split Squat exercise"),
            instructions: NSLocalizedString("exercise.bulgarianSplitSquatRight.instructions", value: "1) Stelle den linken Fuß auf eine erhöhte Fläche hinter dir (Bank, Stuhl) 2) Stehe auf dem rechten Bein 3) Senke dich in eine tiefe Kniebeuge 4) Drücke dich über die rechte Ferse nach oben. Das vordere Knie bleibt über dem Fußgelenk. Oberkörper bleibt aufrecht.", comment: "Instructions for Right Bulgarian Split Squat exercise")
        ),

        ExerciseInfo(
            id: "builtin.wadenheben",
            name: "Wadenheben",
            category: .legs,
            effect: NSLocalizedString("exercise.calfRaises.effect", value: "Isoliertes Training der Wadenmuskulatur (Gastrocnemius und Soleus). Wichtig für Sprungkraft, Laufökonomie und Knöchelstabilität.", comment: "Effect description for Calf Raises exercise"),
            instructions: NSLocalizedString("exercise.calfRaises.instructions", value: "1) Stehe mit den Vorfüßen auf einer erhöhten Fläche (Treppenstufe) oder flach auf dem Boden 2) Hebe die Fersen so hoch wie möglich 3) Halte kurz am oberen Punkt 4) Senke kontrolliert ab. Optional: Einbeinig für höhere Intensität.", comment: "Instructions for Calf Raises exercise")
        ),

        ExerciseInfo(
            id: "builtin.knieheben-stehend",
            name: "Knieheben stehend",
            category: .legs,
            effect: NSLocalizedString("exercise.standingKneeRaises.effect", value: "Leichte Übung zur Aktivierung der Hüftbeuger und Quadrizeps. Verbessert Balance und Koordination. Ideal für Anfänger.", comment: "Effect description for Standing Knee Raises exercise"),
            instructions: NSLocalizedString("exercise.standingKneeRaises.instructions", value: "1) Stehe aufrecht, Hände auf den Hüften oder vor der Brust 2) Hebe ein Knie langsam bis auf Hüfthöhe 3) Senke es kontrolliert ab 4) Wechsel das Bein. Halte den Oberkörper stabil und vermeide seitliches Schwanken.", comment: "Instructions for Standing Knee Raises exercise")
        ),

        // MARK: - Upper Body

        ExerciseInfo(
            id: "builtin.liegestuetze",
            name: "Liegestütze",
            category: .upperBody,
            effect: NSLocalizedString("exercise.pushups.effect", value: "Klassische Oberkörper-Übung. Trainiert Brust, Trizeps, vordere Schultern und Core. Verbessert Druckkraft und funktionelle Oberkörperstärke.", comment: "Effect description for Push-ups exercise"),
            instructions: NSLocalizedString("exercise.pushups.instructions", value: "1) Starte in der Planke-Position mit gestreckten Armen, Hände schulterbreit 2) Senke den Körper ab, bis die Brust fast den Boden berührt 3) Halte die Ellenbogen nah am Körper (ca. 45°) 4) Drücke dich zurück nach oben. Halte den Core angespannt und den Körper in einer Linie. Bei Bedarf: Knie am Boden ablegen.", comment: "Instructions for Push-ups exercise")
        ),

        ExerciseInfo(
            id: "builtin.wandliegestuetze",
            name: "Wandliegestütze",
            category: .upperBody,
            effect: NSLocalizedString("exercise.wallPushups.effect", value: "Anfänger-freundliche Liegestütz-Variante. Trainiert Brust, Trizeps und Schultern mit reduzierter Belastung. Ideal zum Technik-Lernen.", comment: "Effect description for Wall Push-ups exercise"),
            instructions: NSLocalizedString("exercise.wallPushups.instructions", value: "1) Stelle dich etwa armlänge von einer Wand entfernt 2) Platziere die Hände auf Schulterhöhe an der Wand 3) Beuge die Arme und bringe die Brust zur Wand 4) Drücke dich zurück. Halte den Körper gerade und den Core angespannt.", comment: "Instructions for Wall Push-ups exercise")
        ),

        ExerciseInfo(
            id: "builtin.diamond-liegestuetze",
            name: "Diamond-Liegestütze",
            category: .upperBody,
            effect: NSLocalizedString("exercise.diamondPushups.effect", value: "Trizeps-fokussierte Liegestütz-Variante. Trainiert Trizeps intensiver als normale Liegestütze, plus Brust und Schultern.", comment: "Effect description for Diamond Push-ups exercise"),
            instructions: NSLocalizedString("exercise.diamondPushups.instructions", value: "1) Starte in Planke-Position 2) Platziere die Hände so nah zusammen, dass Daumen und Zeigefinger ein Dreieck (Diamond) bilden 3) Senke den Körper ab 4) Drücke dich zurück. Ellenbogen bleiben eng am Körper. Dies ist anspruchsvoller als normale Liegestütze.", comment: "Instructions for Diamond Push-ups exercise")
        ),

        ExerciseInfo(
            id: "builtin.breite-liegestuetze",
            name: "Breite Liegestütze",
            category: .upperBody,
            effect: NSLocalizedString("exercise.widePushups.effect", value: "Brust-fokussierte Liegestütz-Variante. Trainiert die äußere Brustmuskulatur stärker als normale Liegestütze.", comment: "Effect description for Wide Push-ups exercise"),
            instructions: NSLocalizedString("exercise.widePushups.instructions", value: "1) Starte in Planke-Position 2) Platziere die Hände deutlich breiter als schulterbreit 3) Senke den Körper ab 4) Drücke dich zurück. Die Ellenbogen gehen weiter nach außen als bei normalen Liegestützen.", comment: "Instructions for Wide Push-ups exercise")
        ),

        ExerciseInfo(
            id: "builtin.pike-liegestuetze",
            name: "Pike-Liegestütze",
            category: .upperBody,
            effect: NSLocalizedString("exercise.pikePushups.effect", value: "Schulter-fokussierte Liegestütz-Variante. Trainiert vordere und seitliche Schultern intensiv. Vorbereitung für Handstand-Liegestütze.", comment: "Effect description for Pike Push-ups exercise"),
            instructions: NSLocalizedString("exercise.pikePushups.instructions", value: "1) Starte in einer umgedrehten V-Position (Hüfte hoch, Hände und Füße am Boden) 2) Beuge die Arme und bringe den Kopf Richtung Boden 3) Drücke dich zurück. Der Fokus liegt auf den Schultern, nicht der Brust. Je höher die Hüfte, desto schwieriger.", comment: "Instructions for Pike Push-ups exercise")
        ),

        ExerciseInfo(
            id: "builtin.planke-zu-herabschauender-hund",
            name: "Planke zu Herabschauender Hund",
            category: .fullBody,
            effect: NSLocalizedString("exercise.plankToDownwardDog.effect", value: "Dynamische Übung, die Schultern, Core und Hamstring-Flexibilität kombiniert. Aus Yoga abgeleitet. Verbessert Mobilität und Kraft.", comment: "Effect description for Plank to Downward Dog exercise"),
            instructions: NSLocalizedString("exercise.plankToDownwardDog.instructions", value: "1) Starte in der Planke 2) Schiebe die Hüfte nach oben und hinten in den Herabschauenden Hund (umgedrehtes V) 3) Strecke die Beine und schiebe die Fersen Richtung Boden 4) Kehre zur Planke zurück. Fließende Bewegung, synchron mit der Atmung.", comment: "Instructions for Plank to Downward Dog exercise")
        ),

        // MARK: - Stretching

        ExerciseInfo(
            id: "builtin.quadrizeps-dehnung-links",
            name: "Quadrizeps-Dehnung links",
            category: .stretching,
            effect: NSLocalizedString("exercise.quadStretchLeft.effect", value: "Dehnt den vorderen Oberschenkel (Quadrizeps). Reduziert Muskelspannung nach dem Laufen, verbessert Hüftstreckung. Wichtig für Läufer und Radfahrer.", comment: "Effect description for Left Quad Stretch exercise"),
            instructions: NSLocalizedString("exercise.quadStretchLeft.instructions", value: "1) Stehe auf dem rechten Bein 2) Greife den linken Fuß hinter dem Körper 3) Ziehe die Ferse zum Gesäß 4) Halte die Position 22-45 Sekunden. Knie zeigen nach unten, nicht nach vorne. Hüfte bleibt gerade, nicht nach vorne kippen. Optional: An einer Wand abstützen.", comment: "Instructions for Left Quad Stretch exercise")
        ),

        ExerciseInfo(
            id: "builtin.quadrizeps-dehnung-rechts",
            name: "Quadrizeps-Dehnung rechts",
            category: .stretching,
            effect: NSLocalizedString("exercise.quadStretchRight.effect", value: "Wie 'Quadrizeps-Dehnung links', dehnt den rechten Oberschenkel. Wichtig für symmetrische Flexibilität.", comment: "Effect description for Right Quad Stretch exercise"),
            instructions: NSLocalizedString("exercise.quadStretchRight.instructions", value: "1) Stehe auf dem linken Bein 2) Greife den rechten Fuß hinter dem Körper 3) Ziehe die Ferse zum Gesäß 4) Halte die Position 22-45 Sekunden. Knie zeigen nach unten, nicht nach vorne. Hüfte bleibt gerade, nicht nach vorne kippen. Optional: An einer Wand abstützen.", comment: "Instructions for Right Quad Stretch exercise")
        ),

        ExerciseInfo(
            id: "builtin.hamstring-dehnung-links",
            name: "Hamstring-Dehnung links",
            category: .stretching,
            effect: NSLocalizedString("exercise.hamstringStretchLeft.effect", value: "Dehnt die hintere Oberschenkelmuskulatur (Hamstrings). Reduziert Verletzungsrisiko und verbessert Lauftechnik. Wichtig für gesunden unteren Rücken.", comment: "Effect description for Left Hamstring Stretch exercise"),
            instructions: NSLocalizedString("exercise.hamstringStretchLeft.instructions", value: "1) Stehe aufrecht 2) Stelle den linken Fuß nach vorne auf die Ferse, Zehen zeigen nach oben 3) Beuge dich in der Hüfte nach vorne, Rücken gerade 4) Halte die Position. Spüre die Dehnung in der Beinrückseite. Nicht in den Rücken gehen. Alternative: Im Sitzen mit gestrecktem Bein.", comment: "Instructions for Left Hamstring Stretch exercise")
        ),

        ExerciseInfo(
            id: "builtin.hamstring-dehnung-rechts",
            name: "Hamstring-Dehnung rechts",
            category: .stretching,
            effect: NSLocalizedString("exercise.hamstringStretchRight.effect", value: "Wie 'Hamstring-Dehnung links', dehnt das rechte Bein. Wichtig für ausgeglichene Flexibilität.", comment: "Effect description for Right Hamstring Stretch exercise"),
            instructions: NSLocalizedString("exercise.hamstringStretchRight.instructions", value: "1) Stehe aufrecht 2) Stelle den rechten Fuß nach vorne auf die Ferse, Zehen zeigen nach oben 3) Beuge dich in der Hüfte nach vorne, Rücken gerade 4) Halte die Position. Spüre die Dehnung in der Beinrückseite. Nicht in den Rücken gehen. Alternative: Im Sitzen mit gestrecktem Bein.", comment: "Instructions for Right Hamstring Stretch exercise")
        ),

        ExerciseInfo(
            id: "builtin.hueftbeuger-dehnung-links",
            name: "Hüftbeuger-Dehnung links",
            category: .stretching,
            effect: NSLocalizedString("exercise.hipFlexorStretchLeft.effect", value: "Dehnt den Hüftbeuger (Iliopsoas). Extrem wichtig für Menschen, die viel sitzen. Verbessert Hüftstreckung und reduziert untere Rückenschmerzen.", comment: "Effect description for Left Hip Flexor Stretch exercise"),
            instructions: NSLocalizedString("exercise.hipFlexorStretchLeft.instructions", value: "1) Gehe in einen Ausfallschritt, linkes Bein vorne 2) Senke das rechte Knie zum Boden (auf Matte oder Handtuch) 3) Schiebe die Hüfte nach vorne, bis du eine Dehnung in der rechten Hüfte spürst 4) Halte die Position. Oberkörper bleibt aufrecht. Optional: Arme nach oben strecken für intensivere Dehnung.", comment: "Instructions for Left Hip Flexor Stretch exercise")
        ),

        ExerciseInfo(
            id: "builtin.hueftbeuger-dehnung-rechts",
            name: "Hüftbeuger-Dehnung rechts",
            category: .stretching,
            effect: NSLocalizedString("exercise.hipFlexorStretchRight.effect", value: "Wie 'Hüftbeuger-Dehnung links', dehnt die rechte Hüfte. Essentiell für Läufer und Büro-Arbeiter.", comment: "Effect description for Right Hip Flexor Stretch exercise"),
            instructions: NSLocalizedString("exercise.hipFlexorStretchRight.instructions", value: "1) Gehe in einen Ausfallschritt, rechtes Bein vorne 2) Senke das linke Knie zum Boden (auf Matte oder Handtuch) 3) Schiebe die Hüfte nach vorne, bis du eine Dehnung in der linken Hüfte spürst 4) Halte die Position. Oberkörper bleibt aufrecht. Optional: Arme nach oben strecken für intensivere Dehnung.", comment: "Instructions for Right Hip Flexor Stretch exercise")
        ),

        ExerciseInfo(
            id: "builtin.waden-dehnung-links",
            name: "Waden-Dehnung links",
            category: .stretching,
            effect: NSLocalizedString("exercise.calfStretchLeft.effect", value: "Dehnt die Wadenmuskulatur (Gastrocnemius und Soleus). Reduziert Achillessehnen-Probleme und verbessert Knöchel-Mobilität. Wichtig für Läufer.", comment: "Effect description for Left Calf Stretch exercise"),
            instructions: NSLocalizedString("exercise.calfStretchLeft.instructions", value: "1) Stelle dich vor eine Wand 2) Bringe das linke Bein nach vorne (gebeugt) 3) Strecke das rechte Bein nach hinten, Ferse am Boden 4) Lehne dich zur Wand und spüre die Dehnung in der rechten Wade. Ferse bleibt am Boden. Für Soleus (tiefer): Hinteres Knie leicht beugen.", comment: "Instructions for Left Calf Stretch exercise")
        ),

        ExerciseInfo(
            id: "builtin.waden-dehnung-rechts",
            name: "Waden-Dehnung rechts",
            category: .stretching,
            effect: NSLocalizedString("exercise.calfStretchRight.effect", value: "Wie 'Waden-Dehnung links', dehnt die rechte Wade. Beugt Achillessehnen-Verletzungen vor.", comment: "Effect description for Right Calf Stretch exercise"),
            instructions: NSLocalizedString("exercise.calfStretchRight.instructions", value: "1) Stelle dich vor eine Wand 2) Bringe das rechte Bein nach vorne (gebeugt) 3) Strecke das linke Bein nach hinten, Ferse am Boden 4) Lehne dich zur Wand und spüre die Dehnung in der linken Wade. Ferse bleibt am Boden. Für Soleus (tiefer): Hinteres Knie leicht beugen.", comment: "Instructions for Right Calf Stretch exercise")
        ),

        ExerciseInfo(
            id: "builtin.schmetterlings-dehnung",
            name: "Schmetterlings-Dehnung",
            category: .stretching,
            effect: NSLocalizedString("exercise.butterflyStretch.effect", value: "Dehnt die Hüftadduktoren (Innenseiten der Oberschenkel) und öffnet die Hüften. Verbessert Hüftmobilität und reduziert Leisten-Verspannungen.", comment: "Effect description for Butterfly Stretch exercise"),
            instructions: NSLocalizedString("exercise.butterflyStretch.instructions", value: "1) Sitze auf dem Boden 2) Bringe die Fußsohlen zusammen, Knie fallen nach außen 3) Halte die Füße mit den Händen 4) Lehne dich sanft nach vorne für eine tiefere Dehnung. Rücken bleibt gerade. Nicht die Knie nach unten drücken, sondern die Schwerkraft wirken lassen.", comment: "Instructions for Butterfly Stretch exercise")
        ),

        ExerciseInfo(
            id: "builtin.kindspose",
            name: "Kindspose",
            category: .cooldown,
            effect: NSLocalizedString("exercise.childsPose.effect", value: "Entspannende Yoga-Position. Dehnt unteren Rücken, Hüften, Oberschenkel und Schultern. Fördert Entspannung und Regeneration. Perfekt zum Abschluss.", comment: "Effect description for Child's Pose exercise"),
            instructions: NSLocalizedString("exercise.childsPose.instructions", value: "1) Knie dich hin, Zehen berühren sich, Knie sind breit 2) Setze das Gesäß auf die Fersen 3) Strecke die Arme nach vorne aus und senke die Stirn zum Boden 4) Atme tief und entspanne. Optional: Arme neben dem Körper für mehr Schulter-Entspannung. Verweile mindestens 30 Sekunden.", comment: "Instructions for Child's Pose exercise")
        ),

        // MARK: - Dynamic Warm-up / Mobility

        ExerciseInfo(
            id: "builtin.beinpendel",
            name: "Beinpendel",
            category: .warmup,
            effect: NSLocalizedString("exercise.legSwings.effect", value: "Dynamische Mobilitätsübung für Hüftgelenke. Verbessert Bewegungsumfang und bereitet auf explosive Beinarbeit vor. Aktiviert Hüftbeuger und Abduktoren.", comment: "Effect description for Leg Swings exercise"),
            instructions: NSLocalizedString("exercise.legSwings.instructions", value: "1) Stehe auf einem Bein, optional an einer Wand abstützen 2) Schwinge das freie Bein vor und zurück (sagittale Ebene) oder seitlich (frontale Ebene) 3) Starte klein und steigere den Bewegungsumfang. Halte den Oberkörper stabil, nur das Bein bewegt sich. 10-15 Schwünge pro Bein.", comment: "Instructions for Leg Swings exercise")
        ),

        ExerciseInfo(
            id: "builtin.hueftkreisen",
            name: "Hüftkreisen",
            category: .warmup,
            effect: NSLocalizedString("exercise.hipCircles.effect", value: "Mobilisiert Hüftgelenke in alle Richtungen. Verbessert Beweglichkeit und bereitet auf Lauf- oder Sprung-Belastung vor.", comment: "Effect description for Hip Circles exercise"),
            instructions: NSLocalizedString("exercise.hipCircles.instructions", value: "1) Stehe mit hüftbreiten Füßen, Hände auf den Hüften 2) Kreise die Hüfte langsam in großen Kreisen 3) Wechsel die Richtung nach 10 Wiederholungen. Knie bleiben leicht gebeugt. Konzentriere dich auf die volle Bewegungsamplitude.", comment: "Instructions for Hip Circles exercise")
        ),
    ]
}

/// Localized name, effect and instructions of a catalog exercise
struct ExerciseTexts: Equatable {
    let name: String
    let effect: String
    let instructions: String
}

// MARK: - Catalog with fixed ids (#48)

extension ExerciseDatabase {
    /// All catalog exercises in the order of Contracts/catalog/builtin-exercises.json
    static var catalog: [ExerciseInfo] { allExercises }

    private static let infoById: [String: ExerciseInfo] =
        Dictionary(allExercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    /// Look up a catalog exercise by its fixed id
    static func info(forId id: String) -> ExerciseInfo? {
        infoById[id]
    }

    /// English names of the former suggestion list → catalog id (fixed table, no runtime translation)
    private static let englishNameIds: [String: String] = [
        "Plank": "builtin.planke",
        "Side Plank Left": "builtin.seitliche-planke-links",
        "Side Plank Right": "builtin.seitliche-planke-rechts",
        "Bicycle Crunches": "builtin.fahrrad-crunches",
        "Leg Raises": "builtin.beinheben",
        "Plank to Downward Dog": "builtin.planke-zu-herabschauender-hund",
        "Push-ups": "builtin.liegestuetze",
        "Diamond Push-ups": "builtin.diamond-liegestuetze",
        "Wide Push-ups": "builtin.breite-liegestuetze",
        "Pike Push-ups": "builtin.pike-liegestuetze",
        "Wall Push-ups": "builtin.wandliegestuetze",
        "Squats": "builtin.kniebeugen",
        "Jump Squats": "builtin.jump-kniebeugen",
        "Lunges": "builtin.ausfallschritte",
        "Reverse Lunges": "builtin.reverse-ausfallschritte",
        "Walking Lunges": "builtin.ausfallschritte-gehend",
        "Bulgarian Split Squats Left": "builtin.bulgarische-split-kniebeugen-links",
        "Bulgarian Split Squats Right": "builtin.bulgarische-split-kniebeugen-rechts",
        "Single-Leg Deadlift Left": "builtin.einbeiniges-kreuzheben-links",
        "Single-Leg Deadlift Right": "builtin.einbeiniges-kreuzheben-rechts",
        "Calf Raises": "builtin.wadenheben",
        "Standing Knee Raises": "builtin.knieheben-stehend",
        "Jumping Jacks": "builtin.hampelmaenner",
        "Marching in Place": "builtin.marschieren-auf-der-stelle",
        "Child's Pose": "builtin.kindspose",
        "Butterfly Stretch": "builtin.schmetterlings-dehnung",
        "Hip Flexor Stretch Left": "builtin.hueftbeuger-dehnung-links",
        "Hip Flexor Stretch Right": "builtin.hueftbeuger-dehnung-rechts",
        "Quadriceps Stretch Left": "builtin.quadrizeps-dehnung-links",
        "Quadriceps Stretch Right": "builtin.quadrizeps-dehnung-rechts",
        "Hamstring Stretch Left": "builtin.hamstring-dehnung-links",
        "Hamstring Stretch Right": "builtin.hamstring-dehnung-rechts",
        "Calf Stretch Left": "builtin.waden-dehnung-links",
        "Calf Stretch Right": "builtin.waden-dehnung-rechts",
        "Hip Circles": "builtin.hueftkreisen",
        "Leg Swing Left": "builtin.beinpendel",
        "Leg Swing Right": "builtin.beinpendel",
    ]

    /// Comparison key: without surrounding whitespace, case-insensitive
    private static func lookupKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static let idByGermanName: [String: String] =
        Dictionary(allExercises.map { (lookupKey($0.name), $0.id) }, uniquingKeysWith: { first, _ in first })

    private static let idByEnglishName: [String: String] =
        Dictionary(englishNameIds.map { (lookupKey($0.key), $0.value) }, uniquingKeysWith: { first, _ in first })

    /// Id for a stored exercise name (Spec #48, Entscheidung 4): German catalog name, English name,
    /// name with suffix "links"/"rechts" on a catalog exercise, otherwise own.<slug>. Never empty.
    static func exerciseId(forName name: String) -> String {
        let key = lookupKey(name)
        if let id = idByGermanName[key] ?? idByEnglishName[key] {
            return id
        }
        for suffix in [" links", " rechts"] where key.hasSuffix(suffix) {
            if let id = idByGermanName[lookupKey(String(key.dropLast(suffix.count)))] {
                return id
            }
        }
        return ownExerciseId(forName: name)
    }

    /// "own.<slug>" for a user-defined exercise name (Spec #48, Entscheidung 5)
    static func ownExerciseId(forName name: String) -> String {
        "own." + slug(name)
    }

    /// Lowercase ASCII slug: umlauts transliterated, other accents removed, runs of other characters → "-",
    /// at least 2 and at most 63 characters
    private static func slug(_ name: String) -> String {
        var text = name.precomposedStringWithCanonicalMapping.lowercased()
        for (umlaut, replacement) in [("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")] {
            text = text.replacingOccurrences(of: umlaut, with: replacement)
        }
        text = text.folding(options: .diacriticInsensitive, locale: nil)
        var result = ""
        var pendingDash = false
        for scalar in text.unicodeScalars {
            guard ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) else {
                pendingDash = true
                continue
            }
            if pendingDash && !result.isEmpty { result.append("-") }
            result.unicodeScalars.append(scalar)
            pendingDash = false
        }
        if result.isEmpty { return "uebung" }
        if result.count < 2 { result = "uebung-" + result }
        if result.count > 63 {
            result = String(result.prefix(63))
            while result.hasSuffix("-") { result.removeLast() }
        }
        return result
    }

    /// Display name: localized catalog name for builtin.*; stored name for own.*, claude.*, unknown or nil
    static func displayName(exerciseId: String?, storedName: String, bundle: Bundle = .main) -> String {
        guard let id = exerciseId, ExerciseOrigin(exerciseId: id) == .builtin, let info = info(forId: id) else {
            return storedName
        }
        return bundle.localizedString(forKey: info.name, value: info.name, table: nil)
    }

    /// Name, effect and instructions of a catalog exercise in the language of `bundle`.
    /// Stand A2a: only the name follows `bundle`; effect/instructions per bundle follow in A2d (AC-8).
    static func localizedTexts(forId id: String, bundle: Bundle) -> ExerciseTexts? {
        guard let info = info(forId: id) else { return nil }
        let name = bundle.localizedString(forKey: info.name, value: info.name, table: nil)
        return ExerciseTexts(name: name, effect: info.effect, instructions: info.instructions)
    }
}
