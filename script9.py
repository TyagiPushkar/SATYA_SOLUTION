with open("test/feature/home/screen/home_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

import re
pattern = re.compile(r"  List<Widget> _buildEmployeeDrawerItems\(BuildContext context, WidgetRef ref\) \{.*?    \];\n  \}", re.DOTALL)
new_method = "TESTING123"
content, num_subs = pattern.subn(new_method, content, count=1)
print(f"Num subs: {num_subs}")
