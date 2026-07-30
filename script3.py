import sys

with open("test/feature/home/screen/home_screen.dart", "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if line.strip() == "class _RotatedText extends StatelessWidget {":
        new_lines.append("}\n")
    new_lines.append(line)

with open("test/feature/home/screen/home_screen.dart", "w", encoding="utf-8") as f:
    f.writelines(new_lines)
print("Done")
