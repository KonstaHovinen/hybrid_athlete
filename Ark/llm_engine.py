"""
Ark LLM Engine - Standalone AI without web client

Connects to Ollama server running locally
No browser client needed - pure Python API access
"""

import requests
import json
from typing import Optional, Dict, List, Callable
from datetime import datetime


class ArkLLM:
    """
    Standalone LLM wrapper for Ark AI
    Uses local Ollama server - NO web client needed!
    """
    
    def __init__(self, model: str = "llama3.2", base_url: str = "http://localhost:11434"):
        """
        Initialize Ark LLM
        
        Args:
            model: Ollama model to use (llama3.2, llama3, etc.)
            base_url: Ollama server URL (default: localhost:11434)
        """
        self.model = model
        self.base_url = base_url
        self.api_url = f"{base_url}/api/generate"
        self.chat_url = f"{base_url}/api/chat"
        self.conversation_history: List[Dict] = []
        self.system_context = None
        
    def ask(self, prompt: str, stream: bool = False, context: Optional[str] = None) -> str:
        """
        Ask the AI a question (simple, stateless)
        
        Args:
            prompt: Your question or prompt
            stream: Stream response in real-time
            context: Optional additional context
        
        Returns:
            AI's response as string
        """
        full_prompt = prompt
        if context:
            full_prompt = f"{context}\n\n{prompt}"
            
        payload = {
            "model": self.model,
            "prompt": full_prompt,
            "stream": stream
        }
        
        try:
            response = requests.post(self.api_url, json=payload, timeout=60)
            response.raise_for_status()
            
            if stream:
                return self._handle_stream(response)
            else:
                result = response.json()
                answer = result.get('response', '')
                return answer.strip()
                
        except requests.exceptions.RequestException as e:
            return f"❌ Error connecting to Ollama: {e}\nMake sure Ollama is running (ollama serve)"
        except Exception as e:
            return f"❌ Error: {e}"
    
    def chat(self, message: str, system_prompt: Optional[str] = None) -> str:
        """
        Have a conversation with context (stateful)
        
        Args:
            message: Your message
            system_prompt: Optional system instruction (sets AI behavior)
        
        Returns:
            AI's response
        """
        # Set system context if provided
        if system_prompt and not self.system_context:
            self.system_context = system_prompt
        
        # Build messages array for chat API
        messages = []
        
        # Add system message if exists
        if self.system_context:
            messages.append({
                "role": "system",
                "content": self.system_context
            })
        
        # Add conversation history
        messages.extend(self.conversation_history)
        
        # Add current message
        messages.append({
            "role": "user",
            "content": message
        })
        
        payload = {
            "model": self.model,
            "messages": messages,
            "stream": False
        }
        
        try:
            response = requests.post(self.chat_url, json=payload, timeout=60)
            response.raise_for_status()
            
            result = response.json()
            assistant_message = result.get('message', {}).get('content', '')
            
            # Save to history
            self.conversation_history.append({
                "role": "user",
                "content": message
            })
            self.conversation_history.append({
                "role": "assistant",
                "content": assistant_message
            })
            
            return assistant_message.strip()
            
        except Exception as e:
            return f"❌ Chat error: {e}"
    
    def execute_command(self, command: str) -> Dict:
        """
        Parse user command and execute action
        
        Examples:
            "Open hybrid athlete app"
            "Show my workout history"
            "Analyze my last futsal game"
            "What should I train today?"
        
        Returns:
            Dict with action and parameters
        """
        # Use AI to parse the command
        parse_prompt = f"""
You are an AI assistant that controls apps and features.
Parse this user command and return JSON:

Command: "{command}"

Return format:
{{
    "action": "open_app" | "open_feature" | "analyze" | "question",
    "app": "hybrid_athlete" | "other",
    "feature": "workouts" | "history" | "stats" | "profile" | "calendar" | null,
    "query": "user's actual question or analysis request"
}}

Examples:
- "Open hybrid athlete" → {{"action": "open_app", "app": "hybrid_athlete", "feature": null}}
- "Show my stats" → {{"action": "open_feature", "app": "hybrid_athlete", "feature": "stats"}}
- "Analyze my workout" → {{"action": "analyze", "query": "analyze recent workout"}}

Return ONLY valid JSON, nothing else.
"""
        
        response = self.ask(parse_prompt)
        
        try:
            # Extract JSON from response
            # AI sometimes adds markdown formatting
            if "```json" in response:
                response = response.split("```json")[1].split("```")[0].strip()
            elif "```" in response:
                response = response.split("```")[1].split("```")[0].strip()
            
            command_data = json.loads(response)
            return command_data
        except:
            # Fallback: simple keyword matching
            command_lower = command.lower()
            
            if "open" in command_lower and "hybrid" in command_lower:
                return {"action": "open_app", "app": "hybrid_athlete", "feature": None}
            elif "stats" in command_lower or "statistics" in command_lower:
                return {"action": "open_feature", "app": "hybrid_athlete", "feature": "stats"}
            elif "history" in command_lower or "workouts" in command_lower:
                return {"action": "open_feature", "app": "hybrid_athlete", "feature": "history"}
            elif "analyze" in command_lower or "check" in command_lower:
                return {"action": "analyze", "query": command}
            else:
                return {"action": "question", "query": command}
    
    def set_system_prompt(self, prompt: str):
        """Set or update system prompt (AI personality/instructions)"""
        self.system_context = prompt
    
    def reset_conversation(self):
        """Clear conversation history"""
        self.conversation_history = []
        self.system_context = None
    
    def get_conversation_summary(self) -> str:
        """Get summary of current conversation"""
        if not self.conversation_history:
            return "No conversation yet"
        
        summary_prompt = f"""
Summarize this conversation in 2-3 sentences:

{json.dumps(self.conversation_history, indent=2)}

Summary:
"""
        return self.ask(summary_prompt)
    
    def _handle_stream(self, response) -> str:
        """Handle streaming responses"""
        full_response = ""
        try:
            for line in response.iter_lines():
                if line:
                    data = json.loads(line)
                    chunk = data.get('response', '')
                    full_response += chunk
                    print(chunk, end='', flush=True)
            print()  # New line at end
        except Exception as e:
            print(f"\n❌ Stream error: {e}")
        return full_response
    
    def test_connection(self) -> bool:
        """Test if Ollama is running and accessible"""
        try:
            response = requests.get(f"{self.base_url}/api/tags", timeout=5)
            return response.status_code == 200
        except:
            return False


# Example usage and testing
if __name__ == "__main__":
    print("Ark LLM Engine - Testing Connection\n")
    
    # Create AI instance
    ai = ArkLLM()
    
    # Test connection
    print("Testing Ollama connection...")
    if ai.test_connection():
        print("✅ Connected to Ollama!\n")
    else:
        print("❌ Cannot connect to Ollama. Is it running?")
        print("Start it with: ollama serve\n")
        exit(1)
    
    # Simple question
    print("📝 Testing simple question...")
    response = ai.ask("What are the benefits of combining strength training and cardio?")
    print(f"AI: {response}\n")
    
    # Chat with context
    print("💬 Testing chat with context...")
    ai.set_system_prompt("You are a professional hybrid athlete coach with expertise in futsal, weightlifting, and endurance training.")
    
    response1 = ai.chat("I just finished a futsal game. What should I focus on tomorrow?")
    print(f"AI: {response1}\n")
    
    response2 = ai.chat("What if I feel sore?")
    print(f"AI: {response2}\n")
    
    # Command parsing
    print("🎯 Testing command execution...")
    commands = [
        "Open hybrid athlete app",
        "Show my workout stats",
        "Analyze my last workout",
        "What should I train today?"
    ]
    
    for cmd in commands:
        result = ai.execute_command(cmd)
        print(f"Command: '{cmd}'")
        print(f"Parsed: {json.dumps(result, indent=2)}\n")
    
    print("✅ All tests complete!")
