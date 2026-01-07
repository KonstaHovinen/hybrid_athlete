import os

def fix_workout_screens():
    filepath = os.path.join('lib', 'screens', 'workout_screens.dart')
    
    if not os.path.exists(filepath):
        print("❌ Could not find workout_screens.dart")
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # --- 1. Fix the "Red" Compilation Errors (Dropdowns) ---
    # ERROR: undefined_named_parameter 'initialValue' on DropdownButtonFormField
    # FIX: Change 'initialValue' back to 'value' specifically for these variables
    content = content.replace("initialValue: type", "value: type")
    content = content.replace("initialValue: difficulty", "value: difficulty")
    content = content.replace("initialValue: _selectedExercises[index]", "value: _selectedExercises[index]")

    # ERROR: argument_type_not_assignable (List<dynamic> vs List<String>)
    # FIX: Add <DropdownMenuItem<String>> to the .map() calls
    content = content.replace(
        ".map((t) => DropdownMenuItem(value: t, child: Text(t)))", 
        ".map<DropdownMenuItem<String>>((t) => DropdownMenuItem(value: t, child: Text(t)))"
    )
    content = content.replace(
        ".map((d) => DropdownMenuItem(value: d, child: Text(d)))", 
        ".map<DropdownMenuItem<String>>((d) => DropdownMenuItem(value: d, child: Text(d)))"
    )
    # Catch the generic exercise dropdown if missed by above
    content = content.replace(
        "items: _availableExercises.map((e)", 
        "items: _availableExercises.map<DropdownMenuItem<String>>((e)"
    )

    # --- 2. Fix the Deprecation Warnings (TextFormField) ---
    # WARNING: 'value' is deprecated, use 'initialValue'
    # FIX: We look for TextFormField usages that might still be using 'value:'
    # This regex looks for 'TextFormField(' followed eventually by 'value:' and swaps it
    # But to be safer and simpler, let's just swap common patterns found in your code:
    content = content.replace("TextFormField(value:", "TextFormField(initialValue:") 
    # Also catch cases where it might be on a new line
    content = content.replace("TextFormField(\n                  value:", "TextFormField(\n                  initialValue:")

    # --- 3. Fix the formatting error ---
    # INFO: Statements in an if should be enclosed in a block (Line 974)
    # Finding the likely unblocked if statement:
    if "if (currentExerciseIndex < widget.template.exercises.length - 1)\n" in content:
        content = content.replace(
            "if (currentExerciseIndex < widget.template.exercises.length - 1)\n      currentExerciseIndex++;",
            "if (currentExerciseIndex < widget.template.exercises.length - 1) {\n      currentExerciseIndex++;\n    }"
        )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ Fixed workout_screens.dart: Swapped 'value'/'initialValue' correctly and fixed types.")

if __name__ == "__main__":
    fix_workout_screens()