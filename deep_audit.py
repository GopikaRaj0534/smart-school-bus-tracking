import os
import re

def scan_api_service():
    with open('lib/services/api_service.dart', 'r', encoding='utf-8') as f:
        code = f.read()

    # Find method definitions in ApiService
    pattern = r'static\s+Future<([^>]+)>\s+([a-zA-Z0-9_]+)\s*\(([\s\S]*?)\)\s*async'
    matches = re.findall(pattern, code)
    print(f"=== ApiService Methods ({len(matches)}) ===")
    for ret, name, params in matches:
        # Extract HTTP method and endpoint inside body if possible
        clean_p = ' '.join(params.split())
        print(f"ApiService.{name} -> Future<{ret}>")
        print(f"  Params: {clean_p}")

def scan_app_py():
    with open('app.py', 'r', encoding='utf-8') as f:
        code = f.read()

    # Find SQL queries in app.py
    queries = re.findall(r'(SELECT|INSERT|UPDATE|DELETE)\s+[^;"]+', code, re.IGNORECASE)
    print(f"\n=== SQL Queries in app.py ({len(queries)}) ===")
    
    # Check authorization checks in app.py
    print("\n=== Authorization Checks in app.py ===")
    role_checks = re.findall(r'(\/admin[^\'\"]+|\/parent[^\'\"]+|\/driver[^\'\"]+)', code)
    print(f"Total role-prefixed routes: {len(set(role_checks))}")

if __name__ == '__main__':
    scan_api_service()
    scan_app_py()
