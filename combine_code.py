import os

# --- CONFIGURATION ---
OUTPUT_FILE = "FULL_CODE_CONTEXT.txt"

# Folders to COMPLETELY IGNORE
IGNORE_DIRS = {
    'node_modules', '.git', '.next', 'dist', 'build', 'coverage', 
    'venv', '__pycache__', '.vscode', '.idea', 'ios', 'android', 'public'
}

# Only include these text-based code files
INCLUDE_EXTS = {
    '.js', '.jsx', '.ts', '.tsx', '.py', '.html', '.css', '.scss', 
    '.json', '.sql', '.prisma', '.java', '.c', '.cpp', '.rb', '.go', '.rs'
}

# Skip specific junk files
IGNORE_FILES = {
    'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 
    'combine_code.py', OUTPUT_FILE
}

def combine_files():
    print("Scanning project... (This solves the 'Too Many Files' error)")
    file_count = 0
    
    with open(OUTPUT_FILE, "w", encoding="utf-8") as outfile:
        outfile.write(f"PROJECT CONTEXT\n==================\n")
        
        for root, dirs, files in os.walk("."):
            # Remove ignored directories from the search
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
            
            for file in files:
                if file in IGNORE_FILES: continue
                
                ext = os.path.splitext(file)[1].lower()
                if ext in INCLUDE_EXTS:
                    path = os.path.join(root, file)
                    try:
                        # Safety Check: Skip huge files (>500KB) like minified bundles
                        if os.path.getsize(path) > 500_000:
                            print(f"Skipping large file: {file}")
                            continue

                        with open(path, "r", encoding="utf-8", errors='ignore') as infile:
                            content = infile.read()
                            # Write file header so AI knows which file this is
                            outfile.write(f"\n\n--- FILE START: {path} ---\n")
                            outfile.write(content)
                            outfile.write(f"\n--- FILE END: {path} ---\n")
                            file_count += 1
                    except Exception as e:
                        print(f"Error reading {file}: {e}")

    print(f"\n✅ DONE! Processed {file_count} files.")
    print(f"👉 Upload '{OUTPUT_FILE}' to Gemini. (It counts as just 1 file!)")

if __name__ == "__main__":
    combine_files()