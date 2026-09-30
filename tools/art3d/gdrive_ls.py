"""List a public Google Drive folder: gdrive_ls.py <folder_id>  -> lines id<TAB>mime<TAB>name"""
import re, sys, subprocess
fid = sys.argv[1]
html = subprocess.run(["curl", "-sSL", f"https://drive.google.com/drive/folders/{fid}"], capture_output=True, text=True).stdout
i = html.find("_DRIVE_ivd")
seg = html[i:]
seg = seg[:seg.find("';")]
seg = seg.replace("\\/", "/").encode().decode("unicode_escape", errors="ignore")
for m in re.finditer(r'\["([A-Za-z0-9_-]{20,})",\["' + re.escape(fid) + r'"\],"([^"]+)","([^"]+)"', seg):
    print(m.group(1), m.group(3), m.group(2), sep="\t")
