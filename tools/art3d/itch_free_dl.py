"""Download the FREE (min price 0) uploads of an itch.io asset page. Usage: itch_free_dl.py <page_url> <out_dir>"""
import sys, re, json, os, subprocess, tempfile
page, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
jar = tempfile.mktemp()
def curl(*a):
    return subprocess.run(["curl", "-sSL", "-c", jar, "-b", jar, *a], capture_output=True, text=True, check=True).stdout
html = curl(page)
tok = re.search(r'name="csrf_token" value="([^"]+)"', html).group(1)
dl = json.loads(curl("-X", "POST", "--data-urlencode", f"csrf_token={tok}", page.rstrip("/") + "/download_url"))
dlp = curl(dl["url"])
ups = re.findall(r'data-upload_id="(\d+)"', dlp)
names = re.findall(r'class="name" title="([^"]+)"', dlp)
tok = re.search(r'name="csrf_token" value="([^"]+)"', dlp).group(1)
names += [f"upload_{u}.zip" for u in ups[len(names):]]
for uid, name in zip(ups, names):
    r = json.loads(curl("-X", "POST", "--data-urlencode", f"csrf_token={tok}",
        page.rstrip("/") + f"/file/{uid}?source=view_game&as_props=1&after_download_lightbox=true"))
    dest = os.path.join(out, name.replace("/", "_"))
    subprocess.run(["curl", "-sSL", r["url"], "-o", dest], check=True)
    print("OK", uid, name, os.path.getsize(dest))
