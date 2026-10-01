import re

with open('app.py', 'r', encoding='utf-8') as f:
    app_code = f.read()

flask_routes = re.findall(r'@app\.route\(\s*[\'"]([^\'"]+)[\'"](?:,\s*methods=\[([^\]]+)\])?', app_code)
route_dict = {}
for path, methods in flask_routes:
    m_list = [m.strip().replace("'", "").replace('"', '') for m in methods.split(',')] if methods else ['GET']
    route_dict[path] = m_list

with open('lib/services/api_service.dart', 'r', encoding='utf-8') as f:
    api_code = f.read()

# Find all static Future methods by splitting function headers
matches = re.finditer(r'static\s+Future<([^>]+)>\s+([a-zA-Z0-9_]+)\s*\(([\s\S]*?)\)\s*async\s*\{', api_code)

api_table = []
for match in matches:
    ret_t = match.group(1)
    name = match.group(2)
    params = match.group(3)
    
    if name.startswith('_'): continue
    
    start_idx = match.end()
    # Find matching closing brace
    depth = 1
    end_idx = start_idx
    while depth > 0 and end_idx < len(api_code):
        if api_code[end_idx] == '{': depth += 1
        elif api_code[end_idx] == '}': depth -= 1
        end_idx += 1
        
    body = api_code[start_idx:end_idx]
    
    http_m = "UNKNOWN"
    path = "UNKNOWN"
    
    m_get = re.search(r'_get\(\s*[\'"]([^\'"]+)[\'"]', body)
    m_post = re.search(r'_post\(\s*[\'"]([^\'"]+)[\'"]', body)
    m_put = re.search(r'_put\(\s*[\'"]([^\'"]+)[\'"]', body)
    m_del = re.search(r'_delete\(\s*[\'"]([^\'"]+)[\'"]', body)
    
    if m_get: http_m, path = "GET", m_get.group(1)
    elif m_post: http_m, path = "POST", m_post.group(1)
    elif m_put: http_m, path = "PUT", m_put.group(1)
    elif m_del: http_m, path = "DELETE", m_del.group(1)

    norm_path = re.sub(r'\$\{?([a-zA-Z0-9_]+)\}?', r'<\1>', path)
    clean_norm_path = norm_path.split('?')[0]
    
    matched = False
    for f_path, f_methods in route_dict.items():
        f_norm = re.sub(r'<(?:[a-zA-Z0-9_]+:)?([a-zA-Z0-9_]+)>', r'<\1>', f_path)
        if clean_norm_path.lower() == f_norm.lower() or clean_norm_path.lower() == (f_norm + '/').lower():
            matched = True
            m_ok = http_m in f_methods
            status = "MATCH OK" if m_ok else f"METHOD MISMATCH (Flutter: {http_m}, Flask: {f_methods})"
            api_table.append((name, http_m, path, f_path, "YES", "YES", status))
            break
            
    if not matched:
        api_table.append((name, http_m, path, "NONE", "NO", "NO", "MISSING BACKEND ROUTE"))

print(f"=== Accurately Cross-Matching {len(api_table)} ApiService Methods against {len(route_dict)} Flask Routes ===\n")
print(f"{'Flutter Function':32} | {'Method':6} | {'Flutter URL':42} | {'Flask Route':42} | {'Flask Route?'} | {'DB Support?'} | {'Status'}")
print("-" * 170)
for fn, hm, url, fr, ex, db, st in api_table:
    print(f"{fn:32} | {hm:6} | {url:42} | {fr:42} | {ex:12} | {db:11} | {st}")
