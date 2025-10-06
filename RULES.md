# AI Development Rules for Meditationstimer Project

## Core Development Principles

### 1. **ASK BEFORE ACTING**
- **Never automatically make code changes without explicit permission**
- When user asks "what should I change?", provide the information/code snippet only
- Only use editing tools when user explicitly says "make this change" or "fix this"
- Exception: Emergency fixes for build-breaking errors may be applied with clear explanation

### 2. **File Editing Safety**
- **ALWAYS include 3-5 lines of context** before and after when using `replace_string_in_file`
- Never use placeholder comments like `...existing code...` or `Lines 123-456 omitted`
- For simple text replacements (like icon names), be extremely careful with context
- If a file edit fails, use `git checkout` to restore rather than attempting multiple corrections

### 3. **Build System Hygiene**
- **NEVER commit build artifacts** (`build/` directory, `.xcbuilddata`, etc.)
- Always check `git status` before committing and unstage build files
- Create/maintain `.gitignore` for Xcode projects
- Unstage user-specific files like `xcuserdata/`

### 4. **Proactive Git Management**
- **Suggest commits before major changes** - Always ask "Should we commit current progress first?"
- **Regular checkpoint commits** - After completing logical units of work (e.g., fixing one major issue)
- **Before risky operations** - Always commit before attempting complex refactoring or file restructuring
- **Clear commit messages** - Suggest descriptive commit messages that explain what was actually fixed
- **Commit working states** - Don't let too many changes accumulate without saving progress

## Project-Specific Guidelines

### Architecture Understanding
This is a **SwiftUI + Combine** meditation timer app with:
- **Multi-target setup**: iOS app + watchOS app
- **HealthKit integration** for mindfulness session logging  
- **Live Activities** for Dynamic Island/Lock Screen
- **Two-phase timer system** (meditation + reflection phases)

### Key Files & Responsibilities
- `ContentView.swift` - **Tab container ONLY**, no timer logic
- `OffenView.swift` - Main meditation timer UI with circular progress
- `AtemView.swift` - Breathing preset management
- `WorkoutsView.swift` - Workout session tracking
- `TwoPhaseTimerEngine.swift` - Core timer state machine
- `HealthKitManager.swift` - Centralized Health integration
- `MeditationEngine.swift` - Session orchestration
- `project.pbxproj` - Critical for build configuration

### Common Issues & Solutions
1. **"Watch-Only Application Stubs" error**: Fix `SDKROOT = iphoneos` in main target
2. **HealthKit logging broken**: Ensure `#if os(watchOS)` conditionals around `UIApplication`
3. **TwoPhaseTimerEngine errors**: Must be provided as `@EnvironmentObject`
4. **Icon changes**: Use correct SF Symbol names, verify with screenshots

### Build & Testing
- **Always test build** after significant changes: `xcodebuild -scheme "Lean Health Timer" build`
- **Check for compiler errors** that tools might miss
- **Verify HealthKit integration** works on both platforms
- **Test Watch App separately** for watchOS-specific issues

## Error Handling Patterns

### When Build Fails
1. Check compiler output carefully
2. Look for platform-specific issues (`#if os(iOS)` vs `#if os(watchOS)`)
3. Verify target settings in `project.pbxproj`
4. Check for missing imports or framework references

### When Files Get Corrupted
1. **Stop immediately** - don't attempt multiple fixes
2. Use `git checkout <filename>` to restore
3. Identify root cause before trying again
4. Consider manual editing for simple changes

### When HealthKit Integration Breaks
1. Check for `UIApplication` usage on watchOS (needs conditional compilation)
2. Verify authorization flow uses proper async/await patterns
3. Ensure `HealthKitManager.shared` singleton pattern is consistent

## Debugging Context

### Tools Limitations
- AI tools may not see all Xcode compiler errors
- Build artifacts can hide real issues
- Platform-specific compilation differences not always visible

### Information Sources
- **Project comments**: Each file has AI orientation comments
- **Git history**: Check recent changes for context
- **Build logs**: Full xcodebuild output shows hidden issues
- **Screenshots**: UI state verification

## Communication Style
- **Be concise** - user prefers direct answers
- **Admit limitations** when tools can't detect issues
- **Explain reasoning** for suggested changes
- **Ask for clarification** rather than assume intent

## Commit Hygiene
- Stage only source code changes
- Exclude build artifacts, user settings, derived data
- Write clear commit messages describing actual fixes
- Group related changes logically

---

*This file should be updated as new patterns and issues are discovered during development.*