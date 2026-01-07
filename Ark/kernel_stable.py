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
    execution_log = []
    clean_text = ai_text.replace("AI:", "").strip()
    
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
You are the KERNEL on WINDOWS. Execute commands only. No chat.

COMMANDS (one per line):
CMD: command
READ: filename
UPDATE: filename | old_text | new_text
WRITE: filename | content

RULES:
- WINDOWS ONLY: Use copy (not cp), del (not rm), dir (not ls), type (not cat), move (not mv)
- kernel.py: Use UPDATE only (WRITE blocked)
- UPDATE: old_text and new_text must be SHORT (under 100 chars)
- No explanations - just the command

EXAMPLE:
User: Copy test.py to backup.py
AI response:
CMD: copy test.py backup.py
"""

def main():
    print(f"{Fore.GREEN}======================================================{Style.RESET_ALL}")
    print(f"{Fore.GREEN}       SOVEREIGN AI KERNEL - PROTECTED MODE{Style.RESET_ALL}")
    print(f"{Fore.GREEN}       Editing | Auto-Fix | Hot-Reload{Style.RESET_ALL}")
    print(f"{Fore.GREEN}======================================================{Style.RESET_ALL}")
    
    while True:
        try:
            user_input = input(f"{Fore.BLUE}USER >> {Style.RESET_ALL}")
            if user_input.lower() in ["exit", "quit"]: break
            save_memory("user", user_input)
            
            past_context = recall_memory("context")
            messages = [
                {'role': 'system', 'content': SYSTEM_PROMPT},
                {'role': 'user', 'content': f"REQUEST: {user_input}"}
            ]

            for attempt in range(3):
                print(f"{Fore.YELLOW}Processing...{Style.RESET_ALL}")
                try:
                    response = ollama.chat(model=MODEL, messages=messages)
                    ai_text = response['message']['content']
                    print(f"{Fore.GREEN}AI >> {Style.RESET_ALL}{ai_text}")

                    tool_output = parse_and_execute(ai_text)

                    if tool_output:
                        print(f"{Style.DIM}TOOL OUTPUT:\n{tool_output}{Style.RESET_ALL}")
                        if "ERROR" in tool_output or "BLOCKED" in tool_output:
                            print(f"{Fore.RED}!!! ERROR - RETRYING !!!{Style.RESET_ALL}")
                            messages.append({'role': 'assistant', 'content': ai_text})
                            messages.append({'role': 'user', 'content': f"FAILED: {tool_output}\nUse SHORT text only: UPDATE: file | old | new"})
                            continue 
                        save_memory("ai", ai_text)
                        break 
                    else:
                        save_memory("ai", ai_text)
                        break
                except Exception as loop_error:
                    print(f"{Fore.RED}Error: {str(loop_error)}{Style.RESET_ALL}")
                    break

        except KeyboardInterrupt: 
            print(f"\n{Fore.YELLOW}Graceful shutdown...{Style.RESET_ALL}")
            break

if __name__ == "__main__":
    main()