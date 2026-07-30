import sys

with open("test/feature/home/screen/home_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if line.startswith("  List<Widget> _buildAdminDrawerItems("):
        skip = True
    
    if skip and line.strip() == "class _RotatedText extends StatelessWidget {":
        skip = False
    
    if not skip:
        new_lines.append(line)

with open("test/feature/home/screen/home_screen.dart", "w", encoding="utf-8") as f:
    f.writelines(new_lines)
print("Done")
