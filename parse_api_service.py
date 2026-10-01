import re

with open('lib/services/api_service.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

methods = []
current_doc = ""
for i, line in enumerate(lines):
    if 'static Future' in line:
        method_def = line.strip()
        j = i + 1
        while ')' not in lines[j-1] and j < len(lines):
            method_def += " " + lines[j].strip()
            j += 1
        
        # Look inside method body for endpoint
        body = ""
        for k in range(j, min(j + 30, len(lines))):
            body += lines[k]
        
        endpoint = ""
        http_m = "GET"
        if '_get(' in body:
            http_m = "GET"
            match = re.search(r'_get\(\s*[\'"]([^\'"]+)[\'"]', body)
            if match: endpoint = match.group(1)
        elif '_post(' in body:
            http_m = "POST"
            match = re.search(r'_post\(\s*[\'"]([^\'"]+)[\'"]', body)
            if match: endpoint = match.group(1)
        elif '_put(' in body:
            http_m = "PUT"
            match = re.search(r'_put\(\s*[\'"]([^\'"]+)[\'"]', body)
            if match: endpoint = match.group(1)
        elif '_delete(' in body:
            http_m = "DELETE"
            match = re.search(r'_delete\(\s*[\'"]([^\'"]+)[\'"]', body)
            if match: endpoint = match.group(1)
            
        methods.append((method_def, http_m, endpoint))

print(f"Total ApiService Methods Parsed: {len(methods)}")
for m, http_m, ep in methods:
    m_name = m.split('(')[0].replace('static Future<', '').replace('>', '').strip()
    print(f"  {m_name} | {http_m} | {ep}")
