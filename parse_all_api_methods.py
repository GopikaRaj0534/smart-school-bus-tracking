import re

with open('lib/services/api_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

with open('app.py', 'r', encoding='utf-8') as f:
    app_text = f.read()

flask_routes = re.findall(r'@app\.route\(\s*[\'"]([^\'"]+)[\'"](?:,\s*methods=\[([^\]]+)\])?', app_text)
route_dict = {}
for path, methods in flask_routes:
    m_list = [m.strip().replace("'", "").replace('"', '') for m in methods.split(',')] if methods else ['GET']
    route_dict[path] = m_list

chunks = text.split('static Future<')
api_table = []

def camel_to_snake(name):
    name = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
    return re.sub('([a-z0-9])([A-Z])', r'\1_\2', name).lower()

for chunk in chunks[1:]:
    header = chunk.split(') async')[0]
    ret_type = header.split('>')[0].strip()
    name = header.split('>')[1].split('(')[0].strip()
    
    if name.startswith('_'): continue
    
    http_m = "UNKNOWN"
    path = "UNKNOWN"
    m_get = re.search(r'_get\(\s*[\'"]([^\'"]+)[\'"]', chunk)
    m_post = re.search(r'_post\(\s*[\'"]([^\'"]+)[\'"]', chunk)
    m_put = re.search(r'_put\(\s*[\'"]([^\'"]+)[\'"]', chunk)
    m_del = re.search(r'_delete\(\s*[\'"]([^\'"]+)[\'"]', chunk)
    
    if m_get: http_m, path = "GET", m_get.group(1)
    elif m_post: http_m, path = "POST", m_post.group(1)
    elif m_put: http_m, path = "PUT", m_put.group(1)
    elif m_del: http_m, path = "DELETE", m_del.group(1)

    norm_path = re.sub(r'\$\{?([a-zA-Z0-9_]+)\}?', lambda m: f"<{camel_to_snake(m.group(1))}>", path)
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

print(f"Total ApiService methods parsed: {len(api_table)}\n")
print(f"{'Flutter Function':28} | {'Method':6} | {'Flutter URL':42} | {'Flask Route':42} | {'Flask Route?'} | {'DB Support?'} | {'Status'}")
print("-" * 175)
for fn, hm, url, fr, ex, db, st in api_table:
    print(f"{fn:28} | {hm:6} | {url:42} | {fr:42} | {ex:12} | {db:11} | {st}")
