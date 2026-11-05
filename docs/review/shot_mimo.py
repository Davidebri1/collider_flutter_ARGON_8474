import asyncio
from playwright.async_api import async_playwright

OUT = r"C:\Users\D\Documents\collider-source-Mimo\docs\review"

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(channel="chrome", headless=True)
        page = await browser.new_page(viewport={"width": 390, "height": 844}, device_scale_factor=3)
        page.on("pageerror", lambda e: print("PAGEERROR:", str(e)[:300]))

        # 1) Premium market via deep link (also seeds a premium theme).
        await page.goto("http://localhost:8901/?drawer=premium", wait_until="networkidle")
        await page.wait_for_timeout(9000)
        await page.screenshot(path=OUT + r"\mimo_market.png")
        print("market shot saved")

        # 2) Apps pane -> Theme Gallery.
        await page.mouse.click(233, 807)
        await page.wait_for_timeout(2500)
        await page.mouse.click(229, 351)  # Themes tile
        await page.wait_for_timeout(4500)
        await page.screenshot(path=OUT + r"\mimo_gallery.png")
        print("gallery shot saved")

        # 3) Apps pane -> Browser.
        await page.mouse.click(233, 807)
        await page.wait_for_timeout(2000)
        await page.mouse.click(262, 411)  # Browser tile
        await page.wait_for_timeout(4500)
        await page.screenshot(path=OUT + r"\mimo_browser.png")
        print("browser shot saved")
        # close via the 44px X at toolbar right end (inside window, top-right)
        await page.keyboard.press("Escape")
        await page.wait_for_timeout(1500)

        # 4) Apps pane -> Smart Gen.
        await page.mouse.click(233, 807)
        await page.wait_for_timeout(2000)
        await page.mouse.click(93, 351)  # Smart Gen tile
        await page.wait_for_timeout(5000)
        await page.screenshot(path=OUT + r"\mimo_smartgen.png")
        print("smartgen shot saved")

        # 5) Home with the module rail + search.
        await page.keyboard.press("Escape")
        await page.mouse.click(174, 807)  # dock: compose/home
        await page.wait_for_timeout(2500)
        await page.screenshot(path=OUT + r"\mimo_home.png")
        print("home shot saved")
        await browser.close()

asyncio.run(main())
