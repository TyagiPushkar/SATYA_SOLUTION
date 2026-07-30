with open("test/feature/home/screen/home_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re
pattern = re.compile(r"  List<Widget> _buildEmployeeDrawerItems\(.*?    \];\n  \}", re.DOTALL)
match = pattern.search(content)
if match:
    print("MATCHED!")
else:
    print("NO MATCH")
