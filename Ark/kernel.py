import ollama
import os
import subprocess
import datetime
import json
import re
import sys
import importlib
from colorama import Fore, Style, init

init(autoreset=True)

# --- CONFIGURATION ---
MODEL = "dolphin-llama3" 
MEMORY_FILE = "brain.json"
PROTECTED_FILES = ['kernel.py', './kernel.py', 'c:\\users\\konst\\desktop\\ark\\kernel.py']

# --- 1. MEMORY SYSTEM ---
def load_memory():
    if not os.path.exists(MEMORY_FILE): return []
    try:
        with open(MEMORY_FILE, 'r', encoding='utf-8') as f: return json.load(f)
    except: return []

def save_memory(role, text):
    history = load_memory()
    timestamp = datetime.datetime.now().isoformat()
    if len(history) > 20: history = history[-20:]
    history.append({"role": role, "text": text, "time": timestamp})
    with open(MEMORY_FILE, 'w', encoding='utf-8') as f: json.dump(history, f, indent=2)

def recall_memory(query):
    history = load_memory()
    return history[-5:] if history else []

# --- AUTO-LEARN: Detect and save personal facts ---
def auto_learn(user_input):
    """Automatically detect personal facts and save to memory"""
    patterns = [
        (r"my name is (\w+)", "name is {0}"),
        (r"i work (?:at|for) (.+?)(?:\.|$|,)", "works at {0}"),
        (r"i live in (.+?)(?:\.|$|,)", "lives in {0}"),
        (r"i like (.+?)(?:\.|$|,)", "likes {0}"),
        (r"i love (.+?)(?:\.|$|,)", "loves {0}"),
        (r"i hate (.+?)(?:\.|$|,)", "hates {0}"),
        (r"my favorite (\w+) is (.+?)(?:\.|$|,)", "favorite {0} is {1}"),
        (r"my (\w+) is named (\w+)", "{0} is named {1}"),
        (r"i have (?:a |an )?(\w+) named (\w+)", "has {0} named {1}"),
        (r"my birthday is (.+?)(?:\.|$|,)", "birthday is {0}"),
        (r"i am (\d+) years old", "is {0} years old"),
        (r"i'm (\d+) years old", "is {0} years old"),
    ]
    
    # Load existing facts to avoid duplicates
    existing = ""
    about_file = os.path.join("library", "about_user.txt")
    if os.path.exists(about_file):
        with open(about_file, 'r', encoding='utf-8') as f:
            existing = f.read().lower()
    
    text = user_input.lower().strip()
    learned = []
    
    for pattern, template in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            groups = match.groups()
            fact = template.format(*groups)
            # Skip if already known
            if fact.lower() in existing:
                continue
            # Save to librarian
            try:
                subprocess.run(
                    f'python librarian.py add "about_user" "{fact}"',
                    shell=True, capture_output=True, cwd=os.getcwd()
                )
                learned.append(fact)
            except:
                pass
    
    if learned:
        print(f"{Fore.CYAN}[AUTO-LEARNED: {', '.join(learned)}]{Style.RESET_ALL}")
    
    return learned

# --- 2. FILE PROTECTION SYSTEM ---
def is_protected_file(filename):
    """Check if a file is protected from destructive operations"""
    normalized = filename.lower().replace('/', '\\').strip()
    for protected in PROTECTED_FILES:
        if protected.lower() in normalized or normalized.endswith('kernel.py'):
            return True
    return False

# --- 3. THE HANDS (Tools) ---
def write_file(filename, content):
    """NUKE OPTION: Overwrites the entire file."""
    # CRITICAL PROTECTION: Block ALL writes to kernel.py
    if is_protected_file(filename):
        return "SYSTEM ERROR: WRITE command BLOCKED for kernel.py! Use UPDATE instead. This protects against data loss."
    
    try:
        if "\\n" in content: content = content.replace("\\n", "\n")
        with open(filename, 'w', encoding='utf-8') as f: f.write(content)
        return f"SUCCESS: Overwrote {filename}"
    except Exception as e: 
        return f"ERROR: {str(e)}"

def update_file(filename, old_text, new_text):
    """SCALPEL OPTION: Replaces specific text safely."""
    try:
        if not os.path.exists(filename): return f"ERROR: File {filename} not found."
        with open(filename, 'r', encoding='utf-8') as f: content = f.read()
        
        # Handle escaped newlines in old_text and new_text
        if "\\n" in old_text: old_text = old_text.replace("\\n", "\n")
        if "\\n" in new_text: new_text = new_text.replace("\\n", "\n")
        
        if old_text not in content:
            return f"ERROR: old_text not found in file. Text to find: '{old_text[:50]}...'"
            
        new_content = content.replace(old_text, new_text)
        with open(filename, 'w', encoding='utf-8') as f: f.write(new_content)
        return f"SUCCESS: Updated {filename}"
    except Exception as e: 
        return f"ERROR: {str(e)}"

def read_file(filename):
    try:
        if not os.path.exists(filename): return f"ERROR: File {filename} not found."
        with open(filename, 'r', encoding='utf-8') as f: return f.read()
    except Exception as e: 
        return f"ERROR: {str(e)}"

def run_command(command):
    if "python -c" in command: return "SYSTEM ERROR: 'python -c' is BANNED."
    try:
        print(f"{Fore.RED}>>> EXECUTING TERMINAL: {command}{Style.RESET_ALL}")
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        return result.stdout + result.stderr
    except Exception as e: 
        return f"EXECUTION ERROR: {str(e)}"

def reload_kernel():
    """Hot-reload the kernel without restarting the program"""
    try:
        print(f"{Fore.YELLOW}>>> RELOADING KERNEL...{Style.RESET_ALL}")
        current_module = sys.modules[__name__]
        importlib.reload(current_module)
        return "SUCCESS: Kernel reloaded successfully"
    except Exception as e:
        return f"ERROR: Failed to reload kernel - {str(e)}"

def clear_system():
    """Clear memory and reset system state"""
    try:
        if os.path.exists(MEMORY_FILE):
            os.remove(MEMORY_FILE)
        print(f"{Fore.YELLOW}>>> SYSTEM CLEARED{Style.RESET_ALL}")
        return "SUCCESS: Memory cleared and system reset"
    except Exception as e:
        return f"ERROR: Failed to clear system - {str(e)}"

def diagnose_command():
    """Run comprehensive system diagnostics"""
    try:
        print(f"{Fore.CYAN}>>> RUNNING DIAGNOSTICS{Style.RESET_ALL}")
        report = []
        
        report.append("=== SYSTEM DIAGNOSTICS ===")
        report.append(f"Python: {sys.version.split()[0]}")
        report.append(f"Platform: {os.name}")
        report.append(f"Working Directory: {os.getcwd()}")
        
        if os.path.exists(MEMORY_FILE):
            history = load_memory()
            report.append(f"Memory: {len(history)} entries")
        else:
            report.append("Memory: Empty")
        
        report.append("\n=== CODE ANALYSIS ===")
        if os.path.exists("kernel.py"):
            with open("kernel.py", 'r') as f:
                lines = len(f.readlines())
            report.append(f"kernel.py: {lines} lines")
        
        try:
            import ollama
            report.append("OK: Ollama module available")
        except ImportError:
            report.append("MISSING: Ollama module")
        
        return "\n".join(report)
    
    except Exception as e:
        return f"Diagnostic failed: {str(e)}"

# --- 4. THE BRAIN ---
def parse_and_execute(ai_text):
    """Parse and execute commands from AI text. Only executes commands from AI, not from tool output."""
    execution_log = []
    clean_text = ai_text.replace("AI:", "").strip()
    
    # SAFETY: Only parse commands from the original AI text, not from tool output
    # This prevents command injection from tool output
    
    # Tool Regex Patterns - STRICT PARSING (must be on own line)
    cmd_matches = re.findall(r'^CMD:\s*(.+)$', clean_text, re.MULTILINE | re.IGNORECASE)
    write_matches = re.findall(r'^WRITE:\s*(\S+)\s*\|\s*(.+)$', clean_text, re.MULTILINE | re.IGNORECASE)
    update_matches = re.findall(r'^UPDATE:\s*(\S+)\s*\|\s*([^|]+)\s*\|\s*(.+)$', clean_text, re.MULTILINE | re.IGNORECASE)
    read_matches = re.findall(r'^READ:\s*(\S+)\s*$', clean_text, re.MULTILINE | re.IGNORECASE)
    
    # System control commands - must be on their own line
    reload_matches = re.findall(r'^(RELOAD|REFRESH)\s*$', clean_text, re.MULTILINE | re.IGNORECASE)
    clear_matches = re.findall(r'^(CLEAR|RESET)\s*$', clean_text, re.MULTILINE | re.IGNORECASE)
    diagnose_matches = re.findall(r'^(DIAGNOSE|DIAGNOSTIC|CHECK)\s*$', clean_text, re.MULTILINE | re.IGNORECASE)

    # Execute System Commands First
    for _ in reload_matches:
        print(f"{Fore.CYAN}>>> RELOADING KERNEL{Style.RESET_ALL}")
        result = reload_kernel()
        execution_log.append(result)
        
    for _ in clear_matches:
        print(f"{Fore.CYAN}>>> CLEARING SYSTEM{Style.RESET_ALL}")
        result = clear_system()
        execution_log.append(result)
        
    for _ in diagnose_matches:
        print(f"{Fore.CYAN}>>> RUNNING DIAGNOSTICS{Style.RESET_ALL}")
        result = diagnose_command()
        execution_log.append(result)

    # Execute Updates FIRST (The Scalpel)
    for fname, old, new in update_matches:
        fname = fname.strip()
        old = old.strip()
        new = new.strip()
        # SAFETY: Reject if new_text is too long (likely AI explanation got captured)
        if len(new) > 100:
            execution_log.append(f"ERROR: new_text rejected - too long ({len(new)} chars). Must be under 100 chars.")
            continue
        print(f"{Fore.MAGENTA}>>> UPDATING FILE: {fname}{Style.RESET_ALL}")
        print(f"{Fore.MAGENTA}    Replacing: '{old}' -> '{new}'{Style.RESET_ALL}")
        result = update_file(fname, old, new)
        execution_log.append(result)

    # Execute Writes (The Nuke)
    for fname, content in write_matches:
        fname = fname.strip()
        print(f"{Fore.MAGENTA}>>> OVERWRITING FILE: {fname}{Style.RESET_ALL}")
        result = write_file(fname, content.strip())
        execution_log.append(result)

    # Execute Reads
    for fname in read_matches:
        fname = fname.strip()
        print(f"{Fore.MAGENTA}>>> READING FILE: {fname}{Style.RESET_ALL}")
        result = read_file(fname)
        execution_log.append(f"FILE CONTENT ({fname}):\n{result[:1000]}...") 

    # Execute Commands
    for cmd in cmd_matches:
        cmd = cmd.strip()
        if not cmd: continue
        print(f"{Fore.RED}>>> EXECUTING: {cmd}{Style.RESET_ALL}")
        result = run_command(cmd)
        execution_log.append(f"TERMINAL OUTPUT: {result}")

    if not execution_log: return None
    return "\n".join(execution_log)

SYSTEM_PROMPT = """
You are JARVIS, a sovereign AI operating system kernel with advanced tools and protocols.

CRITICAL: When user asks about external information (current events, facts, dates, etc.), you MUST use:
CMD: python researcher.py search "query"
Do NOT search the library for external information - use the internet researcher instead.

USER INFO (refer to them as "you", not by name):
The info below is about the person you're talking to. Use it naturally. This is NOT for answering their questions about the world.

RULES:
- Address user as "you" (never by name or in third person)
- The user owns their data - give them anything they saved
- If they ask for saved info, suggest: "Try /search <keyword>"
- If they share something to remember, suggest: "Want me to /save that?"
- Be helpful, not secretive - this is THEIR assistant

MODES:
- /chat: Default, friendly conversation and reasoning
- /search <query>: Search your own memory and notes
- /save <info>: Save a fact or note to memory

TOOLS (MUST USE EXACT FORMAT - one command per line):
- CMD: <command> - Execute a terminal command
- READ: <filename> - Read a file
- UPDATE: <filename> | <old_text> | <new_text> - Replace text in a file
- WRITE: <filename> | <content> - Overwrite a file

WHEN TO USE WHICH TOOL:
1. INTERNET SEARCH (researcher.py) - Use for ANY question about:
   - Current events, news, recent information
   - Facts about the world, people, places, things
   - Information NOT in the user's saved memory
   - Dates, statistics, releases, sports scores, etc.
   - Example: "What is the release date of GTA 6?" → CMD: python researcher.py search "GTA 6 release date"

2. LOCAL LIBRARY (librarian.py) - Use ONLY when:
   - User explicitly asks to search their saved notes/memory
   - User says "search my notes" or "what did I save about X"
   - Example: "Search my notes for password" → CMD: python librarian.py search "password"

CRITICAL RULES:
- If user asks about something external/current/recent → ALWAYS use researcher.py (internet)
- The library context shown below is just for reference about the USER, not for answering their questions
- When you need to use a tool, output the command on its own line. Then wait for the tool output before responding.
- Do NOT just say "I'll search for that" - actually output: CMD: python researcher.py search "query"

SAFETY:
- Never overwrite kernel.py directly (WRITE is blocked)
- Use UPDATE for safe, surgical edits
- Never run 'python -c' commands

PERSONALITY:
- Be friendly, direct, and use "you" language
- Never refer to yourself in the third person
- Always explain which tool you are using if you invoke one

You are the user's sovereign AI assistant. Be helpful, transparent, and always use the right tool for the job.
"""

def main():
    print(f"{Fore.GREEN}======================================================{Style.RESET_ALL}")
    print(f"{Fore.GREEN}             JARVIS ONLINE - READY{Style.RESET_ALL}")
    print(f"{Fore.GREEN}======================================================{Style.RESET_ALL}")
    print(f"{Fore.CYAN}MODES: /search <query> | /save <info> | /chat (default){Style.RESET_ALL}")
    print(f"{Fore.CYAN}Type 'exit' to quit{Style.RESET_ALL}")
    print()
    
    mode = "chat"  # Default mode
    
    while True:
        try:
            user_input = input(f"{Fore.BLUE}YOU >> {Style.RESET_ALL}")
            if user_input.lower() in ["exit", "quit"]: break
            
            # MODE COMMANDS
            if user_input.lower().startswith("/search "):
                query = user_input[8:].strip()
                print(f"{Fore.MAGENTA}>>> SEARCHING: {query}{Style.RESET_ALL}")
                result = run_command(f'python librarian.py search "{query}"')
                print(f"{Fore.GREEN}JARVIS >> {Style.RESET_ALL}{result}")
                continue
                
            if user_input.lower().startswith("/save "):
                info = user_input[6:].strip()
                print(f"{Fore.MAGENTA}>>> SAVING: {info}{Style.RESET_ALL}")
                result = run_command(f'python librarian.py add "notes" "{info}"')
                print(f"{Fore.GREEN}JARVIS >> {Style.RESET_ALL}Got it! I'll remember that.")
                continue
            
            if user_input.lower() == "/search":
                print(f"{Fore.YELLOW}Usage: /search <query>{Style.RESET_ALL}")
                continue
                
            if user_input.lower() == "/save":
                print(f"{Fore.YELLOW}Usage: /save <info to remember>{Style.RESET_ALL}")
                continue
            
            # CHAT MODE - Auto-learn still works
            auto_learn(user_input)
            save_memory("user", user_input)
            
            # Load ALL library files for smart chat
            memory_context = ""
            library_dir = "library"
            if os.path.exists(library_dir):
                for filename in os.listdir(library_dir):
                    if filename.endswith('.txt'):
                        filepath = os.path.join(library_dir, filename)
                        with open(filepath, 'r', encoding='utf-8') as f:
                            content = f.read().strip()
                            if content:
                                memory_context += f"\n[{filename}]\n{content}\n"
            
            messages = [
                {'role': 'system', 'content': SYSTEM_PROMPT + f"\n\nSAVED INFO:\n{memory_context}"},
                {'role': 'user', 'content': user_input}
            ]

            print(f"{Fore.YELLOW}Thinking...{Style.RESET_ALL}")
            try:
                max_tool_iterations = 3  # Prevent infinite loops
                tool_iteration = 0
                final_ai_text = None
                
                while tool_iteration < max_tool_iterations:
                    response = ollama.chat(model=MODEL, messages=messages)
                    ai_text = response['message']['content']
                    
                    if tool_iteration == 0:
                        print(f"{Fore.GREEN}JARVIS >> {Style.RESET_ALL}{ai_text}")
                    else:
                        print(f"{Fore.CYAN}JARVIS >> {Style.RESET_ALL}{ai_text}")
                    
                    # Execute any tools the AI mentioned
                    tool_output = parse_and_execute(ai_text)
                    
                    # Check if AI actually used a tool (not just talked about it)
                    has_actual_command = bool(re.search(r'^(CMD|READ|WRITE|UPDATE):', ai_text, re.MULTILINE | re.IGNORECASE))
                    
                    if tool_output and has_actual_command:
                        print(f"{Style.DIM}TOOL OUTPUT:\n{tool_output}{Style.RESET_ALL}")
                        
                        # Feed tool output back to AI for a proper response
                        messages.append({'role': 'assistant', 'content': ai_text})
                        messages.append({'role': 'user', 'content': f"Tool execution completed:\n{tool_output}\n\nNow provide a helpful response to the user based on this information. Do NOT execute more tools unless absolutely necessary."})
                        
                        tool_iteration += 1
                        if tool_iteration < max_tool_iterations:
                            print(f"{Fore.YELLOW}Processing tool results...{Style.RESET_ALL}")
                            continue  # Loop back to get AI's response to tool output
                        else:
                            final_ai_text = ai_text
                            break
                    else:
                        # No tools executed, or just conversation
                        final_ai_text = ai_text
                        break
                
                save_memory("ai", final_ai_text)
            except Exception as e:
                print(f"{Fore.RED}Error: {str(e)}{Style.RESET_ALL}")

        except KeyboardInterrupt: 
            print(f"\n{Fore.YELLOW}Graceful shutdown...{Style.RESET_ALL}")
            break

if __name__ == "__main__":
    main()