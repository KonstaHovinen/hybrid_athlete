"""
Workout Analyzer - AI-powered workout insights

Reads sync data from Hybrid Athlete app
Analyzes workout patterns, progress, and provides recommendations
"""

import json
import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from llm_engine import ArkLLM


class WorkoutAnalyzer:
    """
    Analyzes workout data using AI
    Monitors sync file and provides insights
    """
    
    def __init__(self, sync_file_path: Optional[str] = None):
        """
        Initialize workout analyzer
        
        Args:
            sync_file_path: Path to sync JSON file (auto-detects if None)
        """
        self.llm = ArkLLM(model="llama3.2")
        
        # Auto-detect sync file location
        if sync_file_path:
            self.sync_file = sync_file_path
        else:
            # Try common locations
            possible_paths = [
                "../shared_data/hybrid_athlete_sync.json",
                "../../shared_data/hybrid_athlete_sync.json",
                os.path.expanduser("~/Documents/HybridAthlete/hybrid_athlete_sync.json"),
            ]
            
            self.sync_file = None
            for path in possible_paths:
                if os.path.exists(path):
                    self.sync_file = path
                    break
        
        self.insights_file = "../shared_data/ai_insights.json"
        
        # Set AI personality
        self.llm.set_system_prompt("""
You are an expert hybrid athlete coach with deep knowledge of:
- Futsal and soccer training
- Strength training and weightlifting
- Running and endurance sports
- Recovery and injury prevention
- Program design and periodization

Provide practical, actionable advice based on the athlete's data.
Be encouraging but honest about areas for improvement.
""")
    
    def load_workout_data(self) -> Optional[Dict]:
        """Load latest workout data from sync file"""
        if not self.sync_file or not os.path.exists(self.sync_file):
            print(f"❌ Sync file not found: {self.sync_file}")
            return None
        
        try:
            with open(self.sync_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print(f"❌ Error reading sync file: {e}")
            return None
    
    def analyze_latest_workout(self) -> str:
        """Analyze the most recent workout"""
        data = self.load_workout_data()
        if not data or 'data' not in data:
            return "❌ No workout data available. Make sure sync file exists."
        
        workout_history = data['data'].get('workout_history', [])
        if not workout_history:
            return "📭 No workouts logged yet. Start training to get AI insights!"
        
        # Get latest workout
        try:
            latest = json.loads(workout_history[-1])
        except:
            return "❌ Error parsing workout data"
        
        # Build detailed analysis prompt
        workout_type = latest.get('type', 'Unknown')
        date = latest.get('date', 'Unknown')
        template = latest.get('template_name', 'Custom')
        
        # Format exercises nicely
        exercises_str = ""
        sets_data = latest.get('sets', [])
        if sets_data:
            exercise_summary = {}
            for set_data in sets_data:
                ex_name = set_data.get('exerciseName', 'Unknown')
                if ex_name not in exercise_summary:
                    exercise_summary[ex_name] = {
                        'sets': 0,
                        'total_reps': 0,
                        'max_weight': 0,
                        'distances': [],
                        'times': []
                    }
                
                exercise_summary[ex_name]['sets'] += 1
                exercise_summary[ex_name]['total_reps'] += set_data.get('reps', 0)
                
                weight = set_data.get('weight', 0)
                if weight > exercise_summary[ex_name]['max_weight']:
                    exercise_summary[ex_name]['max_weight'] = weight
                
                if 'distance' in set_data:
                    exercise_summary[ex_name]['distances'].append(set_data['distance'])
                if 'time' in set_data:
                    exercise_summary[ex_name]['times'].append(set_data['time'])
            
            for ex, data in exercise_summary.items():
                exercises_str += f"\n  - {ex}: {data['sets']} sets"
                if data['total_reps'] > 0:
                    exercises_str += f", {data['total_reps']} total reps"
                if data['max_weight'] > 0:
                    exercises_str += f", max {data['max_weight']}kg"
                if data['distances']:
                    exercises_str += f", distances: {', '.join(map(str, data['distances']))}km"
                if data['times']:
                    exercises_str += f", times: {', '.join(data['times'])}"
        
        energy = latest.get('energy', 'Not recorded')
        mood = latest.get('mood', 'Not recorded')
        notes = latest.get('notes', 'None')
        
        prompt = f"""
Analyze this workout session and provide expert coaching insights:

**Workout Details:**
- Type: {workout_type}
- Date: {date}
- Template: {template}
- Energy Level: {energy}/5
- Mood: {mood}
- Notes: {notes}

**Exercises Performed:**{exercises_str}

**Provide:**
1. **Assessment**: Overall quality of this workout (2-3 sentences)
2. **What Went Well**: Specific positives to celebrate
3. **Areas for Improvement**: Constructive feedback
4. **Next Session Recommendation**: What to focus on next time

Keep it practical and encouraging!
"""
        
        print(f"🤖 Analyzing {workout_type} workout from {date}...")
        return self.llm.chat(prompt)
    
    def get_weekly_summary(self, days: int = 7) -> str:
        """Get summary of recent training"""
        data = self.load_workout_data()
        if not data:
            return "No data available"
        
        workout_history = data['data'].get('workout_history', [])
        
        # Filter recent workouts
        cutoff_date = datetime.now() - timedelta(days=days)
        recent_workouts = []
        
        for workout_str in workout_history:
            try:
                workout = json.loads(workout_str)
                workout_date = datetime.fromisoformat(workout.get('date', ''))
                if workout_date >= cutoff_date:
                    recent_workouts.append(workout)
            except:
                continue
        
        if not recent_workouts:
            return f"No workouts in the last {days} days"
        
        # Count workout types
        type_counts = {}
        for w in recent_workouts:
            wtype = w.get('type', 'Unknown')
            type_counts[wtype] = type_counts.get(wtype, 0) + 1
        
        summary_data = {
            'total_workouts': len(recent_workouts),
            'types': type_counts,
            'workouts': [
                {
                    'type': w.get('type'),
                    'date': w.get('date'),
                    'energy': w.get('energy')
                }
                for w in recent_workouts
            ]
        }
        
        prompt = f"""
Analyze this {days}-day training summary:

**Training Volume:**
- Total workouts: {summary_data['total_workouts']}
- Breakdown: {json.dumps(type_counts, indent=2)}

**Workout Details:**
{json.dumps(summary_data['workouts'], indent=2)}

**Provide:**
1. Training volume assessment (is it enough/too much?)
2. Balance analysis (strength vs cardio vs sports)
3. Recovery patterns (based on energy levels)
4. Recommendations for next week

Be specific and actionable!
"""
        
        return self.llm.chat(prompt)
    
    def get_training_recommendation(self) -> str:
        """Get AI recommendation for next workout"""
        data = self.load_workout_data()
        if not data:
            return "No data to analyze"
        
        # Get recent workouts (last 7)
        workout_history = data['data'].get('workout_history', [])
        recent = workout_history[-7:] if len(workout_history) > 7 else workout_history
        
        # Parse recent workouts
        recent_parsed = []
        for w_str in recent:
            try:
                recent_parsed.append(json.loads(w_str))
            except:
                continue
        
        prompt = f"""
Based on this recent training history, what should be the focus of the next workout?

**Recent Workouts:**
{json.dumps(recent_parsed, indent=2)}

**Consider:**
- Recovery needs (check energy levels)
- Training balance (variety of strength/cardio/sports)
- Progressive overload (building on previous sessions)
- Injury prevention (avoiding overtraining)

**Provide:**
1. Recommended workout type (gym/running/futsal/rest)
2. Specific focus areas or exercises
3. Intensity guideline
4. Any precautions or warmup advice

Be specific and practical!
"""
        
        return self.llm.chat(prompt)
    
    def analyze_progress(self, exercise_name: str, weeks: int = 4) -> str:
        """Analyze progress on a specific exercise"""
        data = self.load_workout_data()
        if not data:
            return "No data available"
        
        # Find all instances of this exercise
        workout_history = data['data'].get('workout_history', [])
        exercise_data = []
        
        cutoff_date = datetime.now() - timedelta(weeks=weeks)
        
        for w_str in workout_history:
            try:
                workout = json.loads(w_str)
                workout_date = datetime.fromisoformat(workout.get('date', ''))
                
                if workout_date < cutoff_date:
                    continue
                
                for set_data in workout.get('sets', []):
                    if exercise_name.lower() in set_data.get('exerciseName', '').lower():
                        exercise_data.append({
                            'date': workout.get('date'),
                            'weight': set_data.get('weight', 0),
                            'reps': set_data.get('reps', 0),
                            'distance': set_data.get('distance'),
                            'time': set_data.get('time')
                        })
            except:
                continue
        
        if not exercise_data:
            return f"No data found for exercise: {exercise_name}"
        
        prompt = f"""
Analyze progress on this exercise over {weeks} weeks:

**Exercise:** {exercise_name}

**Performance Data:**
{json.dumps(exercise_data, indent=2)}

**Provide:**
1. Progress trend (improving/maintaining/declining)
2. Key metrics (best sets, volume changes)
3. Recommendations for next session
4. Any technique or programming advice

Be encouraging and specific!
"""
        
        return self.llm.chat(prompt)
    
    def save_insights(self, insights: str, insight_type: str = "general"):
        """Save AI insights to file for desktop app to display"""
        try:
            insights_data = {
                'timestamp': datetime.now().isoformat(),
                'type': insight_type,
                'insights': insights
            }
            
            # Ensure directory exists
            os.makedirs(os.path.dirname(self.insights_file), exist_ok=True)
            
            with open(self.insights_file, 'w', encoding='utf-8') as f:
                json.dump(insights_data, f, indent=2)
            
            print(f"✅ Insights saved to {self.insights_file}")
        except Exception as e:
            print(f"❌ Error saving insights: {e}")


# CLI usage
if __name__ == "__main__":
    print("🤖 Ark Workout Analyzer\n")
    
    analyzer = WorkoutAnalyzer()
    
    # Check if sync file exists
    if not analyzer.sync_file:
        print("❌ No sync file found!")
        print("\nExpected locations:")
        print("  - ../shared_data/hybrid_athlete_sync.json")
        print("  - ~/Documents/HybridAthlete/hybrid_athlete_sync.json")
        print("\nExport your workout data from the app first!")
        exit(1)
    
    print(f"📂 Using sync file: {analyzer.sync_file}\n")
    
    # Menu
    while True:
        print("\n" + "="*50)
        print("Choose an analysis:")
        print("1. Analyze latest workout")
        print("2. Weekly summary")
        print("3. Training recommendation")
        print("4. Exercise progress")
        print("5. Exit")
        print("="*50)
        
        choice = input("\nChoice (1-5): ").strip()
        
        if choice == "1":
            print("\n🤖 Analyzing latest workout...\n")
            result = analyzer.analyze_latest_workout()
            print(result)
            analyzer.save_insights(result, "latest_workout")
            
        elif choice == "2":
            print("\n🤖 Generating weekly summary...\n")
            result = analyzer.get_weekly_summary()
            print(result)
            analyzer.save_insights(result, "weekly_summary")
            
        elif choice == "3":
            print("\n🤖 Getting training recommendation...\n")
            result = analyzer.get_training_recommendation()
            print(result)
            analyzer.save_insights(result, "recommendation")
            
        elif choice == "4":
            exercise = input("Exercise name: ").strip()
            weeks = int(input("Weeks to analyze (default 4): ").strip() or "4")
            print(f"\n🤖 Analyzing {exercise} progress...\n")
            result = analyzer.analyze_progress(exercise, weeks)
            print(result)
            analyzer.save_insights(result, f"progress_{exercise}")
            
        elif choice == "5":
            print("\n👋 Goodbye!")
            break
        else:
            print("❌ Invalid choice")
