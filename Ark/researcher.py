from googlesearch import search
import requests
from bs4 import BeautifulSoup
import sys

def google_search(query):
    print(f"[RESEARCHER] Searching Google for: {query}")
    results = []
    # Get top 3 links
    try:
        for j in search(query, num_results=3, advanced=True):
            results.append((j.title, j.url, j.description))
    except Exception as e:
        return f"Search Error: {e}"
    
    output = f"--- SEARCH RESULTS FOR '{query}' ---\n"
    for i, (title, url, desc) in enumerate(results):
        output += f"[{i+1}] {title}\n    {desc}\n    URL: {url}\n\n"
    return output

def read_url(url):
    print(f"[RESEARCHER] Reading content from: {url}")
    try:
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'}
        response = requests.get(url, headers=headers, timeout=10)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Kill javascript and css
        for script in soup(["script", "style"]):
            script.decompose()
            
        text = soup.get_text()
        # Clean up whitespace
        lines = (line.strip() for line in text.splitlines())
        chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
        text = '\n'.join(chunk for chunk in chunks if chunk)
        
        return f"--- CONTENT OF {url} ---\n{text[:2000]}..." # Limit to 2000 chars
    except Exception as e:
        return f"Error reading URL: {e}"

if __name__ == "__main__":
    mode = sys.argv[1]
    query = " ".join(sys.argv[2:])
    
    if mode == "search":
        print(google_search(query))
    elif mode == "read":
        print(read_url(query))