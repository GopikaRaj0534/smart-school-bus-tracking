import re

with open('lib/services/api_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Match static Future <type> <name>(<args>) async
pattern = r'static\s+Future<[^>]+>\s+([a-zA-Z0-9_]+)\s*\(([^)]*)\)\s*async'
matches = re.findall(pattern, text)

print(f"Total ApiService methods found: {len(matches)}")
for name, args in matches:
    if name.startswith('_'): continue
    print(f"- {name}({args.strip()[:40]})")
