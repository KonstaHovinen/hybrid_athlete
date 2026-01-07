import os

def finish_repair():
    filepath = os.path.join('lib', 'screens', 'workout_screens.dart')
    
    if not os.path.exists(filepath):
        print("❌ File not found.")
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # --- FIX 1: The 'Create Template' Dropdown (Lines ~1100) ---
    
    # Error: Argument type 'List<dynamic>' can't be assigned to 'List<String>'
    # Fix: Add <DropdownMenuItem<String>> to the map function
    content = content.replace(
        "items: _availableExercises.map((e)", 
        "items: _availableExercises.map<DropdownMenuItem<String>>((e)"
    )

    # Error: 'initialValue' isn't defined for DropdownButtonFormField
    # Fix: Change to 'value'
    content = content.replace(
        "initialValue: _selectedExercises[index]", 
        "value: _selectedExercises[index]"
    )

    # --- FIX 2: The 'Edit Exercise' Dropdowns (Lines ~1640) ---
    
    # Likely the 'difficulty' or 'type' dropdowns causing the issue at 1646
    # We replace widely to catch both potential culprits
    content = content.replace("initialValue: difficulty", "value: difficulty")
    content = content.replace("initialValue: type", "value: type")
    
    # Just in case it's a generic one found in previous context
    content = content.replace("initialValue: selectedRunType", "value: selectedRunType")

    # --- FIX 3: Safety Net for Maps ---
    # Ensure any other dropdown maps are typed correctly
    content = content.replace(
        ".map((t) => DropdownMenuItem(", 
        ".map<DropdownMenuItem<String>>((t) => DropdownMenuItem("
    )
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ Patched final 3 errors in workout_screens.dart")

if __name__ == "__main__":
    finish_repair()