import sys
import os
import glob

LIBRARY_DIR = "library"
if not os.path.exists(LIBRARY_DIR): os.makedirs(LIBRARY_DIR)

def add_note(category, content):
    # Sanitize filename
    filename = category.lower().strip() + ".txt"
    filepath = os.path.join(LIBRARY_DIR, filename)
    
    with open(filepath, "a", encoding="utf-8") as f:
        f.write(f"\n{content}\n")
    print(f"[LIBRARIAN] Note added to {filename}.")

def search_notes(query):
    print(f"[LIBRARIAN] Searching for '{query}'...")
    found = False
    query_lower = query.lower()
    
    for filepath in glob.glob(os.path.join(LIBRARY_DIR, "*.txt")):
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                lines = f.readlines()
            
            # Find only lines that match the query
            matching_lines = [line.strip() for line in lines if query_lower in line.lower() and line.strip()]
            
            if matching_lines:
                print(f"\n[FOUND]")
                for line in matching_lines:
                    print(f"  {line}")
                found = True
        except: continue
    
    if not found: print("No matching notes found.")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python librarian.py [add|search] [category/query] [content]")
    else:
        mode = sys.argv[1]
        arg1 = sys.argv[2] # Category or Query
        arg2 = " ".join(sys.argv[3:]) # Content (optional)
        
        if mode == "add": add_note(arg1, arg2)
        elif mode == "search": search_notes(arg1)