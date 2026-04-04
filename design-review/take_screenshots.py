from playwright.sync_api import sync_playwright

BASE_DIR = "/Users/thefinder808/Development/macperf/design-review"

FILES = [
    ("option_a_overview.html", "option_a_overview.png"),
    ("option_a_detail.html",   "option_a_detail.png"),
    ("option_b_overview.html", "option_b_overview.png"),
    ("option_b_detail.html",   "option_b_detail.png"),
    ("option_c_overview.html", "option_c_overview.png"),
    ("option_c_detail.html",   "option_c_detail.png"),
]

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(
        viewport={"width": 1200, "height": 800},
        device_scale_factor=2,
    )

    for html_file, png_file in FILES:
        url = f"file://{BASE_DIR}/{html_file}"
        print(f"Navigating to {html_file} ...")
        page.goto(url)
        page.wait_for_timeout(1000)
        out_path = f"{BASE_DIR}/{png_file}"
        page.screenshot(path=out_path, full_page=True)
        print(f"  -> saved {png_file}")

    browser.close()

print("\nDone.")
