import os

main_dart_path = r"c:\New folder\satyasolution\lib\main.dart"
app_dart_path = r"c:\New folder\satyasolution\test\core\app.dart"

# Generate absolute URI
uri = "file:///" + app_dart_path.replace("\\", "/")

with open(main_dart_path, 'r') as f:
    content = f.read()

content = content.replace("import '../test/core/app.dart';", f"import '{uri}';")

with open(main_dart_path, 'w') as f:
    f.write(content)

print(f"Fixed main.dart by replacing relative import with: {uri}")
