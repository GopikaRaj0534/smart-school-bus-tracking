import re

with open('app.py', 'r', encoding='utf-8') as f:
    app_code = f.read()

flask_routes = re.findall(r'@app\.route\(\s*[\'"]([^\'"]+)[\'"](?:,\s*methods=\[([^\]]+)\])?', app_code)
route_dict = {}
for path, methods in flask_routes:
    m_list = [m.strip().replace("'", "").replace('"', '') for m in methods.split(',')] if methods else ['GET']
    route_dict[path] = m_list

with open('lib/services/api_service.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

methods = []
for i, line in enumerate(lines):
    if 'static Future' in line and not line.strip().startswith('//'):
        m_name = line.strip().split('(')[0].replace('static Future<', '').replace('>', '').split()[-1]
        if m_name.startswith('_'): continue
        
        # Read method body
        body = ""
        for j in range(i, min(i + 40, len(lines))):
            body += lines[j]
            
        http_m = "GET"
        path = "UNKNOWN"
        m_get = re.search(r'_get\(\s*[\'"]([^\'"]+)[\'"]', body)
        m_post = re.search(r'_post\(\s*[\'"]([^\'"]+)[\'"]', body)
        m_put = re.search(r'_put\(\s*[\'"]([^\'"]+)[\'"]', body)
        m_del = re.search(r'_delete\(\s*[\'"]([^\'"]+)[\'"]', body)
        
        if m_get: http_m, path = "GET", m_get.group(1)
        elif m_post: http_m, path = "POST", m_post.group(1)
        elif m_put: http_m, path = "PUT", m_put.group(1)
        elif m_del: http_m, path = "DELETE", m_del.group(1)
        
        methods.append((m_name, http_m, path))

print(f"=== Cross-Matching {len(methods)} ApiService Methods against {len(route_dict)} Flask Routes ===\n")

for name, http_m, path in methods:
    # Convert Dart $var or ${var} to python <var>
    norm_path = re.sub(r'\$\{?([a-zA-Z0-9_]+)\}?', r'<\1>', path)
    clean_norm_path = norm_path.split('?')[0]
    
    matched = False
    for f_path, f_methods in route_dict.items():
        f_norm = re.sub(r'<(?:[a-zA-Z0-9_]+:)?([a-zA-Z0-9_]+)>', r'<\1>', f_path)
        if clean_norm_path.lower() == f_norm.lower() or clean_norm_path.lower() == (f_norm + '/').lower():
            matched = True
            m_ok = http_m in f_methods
            status = "MATCH OK" if m_ok else f"METHOD MISMATCH (Flutter: {http_m}, Flask: {f_methods})"
            print(f"{name:32} | {http_m:6} | {path:45} | Backend: {f_path:45} | {status}")
            break
            
    if not matched:
        print(f"{name:32} | {http_m:6} | {path:45} | Backend: MISSING ROUTE                       | NOT FOUND IN FLASK!")
