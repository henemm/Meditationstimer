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
    static func info(for exerciseName: String) -> ExerciseInfo? {
        return exercises[exerciseName]
    }

    /// All available exercises indexed by name
    private static let exercises: [String: ExerciseInfo] = {
        var dict: [String: ExerciseInfo] = [:]
        for exercise in allExercises {
            dict[exercise.name] = exercise
        }
        return dict
    }()

    /// Complete list of all documented exercises
    private static let allExercises: [ExerciseInfo] = [
        // MARK: - Cardio / Full Body

        ExerciseInfo(
            name: "Burpees",
            category: .fullBody,
            effect: "Ganzkörper-Übung, die nahezu alle Muskelgruppen aktiviert: Beine, Core, Brust, Schultern, Arme. Verbessert Ausdauer, Explosivkraft und kardiovaskuläre Fitness. Hohe Kalorienverbrennung durch kombinierte Kraft- und Cardio-Belastung.",
            instructions: "1) Stehe aufrecht 2) Gehe in die Hocke und setze Hände auf den Boden 3) Springe mit den Füßen nach hinten in die Planke 4) Optional: Liegestütz 5) Springe mit den Füßen zurück zur Hocke 6) Springe explosiv nach oben mit gestreckten Armen. Achte auf eine kontrollierte Landung und stabile Core-Spannung während der gesamten Bewegung."
        ),

        ExerciseInfo(
            name: "Mountain Climbers",
            category: .cardio,
            effect: "Trainiert Core-Stabilität, Schultern und Beinmuskulatur. Verbessert Koordination und kardiovaskuläre Ausdauer. Aktiviert schräge Bauchmuskulatur durch Rotationsbewegung.",
            instructions: "1) Starte in der Planke-Position mit gestreckten Armen 2) Ziehe abwechselnd das rechte und linke Knie zur Brust 3) Halte die Hüfte tief und den Core angespannt 4) Bewege dich im Lauftempo. Achte darauf, dass die Hüfte nicht nach oben wandert und die Schultern über den Handgelenken bleiben."
        ),

        ExerciseInfo(
            name: "High Knees",
            category: .cardio,
            effect: "Stärkt Hüftbeuger, Quadrizeps und Waden. Verbessert Laufökonomie und Fußgelenk-Mobilität. Erhöht Herzfrequenz schnell für effektives Cardio-Training.",
            instructions: "1) Stehe aufrecht mit hüftbreiten Füßen 2) Hebe abwechselnd die Knie so hoch wie möglich (idealerweise auf Hüfthöhe) 3) Bewege die Arme aktiv mit 4) Lande auf dem Vorfuß und federe ab. Halte den Oberkörper aufrecht und den Core angespannt. Tempo progressiv steigern."
        ),

        ExerciseInfo(
            name: "Hampelmänner",
            category: .cardio,
            effect: "Klassische Cardio-Übung zur Aktivierung des gesamten Körpers. Verbessert Koordination, Ausdauer und dient als effektives Warm-up. Mobilisiert Schultern und Hüften.",
            instructions: "1) Stehe aufrecht mit geschlossenen Beinen und Armen an den Seiten 2) Springe und spreize gleichzeitig die Beine schulterbreit 3) Führe die Arme über den Kopf zusammen 4) Springe zurück zur Ausgangsposition. Lande weich auf den Vorfüßen und halte eine gleichmäßige Atmung."
        ),

        ExerciseInfo(
            name: "Butt Kicks",
            category: .cardio,
            effect: "Aktiviert Hamstrings und Gesäßmuskulatur. Verbessert Beinrückseiten-Flexibilität und Lauftechnik. Ideal als dynamisches Warm-up vor dem Laufen.",
            instructions: "1) Stehe aufrecht 2) Laufe auf der Stelle und bringe die Fersen so nah wie möglich zum Gesäß 3) Bewege die Arme aktiv im Laufrhythmus mit. Halte den Oberkörper aufrecht und vermeide nach vorne Lehnen. Kurzer Bodenkontakt mit dem Vorfuß."
        ),

        ExerciseInfo(
            name: "Marschieren auf der Stelle",
            category: .warmup,
            effect: "Sanftes Aufwärmen, das Herzfrequenz erhöht und Beinmuskulatur aktiviert. Mobilisiert Hüftgelenke und bereitet den Körper auf intensivere Belastung vor.",
            instructions: "1) Stehe aufrecht 2) Hebe abwechselnd die Knie etwa auf Hüfthöhe 3) Schwinge die Arme natürlich mit 4) Halte einen kontrollierten Rhythmus. Atme gleichmäßig und halte den Core leicht angespannt. Ideal als Einstieg für Anfänger."
        ),

        ExerciseInfo(
            name: "Jump-Kniebeugen",
            category: .legs,
            effect: "Plyometrische Übung für explosive Beinkraft. Trainiert Quadrizeps, Gesäß und Waden intensiv. Verbessert Sprungkraft und Schnellkraft.",
            instructions: "1) Stehe mit hüftbreiten Füßen 2) Gehe in eine tiefe Kniebeuge (Oberschenkel parallel zum Boden) 3) Springe explosiv nach oben 4) Lande weich zurück in die Kniebeuge. Achte auf eine kontrollierte Landung mit gebeugten Knien. Knie bleiben über den Füßen, nicht nach innen knicken."
        ),

        // MARK: - Core

        ExerciseInfo(
            name: "Planke",
            category: .core,
            effect: "Die ultimative Core-Übung. Trainiert die gesamte Rumpfmuskulatur (gerade und schräge Bauchmuskeln, unterer Rücken), Schultern und Gesäß. Verbessert Körperspannung und Haltung.",
            instructions: "1) Gehe in die Unterarmstütz-Position mit Ellenbogen unter den Schultern 2) Halte den Körper in einer geraden Linie von Kopf bis Fersen 3) Spanne Core und Gesäß aktiv an 4) Blick zum Boden, Nacken neutral. Vermeide ein Durchhängen der Hüfte oder ein Hochschieben des Gesäßes. Atme gleichmäßig weiter."
        ),

        ExerciseInfo(
            name: "Planke (Knie)",
            category: .core,
            effect: "Vereinfachte Planken-Variante für Anfänger. Trainiert Core-Stabilität mit reduzierter Belastung. Ideal zum Aufbau der Grundkraft.",
            instructions: "1) Gehe in die Unterarmstütz-Position 2) Lege die Knie auf dem Boden ab 3) Halte den Körper von Kopf bis Knie in einer geraden Linie 4) Spanne Core und Gesäß an. Der Fokus liegt auf der Körperspannung, nicht der Dauer. Progressiv zur normalen Planke steigern."
        ),

        ExerciseInfo(
            name: "Seitliche Planke links",
            category: .core,
            effect: "Fokussiert auf schräge Bauchmuskulatur und seitliche Core-Stabilität. Stärkt Schultern und verbessert Balance. Wichtig für Rotationskraft und Verletzungsprävention.",
            instructions: "1) Liege auf der linken Seite, stütze dich auf den linken Unterarm 2) Hebe die Hüfte, bis der Körper eine gerade Linie bildet 3) Stapel die Füße übereinander oder stelle den oberen Fuß vor den unteren 4) Halte die Position. Der rechte Arm kann auf der Hüfte ruhen oder nach oben gestreckt werden."
        ),

        ExerciseInfo(
            name: "Seitliche Planke rechts",
            category: .core,
            effect: "Wie 'Seitliche Planke links', trainiert die rechte Körperseite. Wichtig für symmetrische Core-Entwicklung.",
            instructions: "1) Liege auf der rechten Seite, stütze dich auf den rechten Unterarm 2) Hebe die Hüfte, bis der Körper eine gerade Linie bildet 3) Stapel die Füße übereinander oder stelle den oberen Fuß vor den unteren 4) Halte die Position. Der linke Arm kann auf der Hüfte ruhen oder nach oben gestreckt werden."
        ),

        ExerciseInfo(
            name: "Fahrrad-Crunches",
            category: .core,
            effect: "Dynamische Core-Übung, die gerade und schräge Bauchmuskeln gleichzeitig trainiert. Verbessert Rotationskraft und Koordination.",
            instructions: "1) Liege auf dem Rücken, Hände hinter dem Kopf 2) Hebe Schulterblätter und Beine vom Boden 3) Führe den rechten Ellenbogen zum linken Knie, während das rechte Bein gestreckt wird 4) Wechsel die Seite rhythmisch. Unterer Rücken bleibt am Boden. Atme aus bei der Drehung."
        ),

        ExerciseInfo(
            name: "Beinheben",
            category: .core,
            effect: "Trainiert den unteren Bauch intensiv. Stärkt Hüftbeuger und verbessert Core-Stabilität. Wichtig für eine ausgewogene Rumpfmuskulatur.",
            instructions: "1) Liege auf dem Rücken, Arme neben dem Körper 2) Hebe beide Beine gestreckt an, bis sie senkrecht stehen 3) Senke die Beine langsam ab, ohne dass sie den Boden berühren 4) Wiederhole. Halte den unteren Rücken am Boden gedrückt. Bei Schwierigkeiten: Knie leicht beugen oder geringeren Bewegungsumfang wählen."
        ),

        ExerciseInfo(
            name: "Russian Twists",
            category: .core,
            effect: "Trainiert schräge Bauchmuskeln und Rotationskraft. Verbessert Balance und Core-Stabilität. Relevant für Sportarten mit Drehbewegungen.",
            instructions: "1) Sitze mit angewinkelten Beinen, lehne den Oberkörper leicht zurück 2) Hebe die Füße vom Boden (fortgeschritten) oder lasse sie am Boden 3) Drehe den Oberkörper abwechselnd nach rechts und links 4) Berühre optional den Boden neben der Hüfte. Halte den Core angespannt und vermeide runden Rücken."
        ),

        // MARK: - Legs

        ExerciseInfo(
            name: "Kniebeugen",
            category: .legs,
            effect: "Die Königsübung für die Beine. Trainiert Quadrizeps, Gesäß, Hamstrings und Core. Verbessert funktionelle Kraft, Mobilität und Knochendichte.",
            instructions: "1) Stehe mit hüftbreiten Füßen, Zehen leicht nach außen 2) Beuge die Knie und schiebe das Gesäß nach hinten, als würdest du dich setzen 3) Gehe so tief, wie deine Mobilität es erlaubt (ideal: Oberschenkel parallel zum Boden) 4) Drücke dich über die Fersen nach oben. Knie bleiben über den Füßen, Brust bleibt aufrecht."
        ),

        ExerciseInfo(
            name: "Ausfallschritte",
            category: .legs,
            effect: "Unilaterale Beinübung, die Balance und Koordination verbessert. Trainiert Quadrizeps, Gesäß und Hamstrings. Korrigiert Muskel-Dysbalancen zwischen linkem und rechtem Bein.",
            instructions: "1) Stehe aufrecht 2) Mache einen großen Schritt nach vorne 3) Senke das hintere Knie Richtung Boden, bis beide Knie etwa 90° gebeugt sind 4) Drücke dich über die vordere Ferse zurück in den Stand. Das vordere Knie bleibt über dem Fußgelenk. Wechsel die Beine."
        ),

        ExerciseInfo(
            name: "Reverse-Ausfallschritte",
            category: .legs,
            effect: "Wie normale Ausfallschritte, aber mit Schritt nach hinten. Schonender für die Knie und bessere Balance. Fokussiert stärker auf Gesäßmuskulatur.",
            instructions: "1) Stehe aufrecht 2) Mache einen Schritt nach hinten 3) Senke das hintere Knie Richtung Boden 4) Drücke dich über die vordere Ferse zurück. Diese Variante ist leichter zu kontrollieren und knie-freundlicher als vorwärts gerichtete Ausfallschritte."
        ),

        ExerciseInfo(
            name: "Ausfallschritte gehend",
            category: .legs,
            effect: "Dynamische Variante, die Koordination und Gleichgewicht zusätzlich herausfordert. Ideal als Warm-up für Läufer.",
            instructions: "1) Führe einen Ausfallschritt aus 2) Statt zurückzukehren, bringe das hintere Bein nach vorne in den nächsten Ausfallschritt 3) 'Gehe' so vorwärts. Halte den Oberkörper aufrecht und die Core-Spannung. Konzentriere dich auf eine gleichmäßige Schrittlänge."
        ),

        ExerciseInfo(
            name: "Glute Bridges",
            category: .legs,
            effect: "Isoliert Gesäßmuskulatur und Hamstrings. Aktiviert oft vernachlässigte Muskeln, die beim Sitzen schwach werden. Reduziert untere Rückenschmerzen.",
            instructions: "1) Liege auf dem Rücken, Knie gebeugt, Füße hüftbreit aufgestellt 2) Hebe die Hüfte, bis Knie, Hüfte und Schultern eine Linie bilden 3) Spanne das Gesäß am oberen Punkt aktiv an 4) Senke die Hüfte kontrolliert ab. Drücke durch die Fersen, nicht durch die Zehen."
        ),

        ExerciseInfo(
            name: "Einbeiniges Kreuzheben links",
            category: .legs,
            effect: "Trainiert Hamstrings, Gesäß und unteren Rücken unilateral. Verbessert Balance, Stabilität und Koordination. Korrigiert Asymmetrien.",
            instructions: "1) Stehe auf dem linken Bein, rechtes Bein leicht gebeugt nach hinten 2) Beuge dich in der Hüfte nach vorne, strecke das rechte Bein nach hinten aus 3) Senke den Oberkörper, bis er parallel zum Boden ist (oder so weit wie möglich) 4) Kehre kontrolliert zurück. Halte den Rücken gerade und Core angespannt."
        ),

        ExerciseInfo(
            name: "Einbeiniges Kreuzheben rechts",
            category: .legs,
            effect: "Wie 'Einbeiniges Kreuzheben links', trainiert die rechte Körperseite. Wichtig für symmetrische Beinentwicklung.",
            instructions: "1) Stehe auf dem rechten Bein, linkes Bein leicht gebeugt nach hinten 2) Beuge dich in der Hüfte nach vorne, strecke das linke Bein nach hinten aus 3) Senke den Oberkörper, bis er parallel zum Boden ist (oder so weit wie möglich) 4) Kehre kontrolliert zurück. Halte den Rücken gerade und Core angespannt."
        ),

        ExerciseInfo(
            name: "Bulgarische Split-Kniebeugen links",
            category: .legs,
            effect: "Fortgeschrittene unilaterale Beinübung mit erhöhtem hinteren Fuß. Intensive Aktivierung von Quadrizeps und Gesäß. Verbessert Balance und Flexibilität.",
            instructions: "1) Stelle den rechten Fuß auf eine erhöhte Fläche hinter dir (Bank, Stuhl) 2) Stehe auf dem linken Bein 3) Senke dich in eine tiefe Kniebeuge 4) Drücke dich über die linke Ferse nach oben. Das vordere Knie bleibt über dem Fußgelenk. Oberkörper bleibt aufrecht."
        ),

        ExerciseInfo(
            name: "Bulgarische Split-Kniebeugen rechts",
            category: .legs,
            effect: "Wie 'Bulgarische Split-Kniebeugen links', trainiert das rechte Bein. Wichtig für symmetrische Kraftentwicklung.",
            instructions: "1) Stelle den linken Fuß auf eine erhöhte Fläche hinter dir (Bank, Stuhl) 2) Stehe auf dem rechten Bein 3) Senke dich in eine tiefe Kniebeuge 4) Drücke dich über die rechte Ferse nach oben. Das vordere Knie bleibt über dem Fußgelenk. Oberkörper bleibt aufrecht."
        ),

        ExerciseInfo(
            name: "Wadenheben",
            category: .legs,
            effect: "Isoliertes Training der Wadenmuskulatur (Gastrocnemius und Soleus). Wichtig für Sprungkraft, Laufökonomie und Knöchelstabilität.",
            instructions: "1) Stehe mit den Vorfüßen auf einer erhöhten Fläche (Treppenstufe) oder flach auf dem Boden 2) Hebe die Fersen so hoch wie möglich 3) Halte kurz am oberen Punkt 4) Senke kontrolliert ab. Optional: Einbeinig für höhere Intensität."
        ),

        ExerciseInfo(
            name: "Knieheben stehend",
            category: .legs,
            effect: "Leichte Übung zur Aktivierung der Hüftbeuger und Quadrizeps. Verbessert Balance und Koordination. Ideal für Anfänger.",
            instructions: "1) Stehe aufrecht, Hände auf den Hüften oder vor der Brust 2) Hebe ein Knie langsam bis auf Hüfthöhe 3) Senke es kontrolliert ab 4) Wechsel das Bein. Halte den Oberkörper stabil und vermeide seitliches Schwanken."
        ),

        // MARK: - Upper Body

        ExerciseInfo(
            name: "Liegestütze",
            category: .upperBody,
            effect: "Klassische Oberkörper-Übung. Trainiert Brust, Trizeps, vordere Schultern und Core. Verbessert Druckkraft und funktionelle Oberkörperstärke.",
            instructions: "1) Starte in der Planke-Position mit gestreckten Armen, Hände schulterbreit 2) Senke den Körper ab, bis die Brust fast den Boden berührt 3) Halte die Ellenbogen nah am Körper (ca. 45°) 4) Drücke dich zurück nach oben. Halte den Core angespannt und den Körper in einer Linie. Bei Bedarf: Knie am Boden ablegen."
        ),

        ExerciseInfo(
            name: "Wandliegestütze",
            category: .upperBody,
            effect: "Anfänger-freundliche Liegestütz-Variante. Trainiert Brust, Trizeps und Schultern mit reduzierter Belastung. Ideal zum Technik-Lernen.",
            instructions: "1) Stelle dich etwa armlänge von einer Wand entfernt 2) Platziere die Hände auf Schulterhöhe an der Wand 3) Beuge die Arme und bringe die Brust zur Wand 4) Drücke dich zurück. Halte den Körper gerade und den Core angespannt."
        ),

        ExerciseInfo(
            name: "Diamond-Liegestütze",
            category: .upperBody,
            effect: "Trizeps-fokussierte Liegestütz-Variante. Trainiert Trizeps intensiver als normale Liegestütze, plus Brust und Schultern.",
            instructions: "1) Starte in Planke-Position 2) Platziere die Hände so nah zusammen, dass Daumen und Zeigefinger ein Dreieck (Diamond) bilden 3) Senke den Körper ab 4) Drücke dich zurück. Ellenbogen bleiben eng am Körper. Dies ist anspruchsvoller als normale Liegestütze."
        ),

        ExerciseInfo(
            name: "Breite Liegestütze",
            category: .upperBody,
            effect: "Brust-fokussierte Liegestütz-Variante. Trainiert die äußere Brustmuskulatur stärker als normale Liegestütze.",
            instructions: "1) Starte in Planke-Position 2) Platziere die Hände deutlich breiter als schulterbreit 3) Senke den Körper ab 4) Drücke dich zurück. Die Ellenbogen gehen weiter nach außen als bei normalen Liegestützen."
        ),

        ExerciseInfo(
            name: "Pike-Liegestütze",
            category: .upperBody,
            effect: "Schulter-fokussierte Liegestütz-Variante. Trainiert vordere und seitliche Schultern intensiv. Vorbereitung für Handstand-Liegestütze.",
            instructions: "1) Starte in einer umgedrehten V-Position (Hüfte hoch, Hände und Füße am Boden) 2) Beuge die Arme und bringe den Kopf Richtung Boden 3) Drücke dich zurück. Der Fokus liegt auf den Schultern, nicht der Brust. Je höher die Hüfte, desto schwieriger."
        ),

        ExerciseInfo(
            name: "Planke zu Herabschauender Hund",
            category: .fullBody,
            effect: "Dynamische Übung, die Schultern, Core und Hamstring-Flexibilität kombiniert. Aus Yoga abgeleitet. Verbessert Mobilität und Kraft.",
            instructions: "1) Starte in der Planke 2) Schiebe die Hüfte nach oben und hinten in den Herabschauenden Hund (umgedrehtes V) 3) Strecke die Beine und schiebe die Fersen Richtung Boden 4) Kehre zur Planke zurück. Fließende Bewegung, synchron mit der Atmung."
        ),

        // MARK: - Stretching

        ExerciseInfo(
            name: "Quadrizeps-Dehnung links",
            category: .stretching,
            effect: "Dehnt den vorderen Oberschenkel (Quadrizeps). Reduziert Muskelspannung nach dem Laufen, verbessert Hüftstreckung. Wichtig für Läufer und Radfahrer.",
            instructions: "1) Stehe auf dem rechten Bein 2) Greife den linken Fuß hinter dem Körper 3) Ziehe die Ferse zum Gesäß 4) Halte die Position 22-45 Sekunden. Knie zeigen nach unten, nicht nach vorne. Hüfte bleibt gerade, nicht nach vorne kippen. Optional: An einer Wand abstützen."
        ),

        ExerciseInfo(
            name: "Quadrizeps-Dehnung rechts",
            category: .stretching,
            effect: "Wie 'Quadrizeps-Dehnung links', dehnt den rechten Oberschenkel. Wichtig für symmetrische Flexibilität.",
            instructions: "1) Stehe auf dem linken Bein 2) Greife den rechten Fuß hinter dem Körper 3) Ziehe die Ferse zum Gesäß 4) Halte die Position 22-45 Sekunden. Knie zeigen nach unten, nicht nach vorne. Hüfte bleibt gerade, nicht nach vorne kippen. Optional: An einer Wand abstützen."
        ),

        ExerciseInfo(
            name: "Hamstring-Dehnung links",
            category: .stretching,
            effect: "Dehnt die hintere Oberschenkelmuskulatur (Hamstrings). Reduziert Verletzungsrisiko und verbessert Lauftechnik. Wichtig für gesunden unteren Rücken.",
            instructions: "1) Stehe aufrecht 2) Stelle den linken Fuß nach vorne auf die Ferse, Zehen zeigen nach oben 3) Beuge dich in der Hüfte nach vorne, Rücken gerade 4) Halte die Position. Spüre die Dehnung in der Beinrückseite. Nicht in den Rücken gehen. Alternative: Im Sitzen mit gestrecktem Bein."
        ),

        ExerciseInfo(
            name: "Hamstring-Dehnung rechts",
            category: .stretching,
            effect: "Wie 'Hamstring-Dehnung links', dehnt das rechte Bein. Wichtig für ausgeglichene Flexibilität.",
            instructions: "1) Stehe aufrecht 2) Stelle den rechten Fuß nach vorne auf die Ferse, Zehen zeigen nach oben 3) Beuge dich in der Hüfte nach vorne, Rücken gerade 4) Halte die Position. Spüre die Dehnung in der Beinrückseite. Nicht in den Rücken gehen. Alternative: Im Sitzen mit gestrecktem Bein."
        ),

        ExerciseInfo(
            name: "Hüftbeuger-Dehnung links",
            category: .stretching,
            effect: "Dehnt den Hüftbeuger (Iliopsoas). Extrem wichtig für Menschen, die viel sitzen. Verbessert Hüftstreckung und reduziert untere Rückenschmerzen.",
            instructions: "1) Gehe in einen Ausfallschritt, linkes Bein vorne 2) Senke das rechte Knie zum Boden (auf Matte oder Handtuch) 3) Schiebe die Hüfte nach vorne, bis du eine Dehnung in der rechten Hüfte spürst 4) Halte die Position. Oberkörper bleibt aufrecht. Optional: Arme nach oben strecken für intensivere Dehnung."
        ),

        ExerciseInfo(
            name: "Hüftbeuger-Dehnung rechts",
            category: .stretching,
            effect: "Wie 'Hüftbeuger-Dehnung links', dehnt die rechte Hüfte. Essentiell für Läufer und Büro-Arbeiter.",
            instructions: "1) Gehe in einen Ausfallschritt, rechtes Bein vorne 2) Senke das linke Knie zum Boden (auf Matte oder Handtuch) 3) Schiebe die Hüfte nach vorne, bis du eine Dehnung in der linken Hüfte spürst 4) Halte die Position. Oberkörper bleibt aufrecht. Optional: Arme nach oben strecken für intensivere Dehnung."
        ),

        ExerciseInfo(
            name: "Waden-Dehnung links",
            category: .stretching,
            effect: "Dehnt die Wadenmuskulatur (Gastrocnemius und Soleus). Reduziert Achillessehnen-Probleme und verbessert Knöchel-Mobilität. Wichtig für Läufer.",
            instructions: "1) Stelle dich vor eine Wand 2) Bringe das linke Bein nach vorne (gebeugt) 3) Strecke das rechte Bein nach hinten, Ferse am Boden 4) Lehne dich zur Wand und spüre die Dehnung in der rechten Wade. Ferse bleibt am Boden. Für Soleus (tiefer): Hinteres Knie leicht beugen."
        ),

        ExerciseInfo(
            name: "Waden-Dehnung rechts",
            category: .stretching,
            effect: "Wie 'Waden-Dehnung links', dehnt die rechte Wade. Beugt Achillessehnen-Verletzungen vor.",
            instructions: "1) Stelle dich vor eine Wand 2) Bringe das rechte Bein nach vorne (gebeugt) 3) Strecke das linke Bein nach hinten, Ferse am Boden 4) Lehne dich zur Wand und spüre die Dehnung in der linken Wade. Ferse bleibt am Boden. Für Soleus (tiefer): Hinteres Knie leicht beugen."
        ),

        ExerciseInfo(
            name: "Schmetterlings-Dehnung",
            category: .stretching,
            effect: "Dehnt die Hüftadduktoren (Innenseiten der Oberschenkel) und öffnet die Hüften. Verbessert Hüftmobilität und reduziert Leisten-Verspannungen.",
            instructions: "1) Sitze auf dem Boden 2) Bringe die Fußsohlen zusammen, Knie fallen nach außen 3) Halte die Füße mit den Händen 4) Lehne dich sanft nach vorne für eine tiefere Dehnung. Rücken bleibt gerade. Nicht die Knie nach unten drücken, sondern die Schwerkraft wirken lassen."
        ),

        ExerciseInfo(
            name: "Kindspose",
            category: .cooldown,
            effect: "Entspannende Yoga-Position. Dehnt unteren Rücken, Hüften, Oberschenkel und Schultern. Fördert Entspannung und Regeneration. Perfekt zum Abschluss.",
            instructions: "1) Knie dich hin, Zehen berühren sich, Knie sind breit 2) Setze das Gesäß auf die Fersen 3) Strecke die Arme nach vorne aus und senke die Stirn zum Boden 4) Atme tief und entspanne. Optional: Arme neben dem Körper für mehr Schulter-Entspannung. Verweile mindestens 30 Sekunden."
        ),

        // MARK: - Dynamic Warm-up / Mobility

        ExerciseInfo(
            name: "Beinpendel",
            category: .warmup,
            effect: "Dynamische Mobilitätsübung für Hüftgelenke. Verbessert Bewegungsumfang und bereitet auf explosive Beinarbeit vor. Aktiviert Hüftbeuger und Abduktoren.",
            instructions: "1) Stehe auf einem Bein, optional an einer Wand abstützen 2) Schwinge das freie Bein vor und zurück (sagittale Ebene) oder seitlich (frontale Ebene) 3) Starte klein und steigere den Bewegungsumfang. Halte den Oberkörper stabil, nur das Bein bewegt sich. 10-15 Schwünge pro Bein."
        ),

        ExerciseInfo(
            name: "Hüftkreisen",
            category: .warmup,
            effect: "Mobilisiert Hüftgelenke in alle Richtungen. Verbessert Beweglichkeit und bereitet auf Lauf- oder Sprung-Belastung vor.",
            instructions: "1) Stehe mit hüftbreiten Füßen, Hände auf den Hüften 2) Kreise die Hüfte langsam in großen Kreisen 3) Wechsel die Richtung nach 10 Wiederholungen. Knie bleiben leicht gebeugt. Konzentriere dich auf die volle Bewegungsamplitude."
        ),
    ]
}
