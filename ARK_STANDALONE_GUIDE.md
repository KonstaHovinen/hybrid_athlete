# 🤖 Ark AI - Standalone LLM Integration Guide

## Overview

Make Ark a **standalone AI** that runs on your PC without needing the Ollama web client.

---

## ✅ What You Have

- ✅ **Ollama installed** (version 0.13.5)
- ✅ **Ollama server running** (http://127.0.0.1:11434)
- ✅ **RTX 4070 GPU** (8GB VRAM, CUDA support)
- ✅ **10 models downloaded** (in `C:\Users\konst\.ollama\models`)

---

## 🚀 Step 1: Create LLM Engine (5 minutes)

Create this file in your Ark folder:

**File**: `ark/llm_engine.py`

```python
import requests
import json

class ArkLLM:
    """
    Standalone LLM wrapper for Ark AI
    Uses local Ollama server - NO web client needed!
    """
    
    def __init__(self, model="llama3.2"):
        self.api_url = "http://localhost:11434/api/generate"
        self.model = model
        self.conversation_history = []
    
    def ask(self, prompt, stream=False):
        """
        Ask the AI a question
        
        Args:
            prompt (str): Your question or prompt
            stream (bool): Stream response in real-time
        
        Returns:
            str: AI's response
        """
        payload = {
            "model": self.model,
            "prompt": prompt,
            "stream": stream
        }
        
        try:
            response = requests.post(self.api_url, json=payload)
            response.raise_for_status()
            
            if stream:
                return self._handle_stream(response)
            else:
                result = response.json()
                answer = result.get('response', '')
                self.conversation_history.append({
                    'prompt': prompt,
                    'response': answer
                })
                return answer
                
        except Exception as e:
            return f"Error: {e}"
    
    def chat(self, message, system_prompt=None):
        """
        Have a conversation with context
        
        Args:
            message (str): Your message
            system_prompt (str): Optional system instruction
        
        Returns:
            str: AI's response
        """
        # Build context from history
        context = ""
        if system_prompt:
            context += f"System: {system_prompt}\n\n"
        
        for turn in self.conversation_history[-5:]:  # Last 5 turns
            context += f"Human: {turn['prompt']}\n"
            context += f"AI: {turn['response']}\n\n"
        
        full_prompt = context + f"Human: {message}\nAI:"
        return self.ask(full_prompt)
    
    def reset_conversation(self):
        """Clear conversation history"""
        self.conversation_history = []
    
    def _handle_stream(self, response):
        """Handle streaming responses"""
        full_response = ""
        for line in response.iter_lines():
            if line:
                data = json.loads(line)
                chunk = data.get('response', '')
                full_response += chunk
                print(chunk, end='', flush=True)
        print()  # New line at end
        return full_response


# Example usage
if __name__ == "__main__":
    # Create AI instance
    ai = ArkLLM()
    
    # Simple question
    response = ai.ask("What is the best way to structure a workout program?")
    print(response)
    
    # Chat with context
    ai.chat("I just did 3 sets of squats with 100kg", 
            system_prompt="You are a professional strength coach")
    ai.chat("What should I do next?")
```

---

## 🎯 Step 2: Integrate with Workout Data

**File**: `ark/workout_analyzer.py`

```python
import json
import os
from llm_engine import ArkLLM

class WorkoutAnalyzer:
    """
    Analyzes workout data using AI
    Monitors sync file and provides insights
    """
    
    def __init__(self):
        self.llm = ArkLLM(model="llama3.2")
        self.sync_file = "../shared_data/hybrid_athlete_sync.json"
        self.insights_file = "../shared_data/ai_insights.json"
    
    def load_workout_data(self):
        """Load latest workout data from sync file"""
        if not os.path.exists(self.sync_file):
            return None
        
        with open(self.sync_file, 'r') as f:
            return json.load(f)
    
    def analyze_latest_workout(self):
        """Analyze the most recent workout"""
        data = self.load_workout_data()
        if not data or 'data' not in data:
            return "No workout data available"
        
        workout_history = data['data'].get('workout_history', [])
        if not workout_history:
            return "No workouts logged yet"
        
        # Get latest workout
        latest = json.loads(workout_history[-1])
        
        prompt = f"""
        Analyze this workout session:
        
        Type: {latest.get('type', 'Unknown')}
        Date: {latest.get('date', 'Unknown')}
        Template: {latest.get('template_name', 'Custom')}
        
        Exercises:
        {json.dumps(latest.get('sets', []), indent=2)}
        
        Energy Level: {latest.get('energy', 'Not recorded')}/5
        Mood: {latest.get('mood', 'Not recorded')}
        Notes: {latest.get('notes', 'None')}
        
        Provide:
        1. Assessment of workout quality
        2. What went well
        3. Areas for improvement
        4. Recommendation for next session
        """
        
        return self.llm.ask(prompt)
    
    def get_training_recommendation(self):
        """Get AI recommendation for next workout"""
        data = self.load_workout_data()
        if not data:
            return "No data to analyze"
        
        # Extract recent workouts (last 7 days)
        workout_history = data['data'].get('workout_history', [])
        recent = workout_history[-7:] if len(workout_history) > 7 else workout_history
        
        prompt = f"""
        Based on this training history:
        {json.dumps([json.loads(w) for w in recent], indent=2)}
        
        What should be the focus of my next training session?
        Consider:
        - Recovery needs
        - Training balance (strength/cardio/sports)
        - Progressive overload
        - Energy levels reported
        """
        
        return self.llm.ask(prompt)
    
    def save_insights(self, insights):
        """Save AI insights to file for desktop app"""
        with open(self.insights_file, 'w') as f:
            json.dump({
                'timestamp': datetime.now().isoformat(),
                'insights': insights
            }, f, indent=2)


# CLI usage
if __name__ == "__main__":
    analyzer = WorkoutAnalyzer()
    
    print("🤖 Analyzing latest workout...")
    print(analyzer.analyze_latest_workout())
    
    print("\n🎯 Training recommendation...")
    print(analyzer.get_training_recommendation())
```

---

## 🔄 Step 3: Auto-Monitor Sync File

**File**: `ark/sync_monitor.py`

```python
import time
import os
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from workout_analyzer import WorkoutAnalyzer

class SyncFileHandler(FileSystemEventHandler):
    """Watches sync file for changes"""
    
    def __init__(self):
        self.analyzer = WorkoutAnalyzer()
        self.last_modified = 0
    
    def on_modified(self, event):
        if event.src_path.endswith('hybrid_athlete_sync.json'):
            # Debounce (avoid multiple triggers)
            current_time = time.time()
            if current_time - self.last_modified < 2:
                return
            
            self.last_modified = current_time
            print("\n📊 New workout data detected!")
            print("🤖 Analyzing with AI...")
            
            # Analyze and save insights
            insights = self.analyzer.analyze_latest_workout()
            print(insights)
            self.analyzer.save_insights(insights)
            print("\n✅ Insights saved for desktop app\n")


def start_monitoring():
    """Start watching sync folder"""
    path = "../shared_data"
    
    if not os.path.exists(path):
        print(f"Creating {path}...")
        os.makedirs(path)
    
    event_handler = SyncFileHandler()
    observer = Observer()
    observer.schedule(event_handler, path, recursive=False)
    observer.start()
    
    print("👀 Ark is watching for new workouts...")
    print("Press Ctrl+C to stop\n")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    
    observer.join()


if __name__ == "__main__":
    start_monitoring()
```

---

## 🎯 How to Use

### Option 1: Manual Analysis
```bash
cd c:\Users\konst\Desktop\hybrid_athlete\Ark
python workout_analyzer.py
```

### Option 2: Auto-Monitor (Runs in background)
```bash
cd c:\Users\konst\Desktop\hybrid_athlete\Ark
python sync_monitor.py
```

This runs 24/7 and automatically analyzes workouts when synced!

---

## 📦 Required Packages

Install these (one-time):

```bash
pip install requests watchdog
```

---

## 🚀 Scaling AI as You Go

### Start Small
```python
# Just basic analysis
ai = ArkLLM()
result = ai.ask("Analyze this workout...")
```

### Add Features Over Time
```python
# Week 1: Basic insights
# Week 2: Pattern recognition
# Week 3: Injury prediction
# Week 4: Program generation
# Week 5: Self-learning
```

### Growing Model Size

**Current**: llama3.2 (~2GB) - Fast, good enough
**Later**: 
- llama3:8b (~4GB) - Better reasoning
- llama3:70b (~40GB) - Professional coach level
- Custom fine-tuned model - Your personal AI

**You control the growth!**

---

## ✅ Answers to Your Questions

### "I don't need the white client from website to run in background"
✅ **CORRECT!** Once `ollama serve` is running:
- Ark uses HTTP API (localhost:11434)
- No browser client needed
- Runs completely standalone
- Can even run as Windows service (auto-start)

### "Ark should be on my PC and workout app on phone communicates through sync feature"
✅ **PERFECT!** Architecture:
```
iPhone (PWA) 
    → Logs workout
    → Syncs to shared_data/
    
Ark (PC)
    → Monitors shared_data/
    → Analyzes with LLM
    → Writes insights
    
Desktop App (PC)
    → Reads insights
    → Shows AI recommendations
```

### "Is it possible to develop the size as I go?"
✅ **YES!** Start with:
- Small model (llama3.2)
- Basic prompts
- Simple analysis

Then grow to:
- Bigger models
- Complex reasoning
- Multi-model ensemble
- Custom training

---

## 🎉 You're Ready!

**What you have NOW:**
- ✅ Standalone LLM (no web client)
- ✅ RTX 4070 GPU acceleration
- ✅ Sync system working
- ✅ Architecture documented

**Next session:**
1. Create the 3 Python files above
2. Test basic AI analysis
3. Set up auto-monitoring
4. Watch Ark learn from your workouts! 🚀
