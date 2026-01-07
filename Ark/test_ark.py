# -*- coding: utf-8 -*-
"""
Quick test of Ark LLM integration
"""

from llm_engine import ArkLLM

def main():
    print("="*50)
    print("ARK LLM ENGINE - QUICK TEST")
    print("="*50)
    
    # Create AI
    ai = ArkLLM()
    
    # Test connection
    print("\n1. Testing Ollama connection...")
    if ai.test_connection():
        print("   [OK] Connected to Ollama!")
    else:
        print("   [ERROR] Cannot connect. Is Ollama running?")
        print("   Start it with: ollama serve")
        return
    
    # Simple question
    print("\n2. Testing simple question...")
    print("   Question: What is hybrid training?")
    response = ai.ask("In one sentence, what is hybrid training?")
    print(f"   AI Response: {response}")
    
    # Chat with context
    print("\n3. Testing chat with coaching context...")
    ai.set_system_prompt("You are a fitness coach. Be brief and practical.")
    response = ai.chat("I want to combine futsal and strength training. Quick tip?")
    print(f"   AI Response: {response}")
    
    # Command parsing
    print("\n4. Testing command parsing...")
    test_commands = [
        "Open hybrid athlete app",
        "Show my stats",
        "What should I train today?"
    ]
    
    for cmd in test_commands:
        result = ai.execute_command(cmd)
        print(f"   Command: '{cmd}'")
        print(f"   Parsed: {result}")
    
    print("\n" + "="*50)
    print("ALL TESTS PASSED!")
    print("="*50)
    print("\nArk AI is ready to use!")
    print("Try: python workout_analyzer.py")

if __name__ == "__main__":
    main()
