import os
import re

def fix_final_three():
    filepath = os.path.join('lib', 'screens', 'workout_screens.dart')
    
    if not os.path.exists(filepath):
        print("❌ File not found.")
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # --- FIX 1: The List Type Error (Line ~1102) ---
    # Problem: The code is split across lines like:
    # .map(
    #   (e) => ...
    #
    # Regex explanation:
    # \.map\s*\(      -> Matches ".map(" with optional whitespace/newlines
    # \s*\(e\)        -> Matches "(e)" with optional whitespace/newlines
    content = re.sub(
        r'\.map\s*\(\s*\(e\)', 
        '.map<DropdownMenuItem<String>>((e)', 
        content
    )

    # --- FIX 2 & 3: The 'initialValue' errors (Line ~1105 & ~1646) ---
    # These are simple swaps, but we must target the specific variables
    # to avoid breaking TextFormFields.
    
    # Fix the Template Creator dropdown
    content = content.replace("initialValue: _selectedExercises[index]", "value: _selectedExercises[index]")
    
    # Fix the Edit Dialog dropdowns (Type and Difficulty)
    content = content.replace("initialValue: type", "value: type")
    content = content.replace("initialValue: difficulty", "value: difficulty")
    
    # Fallback for generic 'map' issues in the dialogs (e.g. ['Gym', 'Running'].map...)
    content = re.sub(
        r'\.map\s*\(\s*\(t\)', 
        '.map<DropdownMenuItem<String>>((t)', 
        content
    )
    content = re.sub(
        r'\.map\s*\(\s*\(d\)', 
        '.map<DropdownMenuItem<String>>((d)', 
        content
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ Fixed the final 3 errors (handled multi-line formatting).")

if __name__ == "__main__":
    fix_final_three()