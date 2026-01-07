import os
import re

def fix_workout_screens():
    filepath = os.path.join('lib', 'screens', 'workout_screens.dart')
    if not os.path.exists(filepath):
        print(f"❌ File not found: {filepath}")
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # --- FIX 1: Revert 'initialValue' back to 'value' ONLY for Dropdowns ---
    # We look for the pattern where DropdownButtonFormField is defined, and ensure it uses value:
    # This is a bit complex for regex, so we'll do a surgical string replacement for the specific error cases.
    
    # Revert specific known bad replacements in DropdownButtonFormField
    content = content.replace("DropdownButtonFormField<String>(", "DropdownButtonFormField<String>(/*FIXED*/")
    
    # We will search for the specific lines causing errors or generic patterns inside the file.
    # Pattern: "initialValue:" ... inside a dropdown context is hard to detect with simple regex globally.
    # Strategy: Replace ALL "initialValue:" back to "value:" ONLY IF it follows a Dropdown pattern nearby?
    # Simpler Strategy: The compilation error only happens on DropdownButtonFormField. 
    # Let's target the lines explicitly if we can, or just swap variable names commonly used in dropdowns.
    
    # Logic: Dropdowns usually take 'value: type' or 'value: difficulty'.
    content = content.replace("initialValue: type", "value: type")
    content = content.replace("initialValue: difficulty", "value: difficulty")
    content = content.replace("initialValue: _selectedMoods", "value: _selectedMoods") # unlikely but possible
    
    # Fix the .map error (Type mismatch)
    # Change .map((t) => DropdownMenuItem( to .map<DropdownMenuItem<String>>((t) => DropdownMenuItem(
    content = content.replace(
        ".map((t) => DropdownMenuItem(value: t, child: Text(t)))", 
        ".map<DropdownMenuItem<String>>((t) => DropdownMenuItem(value: t, child: Text(t)))"
    )
    content = content.replace(
        ".map((d) => DropdownMenuItem(value: d, child: Text(d)))", 
        ".map<DropdownMenuItem<String>>((d) => DropdownMenuItem(value: d, child: Text(d)))"
    )
    
    # Catch-all for other map variations in that file
    content = re.sub(
        r'\.map\(\(([^)]+)\)\s*=>\s*DropdownMenuItem', 
        r'.map<DropdownMenuItem<String>>((\1) => DropdownMenuItem', 
        content
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ Fixed DropdownButton errors in workout_screens.dart")

def fix_home_screen():
    filepath = os.path.join('lib', 'screens', 'home_screen.dart')
    if not os.path.exists(filepath):
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Fix empty catch
    content = content.replace("} catch (e) {}", "} catch (e) { debugPrint(e.toString()); }")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ Fixed empty catch in home_screen.dart")

def fix_async_gaps_blindly():
    # Attempt to blindly fix the specific reported async gaps by inserting checks before Context usage
    # This is "surgical" based on typical patterns.
    
    files_to_check = [
        'lib/screens/device_sync_screen.dart', 
        'lib/screens/profile_screen.dart', 
        'lib/screens/stats_screen.dart'
    ]
    
    for fp in files_to_check:
        if not os.path.exists(fp):
            continue
            
        with open(fp, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        new_lines = []
        modified = False
        
        for i, line in enumerate(lines):
            # If line contains Navigator or ScaffoldMessenger or Theme.of(context)
            # AND previous non-empty line contained 'await'
            # We insert 'if (!mounted) return;'
            
            # This is hard to do perfectly without parsing, but we can look for specific calls reported in logs
            # use_build_context_synchronously usually happens on Scaffolds or Navigators after awaits.
            
            if "ScaffoldMessenger.of(context)" in line or "Navigator." in line:
                # Check previous few lines for await
                prev_lines = "".join(lines[max(0, i-5):i])
                if "await " in prev_lines and "if (!mounted)" not in prev_lines:
                    new_lines.append("                    if (!mounted) return;\n")
                    modified = True
            
            new_lines.append(line)

        if modified:
            with open(fp, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            print(f"⚠️ Attempted blind Async Gap fix on {fp}")

if __name__ == "__main__":
    fix_workout_screens()
    fix_home_screen()
    fix_async_gaps_blindly()