# Hybrid Athlete – Project Documentation

> **Status:** Living document (v0.1)
>  
> This documentation describes the Hybrid Athlete application as an evolving, real-world software project. Features and implementation details may expand over time as the application continues active daily use by its developer.

---

## 1. Project Overview

### 1.1 Problem Statement

Hybrid athletes who combine strength training, running, and team sports (such as futsal) often rely on multiple applications to track their training. Existing fitness applications typically focus on a single domain (e.g., gym workouts or running) and fail to support mixed training models in a unified, practical way.

This fragmentation leads to:
- Incomplete training history
- Inconsistent statistics across disciplines
- Poor support for sport-specific metrics (e.g., futsal sessions)
- Reduced usability for athletes training daily across modalities

### 1.2 Project Goal

The goal of the Hybrid Athlete project is to design and implement a **single, cross-platform application** that allows hybrid athletes to:
- Log strength training, running, and futsal sessions
- Track progress over time
- Maintain motivation through goals and badges
- Use the application daily with minimal friction

The application was developed to solve a real personal need and is actively used by the developer in daily training.

---

## 2. Target Users

### Primary User Persona
- Hybrid athlete
- Combines gym-based strength training, running, and team sports
- Trains multiple times per week
- Requires fast logging and meaningful statistics

### Secondary Users
- Recreational athletes
- Team sport players seeking structured tracking

---

## 3. Functional Requirements (High-Level)

The system shall provide the following core functionalities:

### 3.1 Training Logging
- Log gym workouts with sets, reps, and weights
- Log running sessions with distance, duration, and pace
- Log futsal sessions with per-game statistics

### 3.2 Workout Management
- Create and manage workout templates
- Schedule workouts using a calendar interface
- Start, cancel, and complete scheduled workouts

### 3.3 Analytics & Feedback
- Weekly and historical statistics
- Personal records tracking
- Streak and consistency tracking

### 3.4 User Engagement
- Badge and achievement system
- Goal setting for key exercises and performance metrics

### 3.5 Customization
- Custom exercises and templates
- Editable user profile

---

## 4. Non-Functional Requirements

- Offline-first operation
- Cross-platform compatibility (mobile, desktop, web)
- Fast UI interactions suitable for daily use
- Local data persistence
- Consistent UI/UX across platforms

---

## 5. Scope Management

This project is **intentionally maintained as a living system**. New features may be introduced as training needs evolve. The documentation reflects the state of the system at the time of assessment and may not list every future enhancement.

Out-of-scope items at the time of writing include:
- Cloud synchronization
- Social or competitive features
- Wearable device integration

---

## 6. Architecture & Technical Design

### 6.1 Overall Architecture

The Hybrid Athlete application follows a **feature-based Flutter project structure** that evolved organically during development. The architecture prioritizes simplicity, rapid iteration, and suitability for a single-user, offline-first application.

There is no strict enforcement of classical architectural patterns such as MVC or MVVM. Instead, the structure reflects pragmatic engineering decisions made during real-world development.

### 6.2 App Structure

Key characteristics of the project structure:
- Feature-based folders rather than strict layers
- Screens are largely self-contained
- Related screens are sometimes grouped into a single file (e.g., workout flow screens)
- A shared `data_models.dart` file acts as a lightweight service layer

The `data_models.dart` file contains:
- Data models
- Static manager-style methods
- Helper functions that coordinate updates across multiple storage keys

This approach reduces boilerplate and cognitive overhead for a solo developer.

---

### 6.3 State Management Strategy

State management is implemented using **vanilla Flutter** mechanisms:
- `StatefulWidget`
- `setState()`

Key patterns include:
- Each screen loads its own data in `initState()`
- Use of `mounted` checks to avoid updating disposed widgets
- Screen-to-screen synchronization using `Navigator.pop()` return values followed by reloads
- Atomic update helper functions (e.g., logging a workout updates history, calendar mappings, and statistics together)
- `WidgetsBindingObserver` to detect app lifecycle changes (used for calendar refresh when the app resumes)

#### Rationale

More advanced state management solutions (Provider, Riverpod, Bloc) were intentionally not adopted because:
- The application is single-user
- There is no globally shared mutable state
- Data reload times are consistently below 100 ms
- Simpler state management reduced development friction for a personal project

---

### 6.4 Data Storage Design

All application data is stored locally using **SharedPreferences**, serialized as JSON strings.

#### Reasons for Choosing SharedPreferences

| Aspect | SharedPreferences | Database |
|------|------------------|----------|
| Setup complexity | Minimal | Requires schema & migrations |
| Development speed | Very fast | Slower upfront planning |
| Expected data size | < 1000 workouts | Suitable for very large datasets |
| Query needs | Load & filter in Dart | Complex SQL queries |

This design supports fast iteration and matches the expected scale of a personal fitness application.

#### Known Limitations
- O(n) parsing on load (entire JSON decoded each time)
- No indexing for advanced queries
- Manual schema evolution required when formats change
- Platform-dependent storage size limits

A data format migration was already required once due to changes in the `logged_workouts` structure, highlighting the trade-offs of this approach.

#### Migration Criteria

A transition to a database solution would be justified if:
- Workout entries exceed ~1000 records
- Advanced analytics (time-series charts, comparisons) are introduced

---

### 6.5 Smart Exercise Detection Logic

Exercise logging behavior is determined using **rule-based detection**.

Detection order:
1. Recovery exercises → completion-only logging
2. Sprint exercises → repetitions and best-time input
3. Default → gym-style logging with weight and reps (multi-set)

This logic is implemented using hardcoded exercise name lists.

#### Design Rationale
- Small and predictable exercise set
- Deterministic behavior
- Easy extension by adding items to lists

An alternative design using explicit exercise type metadata was considered but rejected in favor of simpler and more flexible name-based matching, which also supports user-created exercises.

---

### 6.6 Cross-Platform Considerations

The application is deployed across mobile, desktop, and web platforms. Key challenges encountered include:

- **Storage locations** differ across platforms, particularly on Windows
- **Date and time normalization** was required due to platform-specific timezone behavior
- **UI density scaling** between mobile and desktop screen sizes
- **Hot reload behavior** varied significantly across platforms, sometimes requiring full restarts

Despite these challenges, a consistent UI and behavior were achieved through flexible layouts and careful state handling.

---

## 7. Reflection & Learning Outcomes

### 7.1 Initial Skill Level

At the start of the project, the developer had:
- No prior experience with Flutter
- No experience with Android Studio
- No familiarity with the Dart programming language

The project began with a clear goal but without predefined technical expertise.

---

### 7.2 Key Challenges

The most significant challenge during development was **state management**.

Common issues included:
- State updates after widget disposal
- Synchronizing data between screens
- Crashes caused by unexpected lifecycle behavior

Resolving these issues required repeated refactoring and a deeper understanding of Flutter’s widget lifecycle.

---

### 7.3 Design Trade-offs

Many decisions in the project are best described as **"good enough"** solutions rather than theoretically optimal ones.

Examples include:
- Choosing simplicity over scalability in data storage
- Avoiding complex architectural patterns
- Prioritizing development speed over long-term extensibility

These trade-offs were consciously accepted to keep the project usable and maintainable.

---

### 7.4 Iterative, Feeling-Driven Development

The application was developed iteratively, guided primarily by personal usage and intuition rather than formal upfront design.

As a result:
- Feature priorities shifted organically
- The app design reflects real daily training habits
- A hypothetical redesign would differ due to changed inspiration and experience

---

### 7.5 Personal Impact

Daily use of the application increased accountability in training. Logging workouts and marking sessions as complete reinforced consistency and personal responsibility toward practice.

---

## 8. Future Work

The project is expected to continue growing.

Potential future directions include:
- Refinement and performance optimization
- Controlled testing with sports friends
- Public release
- Optional private training networks for clubs

The current architecture supports incremental growth, with larger architectural changes deferred until clearly justified.

---

## 9. Document Versioning

- v0.1 – Initial documentation baseline
- v0.2 – Added architecture, technical design, and reflection sections

