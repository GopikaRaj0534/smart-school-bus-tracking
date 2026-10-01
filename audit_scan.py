import re

def audit_flutter_api():
    with open('lib/services/api_service.dart', 'r', encoding='utf-8') as f:
        code = f.read()

    # Find static Future methods
    methods = re.findall(r'static\s+Future<([^>]+)>\s+([a-zA-Z0-9_]+)\(([\s\S]*?)\)\s*async', code)
    print(f"\nTotal ApiService Methods Found: {len(methods)}")
    for ret_type, name, params in methods:
        clean_p = ' '.join(params.split())
        print(f"  - {name}: Future<{ret_type}>({clean_p})")

if __name__ == '__main__':
    audit_flutter_api()
