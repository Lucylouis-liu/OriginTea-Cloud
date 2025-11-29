import sys
import urllib.parse

temp_file = sys.argv[1]
try:
    with open(temp_file, "r", encoding="utf-8") as f:
        content = f.read()
    encoded = urllib.parse.quote(content, safe="")
    sys.stdout.write(encoded)
    sys.stdout.flush()
except Exception as e:
    sys.stderr.write("Error: " + str(e) + "\n")
    sys.exit(1)

